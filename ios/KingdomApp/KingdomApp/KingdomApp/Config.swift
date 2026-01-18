import Foundation

/// Centralized app configuration
enum AppConfig {
    /// API Environment
    /// - local: Use Docker on your Mac (http://192.168.1.13:8000)
    /// - lambda: Use AWS Lambda deployment (AWS-generated endpoints)
    /// - production: Use custom domains (api.kingdoms.ninja, wss.kingdoms.ninja)
    enum APIEnvironment {
        case local
        case lambda
        case production
    }
    
    /// Set this to switch between local, Lambda, and production API
    static let apiEnvironment: APIEnvironment = .lambda
    
    /// Backend API base URL
    static var apiBaseURL: String {
        switch apiEnvironment {
        case .local:
            return "http://192.168.1.8:8000"
        case .lambda:
            return "https://eu0qm86e1m.execute-api.us-east-1.amazonaws.com"
        case .production:
            return "https://api.kingdoms.ninja"
        }
    }
    
    /// WebSocket URL for real-time features (Town Pub chat, etc.)
    static var webSocketURL: String {
        switch apiEnvironment {
        case .local:
            return "ws://192.168.1.17:8000/ws"  // Local dev WebSocket
        case .lambda:
            return "wss://02oas6q503.execute-api.us-east-1.amazonaws.com/dev"
        case .production:
            return "wss://wss.kingdoms.ninja"
        }
    }
    
    /// Development mode - mirrors backend DEV_MODE setting
    /// When true:
    /// - Shows dev-only UI hints
    /// - May skip certain validations
    /// - Enables debug features
    static let devMode = false
    
    /// Force show onboarding flow (for testing)
    /// When true, always shows onboarding regardless of user state
    static let forceShowOnboarding = false
    
    /// Contract completion hint time (matches backend behavior)
    /// In dev mode: instant completion
    /// In production: actual time calculations
    static var contractCompletionMultiplier: Double {
        devMode ? 0.0 : 1.0
    }
}

