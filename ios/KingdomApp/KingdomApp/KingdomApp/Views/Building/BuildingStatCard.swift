import SwiftUI

struct BuildingStatCard: View {
    let icon: String
    let name: String
    let level: Int
    let maxLevel: Int
    let benefit: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(KingdomTheme.Colors.goldWarm)
            
            Text(name)
                .font(KingdomTheme.Typography.subheadline())
                .fontWeight(.semibold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Level \(level)/\(maxLevel)")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text(benefit)
                .font(KingdomTheme.Typography.caption2())
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .parchmentCard(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: KingdomTheme.CornerRadius.xLarge,
            hasShadow: false
        )
    }
}
