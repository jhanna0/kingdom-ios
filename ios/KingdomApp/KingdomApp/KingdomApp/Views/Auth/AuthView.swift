import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            // Medieval background
            LinearGradient(colors: [.brown.opacity(0.3), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.yellow)
                    
                    Text("KINGDOM")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(.yellow)
                    
                    Text("Build Your Empire")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(10)
                .padding(.horizontal, 40)
                
                // Developer Sign In
                Button(action: {
                    Task {
                        await authManager.signInWithApple(
                            userID: "appletest",
                            email: "appletest@example.com",
                            name: "Apple Reviewer"
                        )
                    }
                }) {
                    Text("Developer Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer()
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                let email = credential.email
                let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                Task {
                    await authManager.signInWithApple(
                        userID: userID,
                        email: email,
                        name: name.isEmpty ? nil : name
                    )
                }
            }
        case .failure(let error):
            authManager.errorMessage = error.localizedDescription
        }
    }
}


