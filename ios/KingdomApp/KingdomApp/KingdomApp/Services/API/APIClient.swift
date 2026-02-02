import Foundation
import Combine

/// Base API client for Kingdom backend
/// Handles authentication, request building, and common networking logic
class APIClient: ObservableObject {
    // MARK: - Singleton
    static let shared = APIClient()
    
    // MARK: - Configuration
    let baseURL: String
    private let session: URLSession
    
    // MARK: - Auth State
    @Published var authToken: String?
    
    var isAuthenticated: Bool {
        return authToken != nil
    }
    
    // MARK: - Connection State
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var lastSyncTime: Date?
    
    // MARK: - Critical Error State (blocks UI until resolved)
    private var isShowingBlockingError: Bool = false
    
    // All continuations waiting for retry (multiple requests can be blocked)
    private var retryContinuations: [CheckedContinuation<Void, Never>] = []
    private let retryLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        self.baseURL = AppConfig.apiBaseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        
        // Auth token will be set by AuthManager - this is the single source of truth
        self.authToken = nil
    }
    
    // MARK: - Critical Error Handling
    
    /// Called when user taps retry - resumes ALL suspended requests
    @MainActor
    private func retryCriticalError() {
        isShowingBlockingError = false
        BlockingErrorWindow.shared.hide()
        
        // Resume ALL waiting requests so they retry
        retryLock.lock()
        let continuations = retryContinuations
        retryContinuations = []
        retryLock.unlock()
        
        for continuation in continuations {
            continuation.resume()
        }
    }
    
    /// Show blocking error and suspend until user taps retry
    private func waitForRetry(message: String) async {
        // Show the blocking error window (only first caller shows it)
        await MainActor.run {
            if !isShowingBlockingError {
                isShowingBlockingError = true
                BlockingErrorWindow.shared.show(
                    title: "Connection Error",
                    message: message,
                    retryAction: { [weak self] in
                        Task { @MainActor in
                            self?.retryCriticalError()
                        }
                    }
                )
            }
        }
        
        // Suspend here until retryCriticalError() is called
        await withCheckedContinuation { continuation in
            retryLock.lock()
            retryContinuations.append(continuation)
            retryLock.unlock()
        }
    }
    
    /// Determine if an error should trigger blocking UI
    /// Only network failures and server errors (5xx) should block
    private func isCriticalError(_ error: Error, statusCode: Int? = nil) -> Bool {
        // Server errors (500+) are critical
        if let code = statusCode, code >= 500 {
            return true
        }
        
        // Network connectivity errors are critical
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    /// Generate user-friendly error message
    private func userFriendlyMessage(for error: Error, statusCode: Int? = nil) -> String {
        if let code = statusCode, code >= 500 {
            return "Server error (\(code)). The kingdom servers may be experiencing issues. Please try again in a moment."
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network and try again."
            case .networkConnectionLost:
                return "Connection lost. Please check your network and try again."
            case .timedOut:
                return "Request timed out. The server may be busy. Please try again."
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "Cannot reach the server. Please check your connection and try again."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
    
    // MARK: - Request Building
    
    func request(endpoint: String, method: String = "GET") -> URLRequest {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 APIClient: Adding auth header for \(method) \(endpoint)")
        } else {
            print("⚠️ APIClient: No auth token for \(method) \(endpoint)")
        }
        
        return request
    }
    
    func request(endpoint: String, method: String, jsonData: Data) -> URLRequest {
        var request = self.request(endpoint: endpoint, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        return request
    }
    
    func request<T: Encodable>(endpoint: String, method: String, body: T) throws -> URLRequest {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)
        return request(endpoint: endpoint, method: method, jsonData: data)
    }
    
    // MARK: - Request Execution
    
    /// Check if error is a stale connection error that should be silently retried
    private func isStaleConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            // -1005: The network connection was lost (often stale keep-alive)
            // -1001: Timeout can also happen on stale connections
            return urlError.code == .networkConnectionLost
        }
        return false
    }
    
    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        // If there's already a critical error showing, wait for it to clear first
        if await MainActor.run(body: { isShowingBlockingError }) {
            await withCheckedContinuation { continuation in
                retryLock.lock()
                retryContinuations.append(continuation)
                retryLock.unlock()
            }
        }
        
        var silentRetryCount = 0
        let maxSilentRetries = 2
        
        // Retry loop - on critical errors, suspend and wait for user to tap retry
        while true {
            let data: Data
            let response: URLResponse
            
            do {
                (data, response) = try await session.data(for: request)
                silentRetryCount = 0 // Reset on success
            } catch {
                // Stale connection errors (-1005) get silent retry first
                if isStaleConnectionError(error) && silentRetryCount < maxSilentRetries {
                    silentRetryCount += 1
                    print("🔄 Silent retry \(silentRetryCount)/\(maxSilentRetries) for stale connection on \(request.url?.path ?? "unknown")")
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                    continue
                }
                
                // Network-level error (no response received)
                if isCriticalError(error) {
                    let message = userFriendlyMessage(for: error)
                    await waitForRetry(message: message)
                    silentRetryCount = 0 // Reset after user retry
                    continue // Retry the request
                }
                throw APIError.networkError(error)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response")
            }
            
            // Check for critical server errors (5xx) - wait for retry
            if httpResponse.statusCode >= 500 {
                let endpoint = request.url?.path ?? "unknown"
                print("🚨 500 ERROR on endpoint: \(endpoint)")
                print("🚨 Full URL: \(request.url?.absoluteString ?? "unknown")")
                if let body = String(data: data, encoding: .utf8) {
                    print("🚨 Response body: \(body)")
                }
                let message = userFriendlyMessage(for: NSError(domain: "", code: 0), statusCode: httpResponse.statusCode)
                await waitForRetry(message: message)
                continue // Retry the request
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Non-critical HTTP errors - throw normally
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorJson["detail"] as? String {
                    if httpResponse.statusCode == 403 {
                        throw APIError.forbidden(detail)
                    } else if httpResponse.statusCode == 404 {
                        throw APIError.notFound(detail)
                    } else if httpResponse.statusCode == 401 {
                        throw APIError.unauthorized
                    }
                    throw APIError.serverError(detail)
                }
                
                if httpResponse.statusCode == 403 {
                    throw APIError.forbidden("Access denied")
                } else if httpResponse.statusCode == 404 {
                    throw APIError.notFound("Resource not found")
                } else if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            // Debug: Print raw response (skip cities endpoint due to large boundary data)
            let path = request.url?.path ?? "unknown"
            if !path.contains("/cities") {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📥 API Response (\(path)):")
                    print(jsonString)
                }
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("❌ Decoding error for \(T.self):")
                print("Error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                        print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type \(type): \(context.debugDescription)")
                        print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type \(type): \(context.debugDescription)")
                        print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                        print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                throw APIError.decodingError(error)
            }
        }
    }
    
    func executeVoid(_ request: URLRequest) async throws {
        // If there's already a critical error showing, wait for it to clear first
        if await MainActor.run(body: { isShowingBlockingError }) {
            await withCheckedContinuation { continuation in
                retryLock.lock()
                retryContinuations.append(continuation)
                retryLock.unlock()
            }
        }
        
        var silentRetryCount = 0
        let maxSilentRetries = 2
        
        // Retry loop - on critical errors, suspend and wait for user to tap retry
        while true {
            let data: Data
            let response: URLResponse
            
            do {
                (data, response) = try await session.data(for: request)
                silentRetryCount = 0 // Reset on success
            } catch {
                // Stale connection errors (-1005) get silent retry first
                if isStaleConnectionError(error) && silentRetryCount < maxSilentRetries {
                    silentRetryCount += 1
                    print("🔄 Silent retry \(silentRetryCount)/\(maxSilentRetries) for stale connection on \(request.url?.path ?? "unknown")")
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                    continue
                }
                
                // Network-level error (no response received)
                if isCriticalError(error) {
                    let message = userFriendlyMessage(for: error)
                    await waitForRetry(message: message)
                    silentRetryCount = 0 // Reset after user retry
                    continue // Retry the request
                }
                throw APIError.networkError(error)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response")
            }
            
            // Check for critical server errors (5xx) - wait for retry
            if httpResponse.statusCode >= 500 {
                let endpoint = request.url?.path ?? "unknown"
                print("🚨 500 ERROR on endpoint: \(endpoint)")
                print("🚨 Full URL: \(request.url?.absoluteString ?? "unknown")")
                if let body = String(data: data, encoding: .utf8) {
                    print("🚨 Response body: \(body)")
                }
                let message = userFriendlyMessage(for: NSError(domain: "", code: 0), statusCode: httpResponse.statusCode)
                await waitForRetry(message: message)
                continue // Retry the request
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Non-critical HTTP errors - throw normally
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorJson["detail"] as? String {
                    if httpResponse.statusCode == 403 {
                        throw APIError.forbidden(detail)
                    } else if httpResponse.statusCode == 404 {
                        throw APIError.notFound(detail)
                    } else if httpResponse.statusCode == 401 {
                        throw APIError.unauthorized
                    }
                    throw APIError.serverError(detail)
                }
                
                if httpResponse.statusCode == 403 {
                    throw APIError.forbidden("Access denied")
                } else if httpResponse.statusCode == 404 {
                    throw APIError.notFound("Resource not found")
                } else if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            return // Success
        }
    }
    
    // MARK: - Health Check
    
    func testConnection() async -> Bool {
        do {
            let request = self.request(endpoint: "/health")
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    isConnected = false
                    lastError = "Server returned invalid response"
                }
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status == "healthy" || status == "ok" {
                await MainActor.run {
                    isConnected = true
                    lastError = nil
                }
                print("✅ Connected to Kingdom API")
                return true
            }
            
            await MainActor.run {
                isConnected = false
            }
            return false
            
        } catch {
            await MainActor.run {
                isConnected = false
                lastError = error.localizedDescription
            }
            print("❌ Failed to connect to API: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Auth
    
    func setAuthToken(_ token: String) {
        authToken = token
        print("🔐 APIClient: Auth token set (length: \(token.count))")
    }
    
    func clearAuth() {
        authToken = nil
        print("🔓 APIClient: Auth token cleared")
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case notFound(String)
    case unauthorized
    case forbidden(String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let message):
            return message
        case .notFound(let message):
            return "Not found: \(message)"
        case .unauthorized:
            return "Not authenticated"
        case .forbidden(let message):
            return "Access denied: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

