import Foundation
import UIKit

/// Sends debug logs to the backend for debugging crashes during sign-up flow.
/// Uses fire-and-forget pattern - never blocks the main flow.
class DebugLogger {
    static let shared = DebugLogger()
    
    private let apiClient = APIClient.shared
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString
    
    private init() {}
    
    /// Log a step in the sign-up flow to the backend
    /// - Parameters:
    ///   - step: A short identifier for the step (e.g., "signIn_start")
    ///   - message: Human-readable description
    ///   - extra: Optional additional context
    func log(_ step: String, message: String, extra: [String: Any]? = nil) {
        // Also print locally for Xcode console
        print("📱 [DebugLogger] [\(step)] \(message)")
        
        // Fire and forget - don't wait for response
        Task.detached(priority: .background) { [weak self] in
            await self?.sendLog(step: step, message: message, extra: extra)
        }
    }
    
    private func sendLog(step: String, message: String, extra: [String: Any]?) async {
        struct ClientLogRequest: Encodable {
            let step: String
            let message: String
            let device_id: String?
            let extra: [String: String]?  // Simplified to string values
        }
        
        // Convert extra dict to string values for JSON encoding
        var stringExtra: [String: String]? = nil
        if let extra = extra {
            stringExtra = extra.reduce(into: [:]) { result, pair in
                result[pair.key] = String(describing: pair.value)
            }
        }
        
        let body = ClientLogRequest(
            step: step,
            message: message,
            device_id: deviceId,
            extra: stringExtra
        )
        
        do {
            // Build request manually since this endpoint doesn't need auth
            let url = URL(string: "\(apiClient.baseURL)/auth/client-log")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            
            // Fire and forget - we don't care about the response
            _ = try? await URLSession.shared.data(for: request)
        } catch {
            // Silently ignore - logging should never break the app
            print("⚠️ DebugLogger failed to send: \(error.localizedDescription)")
        }
    }
}
