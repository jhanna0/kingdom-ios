import Foundation
import AuthenticationServices
import SwiftUI
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var authToken: String?
    @Published var currentUser: UserData?
    @Published var errorMessage: String?
    
    private let baseURL = AppConfig.apiBaseURL
    
    init() {
        Task { @MainActor in
            await checkSavedAuth()
        }
    }
    
    // MARK: - Apple Sign In
    
    @MainActor
    func signInWithApple(userID: String, email: String?, name: String?) async {
        do {
            let body: [String: Any?] = [
                "apple_user_id": userID,
                "email": email,
                "display_name": name ?? "User"
            ]
            
            let data = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/apple-signin")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(TokenResponse.self, from: responseData)
            
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
            let body: [String: String] = [
                "email": email,
                "username": username,
                "password": password,
                "display_name": displayName
            ]
            
            let data = try JSONEncoder().encode(body)
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/register")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(TokenResponse.self, from: responseData)
            
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
            let body: [String: String] = [
                "identifier": identifier,
                "password": password
            ]
            
            let data = try JSONEncoder().encode(body)
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/login")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(TokenResponse.self, from: responseData)
            
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
        guard let token = authToken else { return }
        
        do {
            let body: [String: Any?] = [
                "display_name": displayName,
                "hometown_kingdom_id": hometownKingdomId
            ]
            
            let data = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/me")!)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            currentUser = try JSONDecoder().decode(UserData.self, from: responseData)
            
            needsOnboarding = false
            isAuthenticated = true
        } catch {
            errorMessage = "Failed to complete onboarding: \(error.localizedDescription)"
        }
    }
    
    // MARK: - User Profile
    
    @MainActor
    func fetchUserProfile() async {
        guard let token = authToken else { return }
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/me")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            currentUser = try JSONDecoder().decode(UserData.self, from: data)
        } catch {
            print("Failed to fetch user: \(error)")
            logout()
        }
    }
    
    // MARK: - Token Storage
    
    private func saveToken(_ token: String) {
        KeychainHelper.save(token: token)
    }
    
    private func loadToken() -> String? {
        return KeychainHelper.load()
    }
    
    private func deleteToken() {
        KeychainHelper.delete()
    }
    
    @MainActor
    private func checkSavedAuth() async {
        if let token = loadToken() {
            authToken = token
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
    }
}

// MARK: - Models

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct UserData: Codable {
    let id: String
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

