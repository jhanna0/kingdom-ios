import SwiftUI

// Check-in button - appears when inside a kingdom
struct CheckInButton: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    let onCheckIn: () -> Void
    let onClaim: () -> Void
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Show different button based on state
            if kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                // Can claim this kingdom!
                MedievalActionButton(
                    title: "👑 Claim \(kingdom.name)",
                    color: KingdomTheme.Colors.gold,
                    fullWidth: true
                ) {
                    onClaim()
                }
            } else if !player.isCheckedIn() || player.currentKingdom != kingdom.name {
                // Need to check in
                MedievalActionButton(
                    title: "📍 Check In to \(kingdom.name)",
                    color: KingdomTheme.Colors.buttonSuccess,
                    fullWidth: true
                ) {
                    onCheckIn()
                }
            } else {
                // Already checked in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    Text("Checked in to \(kingdom.name)")
                        .font(KingdomTheme.Typography.subheadline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(KingdomTheme.Spacing.medium)
                .parchmentCard(borderColor: KingdomTheme.Colors.buttonSuccess, hasShadow: false)
            }
        }
        .padding(.horizontal)
    }
}
