import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var appleSignInCoordinator: AppleSignInCoordinator?
    @State private var logoTapCount = 0
    @State private var showDemoLogin = false
    
    var body: some View {
        ZStack {
            // Parchment background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                Spacer()
                
                // Logo Section
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Crown with brutalist badge - tap 5 times for demo login
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
                        .onTapGesture {
                            logoTapCount += 1
                            if logoTapCount >= 5 {
                                logoTapCount = 0
                                showDemoLogin = true
                            }
                        }
                    
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
                    
                    // Dev login button
                    #if DEBUG
                    Button(action: {
                        Task {
                            await authManager.signInWithApple(userID: "appletest", email: nil, name: nil)
                        }
                    }) {
                        Text("🧪 Dev Login (Apple the Wise)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    #endif
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
        .sheet(isPresented: $showDemoLogin) {
            DemoLoginSheet(authManager: authManager, isPresented: $showDemoLogin)
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
            
            // SECURITY: Extract the identity token - this is a JWT signed by Apple
            // that proves the user actually authenticated. The backend MUST verify this.
            var identityTokenString: String? = nil
            if let identityTokenData = credential.identityToken,
               let tokenString = String(data: identityTokenData, encoding: .utf8) {
                identityTokenString = tokenString
            }
            
            Task {
                await authManager.signInWithApple(
                    userID: userID,
                    identityToken: identityTokenString,
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

// MARK: - Demo Login Sheet (App Review)

struct DemoLoginSheet: View {
    let authManager: AuthManager
    @Binding var isPresented: Bool
    @State private var secretCode = ""
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                .padding(.top, KingdomTheme.Spacing.medium)
                .padding(.horizontal, KingdomTheme.Spacing.medium)
                
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Text("Royal Access")
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Enter the code for App Review access.")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    Text("Code")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    TextField("Code", text: $secretCode)
                        .font(FontStyles.bodyLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .textFieldStyle(.plain)
                        .padding(KingdomTheme.Spacing.medium)
                        .background(Color.white)
                        .cornerRadius(KingdomTheme.Brutalist.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
                
                Button(action: {
                    Task {
                        await authManager.demoLogin(secret: secretCode)
                        isPresented = false
                    }
                }) {
                    HStack {
                        Text("Enter the Kingdom")
                            .font(FontStyles.bodyLargeBold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KingdomTheme.Spacing.large)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .fill(Color.black)
                                .offset(x: 4, y: 4)
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .fill(secretCode.isEmpty ? KingdomTheme.Colors.disabled : KingdomTheme.Colors.buttonPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                        .stroke(Color.black, lineWidth: 3)
                                )
                        }
                    )
                }
                .disabled(secretCode.isEmpty)
                .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
                .padding(.bottom, KingdomTheme.Spacing.xxLarge)
                
                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
