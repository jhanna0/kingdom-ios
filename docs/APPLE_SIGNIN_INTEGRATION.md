# Apple Sign In Integration Guide

This guide explains how to integrate "Sign in with Apple" into your Kingdom iOS app and backend.

## Overview

Sign in with Apple provides a secure, privacy-focused way for users to create accounts and sign in to your app. Apple requires all apps that offer third-party sign-in options to also offer Sign in with Apple.

## Difficulty Assessment

**Integration Difficulty: MODERATE** ⭐⭐⭐☆☆

- **Backend Setup:** Easy (already done!)
- **Apple Developer Setup:** Moderate (requires Apple Developer account)
- **iOS Implementation:** Easy-Moderate (SwiftUI has native support)
- **Total Time:** 2-4 hours for first-time setup

## Backend Setup (✅ Already Complete!)

Your backend is already set up to handle Apple Sign In! The endpoint is ready at:

```
POST /auth/apple-signin
```

**Request body:**
```json
{
  "apple_user_id": "001234.abc123...",
  "email": "user@example.com",
  "display_name": "John Doe"
}
```

The backend will:
1. Check if a user with this Apple ID already exists
2. If yes, log them in
3. If no, create a new account automatically
4. Return a JWT token for authentication

## Step 1: Apple Developer Account Setup

### Prerequisites
- Active Apple Developer Account ($99/year)
- Access to App Store Connect

### 1.1 Create App ID with Sign in with Apple

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** → **App IDs**
4. Create a new App ID or edit existing:
   - Bundle ID: `com.yourcompany.kingdom` (must match Xcode)
   - Enable "Sign in with Apple" capability
   - Click "Save"

### 1.2 Create Service ID (Optional - for Web)

Only needed if you want web-based sign in:

1. In Identifiers, create new **Service ID**
2. Identifier: `com.yourcompany.kingdom.service`
3. Enable "Sign in with Apple"
4. Configure domains and redirect URLs for your web app

### 1.3 Create Key for Server Communication (Optional)

Only needed if you want to verify tokens server-side:

1. Navigate to **Keys**
2. Create new key
3. Enable "Sign in with Apple"
4. Download the `.p8` file (keep it secure!)
5. Note the Key ID

## Step 2: Xcode Project Setup

### 2.1 Add Sign in with Apple Capability

1. Open your Xcode project
2. Select your target → **Signing & Capabilities**
3. Click **+ Capability**
4. Add "Sign in with Apple"

### 2.2 Verify Bundle ID

Ensure your bundle identifier matches what you configured in Apple Developer:
- Should be: `com.yourcompany.kingdom` (or whatever you set)

## Step 3: iOS Implementation

### 3.1 Create AppleSignInButton Component

Create a new file `Views/Auth/AppleSignInButton.swift`:

```swift
import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    handleSignInWithApple(result: result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
            
            if isLoading {
                ProgressView()
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    private func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let appleUserID = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                // Create display name from full name
                var displayName = ""
                if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                    displayName = "\(givenName) \(familyName)"
                }
                
                // Send to your backend
                Task {
                    await authManager.signInWithApple(
                        appleUserID: appleUserID,
                        email: email,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                    isLoading = false
                }
            }
            
        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
```

### 3.2 Create AuthenticationManager

Create `Services/AuthenticationManager.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserPrivate?
    @Published var authToken: String?
    
    private let baseURL = "http://localhost:8000"  // Your API URL
    
    // MARK: - Apple Sign In
    
    func signInWithApple(appleUserID: String, email: String?, displayName: String?) async {
        do {
            let requestBody: [String: Any] = [
                "apple_user_id": appleUserID,
                "email": email as Any,
                "display_name": displayName as Any
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/apple-signin")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.authToken = tokenResponse.access_token
                
                // Save token to keychain
                KeychainHelper.save(token: tokenResponse.access_token)
                
                // Fetch user profile
                await fetchCurrentUser()
                
                self.isAuthenticated = true
            } else {
                throw AuthError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            print("Apple Sign In error: \(error)")
        }
    }
    
    // MARK: - Email/Password Registration
    
    func register(email: String, username: String, password: String, displayName: String) async {
        do {
            let requestBody: [String: String] = [
                "email": email,
                "username": username,
                "password": password,
                "display_name": displayName
            ]
            
            let jsonData = try JSONEncoder().encode(requestBody)
            
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/register")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if httpResponse.statusCode == 201 {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.authToken = tokenResponse.access_token
                KeychainHelper.save(token: tokenResponse.access_token)
                await fetchCurrentUser()
                self.isAuthenticated = true
            } else {
                throw AuthError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            print("Registration error: \(error)")
        }
    }
    
    // MARK: - Login
    
    func login(identifier: String, password: String) async {
        do {
            let requestBody: [String: String] = [
                "identifier": identifier,
                "password": password
            ]
            
            let jsonData = try JSONEncoder().encode(requestBody)
            
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/login")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.authToken = tokenResponse.access_token
                KeychainHelper.save(token: tokenResponse.access_token)
                await fetchCurrentUser()
                self.isAuthenticated = true
            } else {
                throw AuthError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            print("Login error: \(error)")
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        KeychainHelper.delete()
        self.authToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Fetch User
    
    func fetchCurrentUser() async {
        guard let token = authToken else { return }
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/auth/me")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(UserPrivate.self, from: data)
            self.currentUser = user
        } catch {
            print("Fetch user error: \(error)")
        }
    }
    
    // MARK: - Check Saved Token
    
    func checkSavedAuthentication() async {
        if let token = KeychainHelper.load() {
            self.authToken = token
            await fetchCurrentUser()
            if currentUser != nil {
                self.isAuthenticated = true
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

struct UserPrivate: Codable {
    let id: String
    let email: String?
    let username: String
    let display_name: String
    let avatar_url: String?
    let gold: Int
    let level: Int
    let experience: Int
    let reputation: Int
    let honor: Int
    let total_checkins: Int
    let total_conquests: Int
    let kingdoms_ruled: Int
    let is_premium: Bool
    let premium_expires_at: String?
    let is_verified: Bool
    let last_login: String?
    let created_at: String
    let has_apple_connected: Bool
    let has_google_connected: Bool
}

enum AuthError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
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
```

### 3.3 Create Login/Registration View

Create `Views/Auth/AuthView.swift`:

```swift
import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showEmailAuth = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Logo and Title
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                
                Text("Kingdom")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Build your empire, one city at a time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sign in with Apple
            AppleSignInButton()
                .padding(.horizontal, 40)
            
            // Or divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            
            // Email/Password option
            Button {
                showEmailAuth = true
            } label: {
                Text("Continue with Email")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
        }
    }
}
```

### 3.4 Update Your App Entry Point

Update `KingdomAppApp.swift`:

```swift
import SwiftUI

@main
struct KingdomAppApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
    }
}
```

## Step 4: Testing

### 4.1 Simulator Testing

1. Run app in iOS Simulator
2. Click "Sign in with Apple"
3. Simulator will show test Apple ID dialog
4. Use your Apple ID (or create test account)

### 4.2 Device Testing

1. Connect physical device
2. Ensure device has Apple ID signed in
3. Run app on device
4. Sign in will use real Apple ID

### 4.3 Backend Testing

Test the endpoint directly:

```bash
curl -X POST http://localhost:8000/auth/apple-signin \
  -H "Content-Type: application/json" \
  -d '{
    "apple_user_id": "001234.abc123def456",
    "email": "user@example.com",
    "display_name": "Test User"
  }'
```

## Security Considerations

### ✅ What We Handle

- **JWT Token Security**: Tokens stored in iOS Keychain (most secure)
- **Password Hashing**: Using bcrypt (industry standard)
- **OAuth Validation**: Apple's built-in validation
- **Token Expiration**: 7-day tokens with refresh capability

### ⚠️ Production Recommendations

1. **Change JWT Secret**: Set `JWT_SECRET_KEY` environment variable to a strong random string
2. **Enable HTTPS**: Use SSL certificates in production
3. **Token Verification**: Optionally verify Apple tokens server-side
4. **Rate Limiting**: Add rate limiting to prevent abuse
5. **CORS Configuration**: Restrict `allow_origins` to your domains

## Environment Variables

Add these to your production environment:

```bash
# Required
DATABASE_URL=postgresql://user:pass@host:5432/kingdom
JWT_SECRET_KEY=your-super-secret-key-min-32-chars

# Optional - for server-side Apple token verification
APPLE_TEAM_ID=ABC123
APPLE_KEY_ID=DEF456
APPLE_PRIVATE_KEY_PATH=/path/to/key.p8
```

## Common Issues & Solutions

### Issue: "Sign in with Apple" button not showing
**Solution**: Ensure capability is added in Xcode and Bundle ID matches Apple Developer portal

### Issue: "Invalid grant" error
**Solution**: Check that your Service ID configuration matches your domain

### Issue: Email is null after sign-in
**Solution**: Apple may not provide email on subsequent sign-ins, or user chose to hide email

### Issue: Token expired
**Solution**: Implement token refresh logic or prompt user to sign in again

## Next Steps

1. ✅ Backend is ready!
2. ⬜ Set up Apple Developer account
3. ⬜ Add Sign in with Apple capability in Xcode
4. ⬜ Implement iOS auth components
5. ⬜ Test on simulator and device
6. ⬜ Deploy backend with proper environment variables

## Resources

- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
- [SwiftUI Authentication](https://developer.apple.com/documentation/authenticationservices)

## Support

Your backend API documentation is available at:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

All authentication endpoints are under `/auth/`

