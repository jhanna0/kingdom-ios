import Foundation
import AuthenticationServices
import SwiftUI
import Combine
import UIKit

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var isCheckingAuth = true  // NEW: prevents flash
    @Published var authToken: String?
    @Published var currentUser: UserData?
    @Published var hasCriticalError = false  // Blocks UI until resolved
    @Published var criticalErrorMessage: String?
    
    private let apiClient = APIClient.shared
    
    init() {
        Task { @MainActor in
            await checkSavedAuth()
        }
    }
    
    // MARK: - Apple Sign In
    
    @MainActor
    func signInWithApple(userID: String, identityToken: String? = nil, email: String?, name: String?) async {
        DebugLogger.shared.log("signIn_start", message: "Starting Apple Sign In", extra: [
            "hasIdentityToken": identityToken != nil,
            "hasEmail": email != nil,
            "hasName": name != nil
        ])
        
        do {
            struct AppleSignInRequest: Encodable {
                let apple_user_id: String
                let identity_token: String?  // SECURITY: JWT signed by Apple for server verification
                let email: String?
                let display_name: String
                let device_id: String?  // For multi-account detection
            }
            
            let body = AppleSignInRequest(
                apple_user_id: userID,
                identity_token: identityToken,
                email: email,
                display_name: name ?? "User",
                device_id: UIDevice.current.identifierForVendor?.uuidString
            )
            
            DebugLogger.shared.log("signIn_request", message: "Sending request to /auth/apple-signin")
            
            let request = try apiClient.request(endpoint: "/auth/apple-signin", method: "POST", body: body)
            let token: TokenResponse = try await apiClient.execute(request)
            
            DebugLogger.shared.log("signIn_token_received", message: "Token received from server")
            
            authToken = token.access_token
            saveToken(token.access_token)
            
            DebugLogger.shared.log("signIn_token_saved", message: "Token saved to keychain")
            
            await fetchUserProfile()
            
            DebugLogger.shared.log("signIn_profile_fetched", message: "User profile fetched", extra: [
                "hasCurrentUser": currentUser != nil,
                "needsOnboarding": currentUser?.needsOnboarding ?? false
            ])
            
            // Check if needs onboarding (no hometown OR no proper display name)
            if let user = currentUser, user.needsOnboarding {
                needsOnboarding = true
                DebugLogger.shared.log("signIn_complete", message: "Sign in complete - needs onboarding")
            } else {
                isAuthenticated = true
                DebugLogger.shared.log("signIn_complete", message: "Sign in complete - fully authenticated")
            }
        } catch {
            DebugLogger.shared.log("signIn_error", message: "Sign in failed: \(error.localizedDescription)")
            // CRITICAL ERROR - sign in failed, block everything
            hasCriticalError = true
            criticalErrorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Email/Password
    
    @MainActor
    func register(email: String, username: String, password: String, displayName: String) async {
        do {
            struct RegisterRequest: Encodable {
                let email: String
                let username: String
                let password: String
                let display_name: String
            }
            
            let body = RegisterRequest(
                email: email,
                username: username,
                password: password,
                display_name: displayName
            )
            
            let request = try apiClient.request(endpoint: "/auth/register", method: "POST", body: body)
            let token: TokenResponse = try await apiClient.execute(request)
            
            authToken = token.access_token
            saveToken(token.access_token)
            await fetchUserProfile()
            isAuthenticated = true
        } catch {
            // CRITICAL ERROR - registration failed, block everything
            hasCriticalError = true
            criticalErrorMessage = "Registration failed: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func login(identifier: String, password: String) async {
        do {
            struct LoginRequest: Encodable {
                let identifier: String
                let password: String
            }
            
            let body = LoginRequest(
                identifier: identifier,
                password: password
            )
            
            let request = try apiClient.request(endpoint: "/auth/login", method: "POST", body: body)
            let token: TokenResponse = try await apiClient.execute(request)
            
            authToken = token.access_token
            saveToken(token.access_token)
            await fetchUserProfile()
            isAuthenticated = true
        } catch {
            // CRITICAL ERROR - login failed, block everything
            hasCriticalError = true
            criticalErrorMessage = "Login failed: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func logout() {
        authToken = nil
        currentUser = nil
        isAuthenticated = false
        needsOnboarding = false
        hasCriticalError = false
        criticalErrorMessage = nil
        deleteToken()
        
        // Disconnect from game events WebSocket
        GameEventManager.shared.disconnect()
    }
    
    @MainActor
    func retryAuth() async {
        hasCriticalError = false
        criticalErrorMessage = nil
        await fetchUserProfile()
        
        if let user = currentUser, !hasCriticalError {
            // Success - check onboarding status
            if user.needsOnboarding {
                needsOnboarding = true
            } else {
                isAuthenticated = true
            }
        }
    }
    
    // MARK: - Demo Login (App Review)
    
    @MainActor
    func demoLogin(secret: String) async {
        do {
            struct DemoLoginRequest: Encodable {
                let secret: String
            }
            
            let body = DemoLoginRequest(secret: secret)
            let request = try apiClient.request(endpoint: "/auth/demo-login", method: "POST", body: body)
            let token: TokenResponse = try await apiClient.execute(request)
            
            authToken = token.access_token
            saveToken(token.access_token)
            await fetchUserProfile()
            
            if let user = currentUser, user.needsOnboarding {
                needsOnboarding = true
            } else {
                isAuthenticated = true
            }
        } catch {
            hasCriticalError = true
            criticalErrorMessage = "Demo login failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Onboarding
    
    @MainActor
    func completeOnboarding(displayName: String, hometownKingdomId: String?) async {
        guard authToken != nil else {
            DebugLogger.shared.log("onboarding_error", message: "No auth token for onboarding")
            return
        }
        
        DebugLogger.shared.log("onboarding_start", message: "Starting onboarding", extra: [
            "displayName": displayName,
            "hasHometownKingdomId": hometownKingdomId != nil
        ])
        
        do {
            struct OnboardingRequest: Encodable {
                let display_name: String
                let hometown_kingdom_id: String?
            }
            
            let body = OnboardingRequest(
                display_name: displayName,
                hometown_kingdom_id: hometownKingdomId
            )
            
            DebugLogger.shared.log("onboarding_request", message: "Sending PATCH to /auth/me")
            
            let request = try apiClient.request(endpoint: "/auth/me", method: "PATCH", body: body)
            currentUser = try await apiClient.execute(request)
            
            DebugLogger.shared.log("onboarding_response", message: "Onboarding response received")
            
            needsOnboarding = false
            isAuthenticated = true
            
            DebugLogger.shared.log("onboarding_complete", message: "Onboarding complete - user authenticated")
        } catch {
            DebugLogger.shared.log("onboarding_error", message: "Onboarding failed: \(error.localizedDescription)")
            // CRITICAL ERROR - onboarding failed, block everything
            hasCriticalError = true
            criticalErrorMessage = "Failed to complete onboarding: \(error.localizedDescription)"
        }
    }
    
    // MARK: - User Profile
    
    @MainActor
    func fetchUserProfile() async {
        guard authToken != nil else { return }
        
        do {
            let request = apiClient.request(endpoint: "/auth/me")
            currentUser = try await apiClient.execute(request)
            hasCriticalError = false
            criticalErrorMessage = nil
        } catch {
            print("Failed to fetch user: \(error)")
            
            // This is CRITICAL - user cannot proceed without profile
            hasCriticalError = true
            
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let message):
                    if message.contains("500") {
                        criticalErrorMessage = "Server error while loading your profile. The kingdom servers may be down. Please try again."
                    } else {
                        criticalErrorMessage = "Failed to load profile: \(message)"
                    }
                case .networkError:
                    criticalErrorMessage = "No internet connection. Please check your network and try again."
                case .unauthorized:
                    criticalErrorMessage = "Your session has expired. Please sign in again."
                    logout()
                default:
                    criticalErrorMessage = "Failed to load your profile: \(error.localizedDescription)"
                }
            } else {
                criticalErrorMessage = "Failed to load your profile: \(error.localizedDescription)"
            }
            
            // Don't auto-logout on server errors - let user retry
            if case .unauthorized = error as? APIError {
                logout()
            }
        }
    }
    
    // MARK: - Token Storage
    
    private func saveToken(_ token: String) {
        print("🔐 AuthManager: Saving token to Keychain")
        KeychainHelper.save(token: token)
        // Centralized: APIClient is the single source of truth for auth
        apiClient.setAuthToken(token)
        print("✅ AuthManager: Token saved and set in APIClient")
    }
    
    private func loadToken() -> String? {
        let token = KeychainHelper.load()
        if token != nil {
            print("🔐 AuthManager: Token loaded from Keychain")
        } else {
            print("⚠️ AuthManager: No token found in Keychain")
        }
        return token
    }
    
    private func deleteToken() {
        print("🔓 AuthManager: Deleting token from Keychain")
        KeychainHelper.delete()
        // Centralized: Clear from APIClient
        apiClient.clearAuth()
    }
    
    @MainActor
    private func checkSavedAuth() async {
        // FIRST: Check version requirements before authentication
        let versionCheckPassed = await VersionManager.shared.performStartupCheck()
        if !versionCheckPassed {
            print("❌ AuthManager: Version check failed, blocking app")
            isCheckingAuth = false
            return
        }
        
        if let token = loadToken() {
            authToken = token
            // Centralized: Set token in APIClient for all API calls
            apiClient.setAuthToken(token)
            await fetchUserProfile()
            if let user = currentUser {
                // Check if user needs onboarding (no hometown OR no proper display name)
                if user.needsOnboarding {
                    needsOnboarding = true
                } else {
                    isAuthenticated = true
                }
            }
        }
        isCheckingAuth = false  // Done checking
    }
}

// MARK: - Models

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct UserData: Codable {
    let id: Int  // PostgreSQL auto-generated integer ID
    let display_name: String
    let email: String?
    let hometown_kingdom_id: String?
    let gold: Int
    let level: Int
    let experience: Int
    let reputation: Int
    let total_checkins: Int
    let total_conquests: Int
    let kingdoms_ruled: Int
    
    /// Returns true if the user needs to complete onboarding
    /// (missing hometown kingdom OR has a placeholder/empty display name)
    var needsOnboarding: Bool {
        // Force onboarding for testing
        if AppConfig.forceShowOnboarding {
            return true
        }
        
        // No hometown kingdom selected
        if hometown_kingdom_id == nil || hometown_kingdom_id?.isEmpty == true {
            return true
        }
        
        // Placeholder or empty display name
        let trimmedName = display_name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == "User" {
            return true
        }
        
        return false
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static func save(token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

