import SwiftUI

struct BuildingStatCard: View {
    let icon: String
    let name: String
    let level: Int
    let maxLevel: Int
    let benefit: String
    let buildingType: String
    let kingdom: Kingdom
    let player: Player
    var iconColor: Color = KingdomTheme.Colors.inkMedium
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with brutalist style
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .brutalistBadge(
                    backgroundColor: iconColor,
                    cornerRadius: 12,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(spacing: 4) {
                Text(name)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Level dots with better styling
                HStack(spacing: 4) {
                    ForEach(1...maxLevel, id: \.self) { lvl in
                        Circle()
                            .fill(lvl <= level ? iconColor : KingdomTheme.Colors.inkDark.opacity(0.2))
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(lvl <= level ? 0.5 : 0.1), lineWidth: 0.5)
                            )
                    }
                }
                
                Text("Lv \(level)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(iconColor)
            }
            
            Text(benefit)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
}
