import SwiftUI

// Legend showing kingdom info - Medieval scroll style
struct LegendView: View {
    let kingdomCount: Int
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            HStack {
                Text("⚔️ \(kingdomCount) Kingdoms")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            
            Text("Ancient territories")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(KingdomTheme.Spacing.medium)
        .parchmentCard(cornerRadius: KingdomTheme.CornerRadius.medium)
    }
}
