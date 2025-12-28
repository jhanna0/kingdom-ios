import SwiftUI

// Player HUD - shows player status
struct PlayerHUD: View {
    @ObservedObject var player: Player
    let currentKingdom: Kingdom?
    @ObservedObject var apiService: KingdomAPIService
    @State private var showingAPIDebug = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            HStack(spacing: 8) {
                Text(player.isRuler ? "👑" : "⚔️")
                    .font(.title3)
                Text(player.name)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                // API Status Indicator
                Button {
                    showingAPIDebug = true
                } label: {
                    Circle()
                        .fill(apiService.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Label("\(player.gold)g", systemImage: "dollarsign.circle.fill")
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .font(KingdomTheme.Typography.subheadline())
                
                if player.isRuler {
                    Label("\(player.fiefsRuled.count)", systemImage: "crown.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        .font(KingdomTheme.Typography.subheadline())
                }
            }
            
            if let kingdom = currentKingdom {
                Text("📍 \(kingdom.name)")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else {
                Text("🗺️ Traveling...")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .parchmentCard()
        .sheet(isPresented: $showingAPIDebug) {
            APIDebugView()
        }
    }
}
