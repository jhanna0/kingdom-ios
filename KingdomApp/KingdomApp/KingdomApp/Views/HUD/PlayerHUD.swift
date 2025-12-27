import SwiftUI

// Player HUD - shows player status
struct PlayerHUD: View {
    @ObservedObject var player: Player
    let currentKingdom: Kingdom?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(player.isRuler ? "👑" : "⚔️")
                    .font(.title3)
                Text(player.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
            }
            
            HStack(spacing: 12) {
                Label("\(player.gold)g", systemImage: "dollarsign.circle.fill")
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    .font(.system(.subheadline, design: .serif))
                
                if player.isRuler {
                    Label("\(player.fiefsRuled.count)", systemImage: "crown.fill")
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
                        .font(.system(.subheadline, design: .serif))
                }
            }
            
            if let kingdom = currentKingdom {
                Text("📍 \(kingdom.name)")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            } else {
                Text("🗺️ Traveling...")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
            }
        }
        .padding(12)
        .background(Color(red: 0.95, green: 0.87, blue: 0.70))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 2, y: 3)
    }
}

