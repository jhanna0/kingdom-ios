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
    
    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                // Handle specific status codes
                if httpResponse.statusCode == 403 {
                    throw APIError.forbidden(detail)
                } else if httpResponse.statusCode == 404 {
                    throw APIError.notFound(detail)
                } else if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.serverError(detail)
            }
            
            // No detail message, use status code
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
    
    func executeVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                // Handle specific status codes
                if httpResponse.statusCode == 403 {
                    throw APIError.forbidden(detail)
                } else if httpResponse.statusCode == 404 {
                    throw APIError.notFound(detail)
                } else if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.serverError(detail)
            }
            
            // No detail message, use status code
            if httpResponse.statusCode == 403 {
                throw APIError.forbidden("Access denied")
            } else if httpResponse.statusCode == 404 {
                throw APIError.notFound("Resource not found")
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
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

