import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var appleSignInCoordinator: AppleSignInCoordinator?
    
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
                    
                    // Apple Sign In
                    Button(action: {
                        performAppleSignIn()
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(FontStyles.iconSmall)
                            Text("Sign in with Apple")
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
                                    .fill(Color.black)
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
    
    private func performAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let coordinator = AppleSignInCoordinator(authManager: authManager)
        self.appleSignInCoordinator = coordinator
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.performRequests()
    }
}

// Coordinator to handle Apple Sign In
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
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
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In failed: \(error.localizedDescription)")
    }
}


