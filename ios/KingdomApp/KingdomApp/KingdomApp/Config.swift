import Foundation

/// Centralized app configuration
enum AppConfig {
    /// Backend API base URL
    /// TODO: Replace with your Mac's IP address
    /// Run in terminal: ipconfig getifaddr en0
    static let apiBaseURL = "http://192.168.1.13:8000"
    
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

