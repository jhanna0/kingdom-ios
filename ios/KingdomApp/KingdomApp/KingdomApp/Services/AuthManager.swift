import Foundation
import AuthenticationServices
import SwiftUI
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var isCheckingAuth = true  // NEW: prevents flash
    @Published var authToken: String?
    @Published var currentUser: UserData?
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    init() {
        Task { @MainActor in
            await checkSavedAuth()
        }
    }
    
    // MARK: - Apple Sign In
    
    @MainActor
    func signInWithApple(userID: String, email: String?, name: String?) async {
        do {
            struct AppleSignInRequest: Encodable {
                let apple_user_id: String
                let email: String?
                let display_name: String
            }
            
            let body = AppleSignInRequest(
                apple_user_id: userID,
                email: email,
                display_name: name ?? "User"
            )
            
            let request = try apiClient.request(endpoint: "/auth/apple-signin", method: "POST", body: body)
            let token: TokenResponse = try await apiClient.execute(request)
            
            authToken = token.access_token
            saveToken(token.access_token)
            await fetchUserProfile()
            
            // Check if needs onboarding (no hometown selected yet)
            if currentUser != nil && currentUser!.hometown_kingdom_id == nil {
                needsOnboarding = true
            } else {
                isAuthenticated = true
            }
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
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
            errorMessage = "Registration failed: \(error.localizedDescription)"
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
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func logout() {
        authToken = nil
        currentUser = nil
        isAuthenticated = false
        needsOnboarding = false
        deleteToken()
    }
    
    // MARK: - Onboarding
    
    @MainActor
    func completeOnboarding(displayName: String, hometownKingdomId: String?) async {
        guard authToken != nil else { return }
        
        do {
            struct OnboardingRequest: Encodable {
                let display_name: String
                let hometown_kingdom_id: String?
            }
            
            let body = OnboardingRequest(
                display_name: displayName,
                hometown_kingdom_id: hometownKingdomId
            )
            
            let request = try apiClient.request(endpoint: "/auth/me", method: "PATCH", body: body)
            currentUser = try await apiClient.execute(request)
            
            needsOnboarding = false
            isAuthenticated = true
        } catch {
            errorMessage = "Failed to complete onboarding: \(error.localizedDescription)"
        }
    }
    
    // MARK: - User Profile
    
    @MainActor
    func fetchUserProfile() async {
        guard authToken != nil else { return }
        
        do {
            let request = apiClient.request(endpoint: "/auth/me")
            currentUser = try await apiClient.execute(request)
        } catch {
            print("Failed to fetch user: \(error)")
            logout()
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
        if let token = loadToken() {
            authToken = token
            // Centralized: Set token in APIClient for all API calls
            apiClient.setAuthToken(token)
            await fetchUserProfile()
            if currentUser != nil {
                // Check if user needs onboarding
                if currentUser!.hometown_kingdom_id == nil {
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
    let honor: Int
    let total_checkins: Int
    let total_conquests: Int
    let kingdoms_ruled: Int
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

