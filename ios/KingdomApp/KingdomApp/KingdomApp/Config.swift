import Foundation

/// Centralized app configuration
enum AppConfig {
    /// API Environment
    /// - local: Use Docker on your Mac (http://192.168.1.13:8000)
    /// - lambda: Use AWS Lambda deployment (https://...)
    enum APIEnvironment {
        case local
        case lambda
    }
    
    /// Set this to switch between local and Lambda API
    static let apiEnvironment: APIEnvironment = .lambda
    
    /// Backend API base URL
    static var apiBaseURL: String {
        switch apiEnvironment {
        case .local:
            return "http://192.168.1.13:8000"
        case .lambda:
            return "https://eu0qm86e1m.execute-api.us-east-1.amazonaws.com"
        }
    }
    
    /// Development mode - mirrors backend DEV_MODE setting
    /// When true:
    /// - Shows dev-only UI hints
    /// - May skip certain validations
    /// - Enables debug features
    static let devMode = true
    
    /// Contract completion hint time (matches backend behavior)
    /// In dev mode: instant completion
    /// In production: actual time calculations
    static var contractCompletionMultiplier: Double {
        devMode ? 0.0 : 1.0
    }
}

