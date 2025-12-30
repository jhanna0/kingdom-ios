import SwiftUI

struct BuildingStatCard: View {
    let icon: String
    let name: String
    let level: Int
    let maxLevel: Int
    let benefit: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [KingdomTheme.Colors.gold.opacity(0.3), KingdomTheme.Colors.gold.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            
            VStack(spacing: 4) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Level dots
                HStack(spacing: 3) {
                    ForEach(1...maxLevel, id: \.self) { lvl in
                        Circle()
                            .fill(lvl <= level ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
                
                Text("Lv \(level)")
                    .font(.caption2.bold())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            
            Text(benefit)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.2), lineWidth: 1)
        )
    }
}
