import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            // Parchment background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                Spacer()
                
                // Logo Section
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Crown with brutalist badge
                    Image(systemName: "crown.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 120)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.inkMedium,
                            cornerRadius: 24,
                            shadowOffset: 6,
                            borderWidth: 4
                        )
                    
                    Text("KINGDOM")
                        .font(FontStyles.displayLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Build Your Empire")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                // Sign In Card
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Text("Begin Your Journey")
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 3)
                    )
                    
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
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .font(FontStyles.iconSmall)
                            Text("Developer Sign In")
                                .font(FontStyles.bodyMediumBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                                    .offset(x: 3, y: 3)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black, lineWidth: 3)
                                    )
                            }
                        )
                    }
                }
                .padding(KingdomTheme.Spacing.xxLarge)
                .brutalistCard(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 20
                )
                .padding(.horizontal, KingdomTheme.Spacing.large)
                
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
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}


