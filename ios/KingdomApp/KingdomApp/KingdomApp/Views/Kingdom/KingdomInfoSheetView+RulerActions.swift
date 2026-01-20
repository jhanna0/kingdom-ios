import SwiftUI

// MARK: - Ruler Actions

extension KingdomInfoSheetView {
    
    // MARK: - Ruler Actions Section
    
    @ViewBuilder
    var rulerActionsSection: some View {
        if isPlayerInside && kingdom.rulerId == player.playerId {
            // Player is ruler of this kingdom
            HStack(spacing: 10) {
                Button(action: onViewKingdom) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        Text("Manage")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                }
                
                Button(action: onViewAllKingdoms) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        Text("My Empire")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                }
                
                Spacer()
            }
            .padding(.horizontal)
        } else if kingdom.canClaim {
            // Backend says we can claim!
            claimKingdomButton
                .padding(.horizontal)
        } else if isPlayerInside {
            // Already present but someone else rules it
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("You are here")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(KingdomTheme.Spacing.small)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
            .padding(.horizontal)
        } else {
            // Not inside this kingdom
            HStack(spacing: 6) {
                Image(systemName: "location.circle")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("You must travel here first")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .padding(KingdomTheme.Spacing.small)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Claim Kingdom Button
    
    private var claimKingdomButton: some View {
        Button(action: {
            performClaimKingdom()
        }) {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                if isClaiming {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Text(isClaiming ? "Claiming Your Kingdom..." : "Claim This Kingdom")
                    .font(FontStyles.headingMedium)
                    .fontWeight(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KingdomTheme.Spacing.large)
            .foregroundColor(.white)
        }
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 12, shadowOffset: 4, borderWidth: 3)
        .disabled(isClaiming)
        .alert("Claim Failed", isPresented: $showClaimError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(claimErrorMessage)
        }
    }
    
    // MARK: - Claim Action
    
    func performClaimKingdom() {
        isClaiming = true
        Task {
            do {
                try await viewModel.claimKingdom()
                // Dismiss sheet after short delay to let celebration popup show
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                dismiss()
            } catch {
                isClaiming = false
                claimErrorMessage = error.localizedDescription
                showClaimError = true
                print("❌ Failed to claim: \(error.localizedDescription)")
            }
        }
    }
}
