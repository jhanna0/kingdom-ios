import Foundation
import UIKit

/// Centralized version/maintenance gate for Kingdom app
/// Checks with backend on startup to ensure:
/// - App version meets minimum requirements
/// - App is not in maintenance mode
/// - Directs users to TestFlight for updates
final class VersionManager {
    static let shared = VersionManager()
    
    private init() {}
    
    // MARK: - Configuration
    private let requestSchemaVersion: String = "1"
    private let testFlightURLString: String = "https://testflight.apple.com/join/4jxSyUmW"
    
    // Cache last-known status to avoid repeated blocking
    private var isBelowMinimumVersion: Bool = false
    private var isMaintenanceMode: Bool = false
    private var maintenanceMessage: String = ""
    private var requiredMinimumVersion: String?
    private var computedUpdateURLString: String?
    
    // MARK: - Startup Check
    func performStartupCheck() async -> Bool {
        // If we already know we must block, re-present gate and stop
        if isBelowMinimumVersion || isMaintenanceMode {
            await presentGateIfNeeded()
            return false
        }
        
        do {
            let config = try await fetchAppConfig()
            processConfig(config)
            
            if isBelowMinimumVersion || isMaintenanceMode {
                await presentGateIfNeeded()
                return false
            }
            
            return true
        } catch {
            print("❌ VersionManager: Failed to fetch config: \(error)")
            // Don't block on network errors - allow app to continue
            // This prevents users from being locked out due to temporary network issues
            return true
        }
    }
    
    // MARK: - Fetch Config
    private func fetchAppConfig() async throws -> AppConfigResponse {
        let urlString = "\(AppConfig.apiBaseURL)/app-config"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw VersionError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "app_version", value: Self.currentAppVersionString()),
            URLQueryItem(name: "build", value: Self.currentBuildNumberString()),
            URLQueryItem(name: "schema_version", value: requestSchemaVersion)
        ]
        
        guard let url = urlComponents.url else {
            throw VersionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VersionError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VersionError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AppConfigResponse.self, from: data)
    }
    
    // MARK: - Process Config
    private func processConfig(_ config: AppConfigResponse) {
        // Extract values
        let maintenance = config.maintenance
        let maintenanceMsg = config.maintenanceMessage ?? "Kingdom: Territory is undergoing maintenance. Please try again later."
        let minVersion = config.minVersion ?? config.minIosVersion
        let updateURL = config.linkUrl ?? config.testflightUrl ?? config.updateUrl
        
        // Check minimum version requirement
        if let minVersion = minVersion {
            let comparison = Self.compareVersions(Self.currentAppVersionString(), minVersion)
            isBelowMinimumVersion = (comparison == .orderedAscending)
            requiredMinimumVersion = minVersion
            computedUpdateURLString = updateURL ?? testFlightURLString
        } else {
            isBelowMinimumVersion = false
            requiredMinimumVersion = nil
            computedUpdateURLString = nil
        }
        
        isMaintenanceMode = maintenance
        maintenanceMessage = maintenanceMsg
        
        print("📱 VersionManager: Config loaded")
        print("   Current version: \(Self.currentAppVersionString())")
        print("   Minimum version: \(minVersion ?? "none")")
        print("   Maintenance mode: \(maintenance)")
        print("   Below minimum: \(isBelowMinimumVersion)")
    }
    
    // MARK: - Present Gates
    @MainActor
    private func presentGateIfNeeded() {
        if self.isBelowMinimumVersion {
            let urlString = computedUpdateURLString ?? testFlightURLString
            AppBlockingVC.showUpdateRequired(updateURLString: urlString)
            return
        }
        
        if self.isMaintenanceMode {
            AppBlockingVC.showMaintenance(message: self.maintenanceMessage)
            return
        }
        
        // Default/fallback: connection issue or unknown blocking state
        AppBlockingVC.showConnectionError()
    }
    
    // MARK: - Utilities
    static func currentAppVersionString() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    static func currentBuildNumberString() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        return lhs.compare(rhs, options: .numeric)
    }
}

// MARK: - Models

struct AppConfigResponse: Codable {
    let status: Int?
    let maintenance: Bool
    let maintenanceMessage: String?
    let minVersion: String?
    let minIosVersion: String?  // Alias
    let linkUrl: String?
    let testflightUrl: String?  // Alias
    let updateUrl: String?  // Alias
    let platform: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case maintenance
        case maintenanceMessage = "maintenance_message"
        case minVersion = "min_version"
        case minIosVersion = "min_ios_version"
        case linkUrl = "link_url"
        case testflightUrl = "testflight_url"
        case updateUrl = "update_url"
        case platform
    }
}

// MARK: - Errors

enum VersionError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

