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
    @Published var authToken: String? {
        didSet {
            if let token = authToken {
                UserDefaults.standard.set(token, forKey: "authToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "authToken")
            }
        }
    }
    
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
        
        // Load saved auth token
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
    }
    
    // MARK: - Request Building
    
    func request(endpoint: String, method: String = "GET") -> URLRequest {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        let data = try JSONEncoder().encode(body)
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
                throw APIError.serverError(detail)
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    func executeVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                throw APIError.serverError(detail)
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
    }
    
    func clearAuth() {
        authToken = nil
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case notFound(String)
    case unauthorized
    case networkError(Error)
    
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
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

