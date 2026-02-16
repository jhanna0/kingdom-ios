import SwiftUI

/// View for account deletion with confirmation
struct DeleteAccountView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showConfirmation = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(KingdomTheme.Colors.error)
                    .padding(.top, 32)
                
                // Title
                Text("Delete Account")
                    .font(KingdomTheme.Typography.title())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Warning Message
                VStack(alignment: .leading, spacing: 16) {
                    Text("This action cannot be undone.")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.error)
                    
                    Text("Deleting your account will:")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint(icon: "person.slash", text: "Remove your profile and game progress")
                        BulletPoint(icon: "crown.fill", text: "Delete your kingdoms and conquests")
                        BulletPoint(icon: "chart.bar.xaxis", text: "Remove you from all leaderboards")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .brutalistCard(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 12
                )
                
                // Delete Button
                Button {
                    showConfirmation = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "trash.fill")
                                .font(FontStyles.iconSmall)
                        }
                        Text(isDeleting ? "Deleting..." : "Delete My Account")
                            .font(FontStyles.bodyMediumBold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .disabled(isDeleting)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonDanger,
                    cornerRadius: 12,
                    shadowOffset: 3,
                    borderWidth: 2
                )
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Delete Account?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure? This cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func deleteAccount() async {
        isDeleting = true
        
        do {
            try await authManager.deleteAccount()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            showError = true
            isDeleting = false
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(AuthManager())
    }
}
