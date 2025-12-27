import SwiftUI

// Check-in button - appears when inside a kingdom
struct CheckInButton: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    let onCheckIn: () -> Void
    let onClaim: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Show different button based on state
            if kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                // Can claim this kingdom!
                MedievalActionButton(
                    title: "👑 Claim \(kingdom.name)",
                    color: Color(red: 0.6, green: 0.4, blue: 0.1),
                    fullWidth: true
                ) {
                    onClaim()
                }
            } else if !player.isCheckedIn() || player.currentKingdom != kingdom.name {
                // Need to check in
                MedievalActionButton(
                    title: "📍 Check In to \(kingdom.name)",
                    color: Color(red: 0.2, green: 0.5, blue: 0.3),
                    fullWidth: true
                ) {
                    onCheckIn()
                }
            } else {
                // Already checked in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.3))
                    Text("Checked in to \(kingdom.name)")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                }
                .padding(12)
                .background(Color(red: 0.95, green: 0.87, blue: 0.70))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.2, green: 0.5, blue: 0.3), lineWidth: 2)
                )
            }
        }
        .padding(.horizontal)
    }
}

