import SwiftUI

/// Card displaying player statistics (check-ins, conquests, etc.)
struct StatisticsCard: View {
    let kingdomsRuled: Int
    let coupsWon: Int
    let totalCheckins: Int
    let contractsCompleted: Int
    let totalConquests: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Statistics")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            VStack(spacing: 8) {
                statisticRow(
                    icon: "flag.fill",
                    title: "Kingdoms Ruled",
                    value: "\(kingdomsRuled)",
                    color: KingdomTheme.Colors.royalPurple
                )
                
                statisticRow(
                    icon: "crown.fill",
                    title: "Coups Won",
                    value: "\(coupsWon)",
                    color: KingdomTheme.Colors.goldLight
                )
                
                statisticRow(
                    icon: "mappin.circle.fill",
                    title: "Total Check-ins",
                    value: "\(totalCheckins)",
                    color: KingdomTheme.Colors.royalBlue
                )
                
                statisticRow(
                    icon: "hammer.fill",
                    title: "Contracts Completed",
                    value: "\(contractsCompleted)",
                    color: KingdomTheme.Colors.royalEmerald
                )
                
                statisticRow(
                    icon: "star.fill",
                    title: "Total Conquests",
                    value: "\(totalConquests)",
                    color: KingdomTheme.Colors.buttonDanger
                )
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func statisticRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .brutalistBadge(backgroundColor: color, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            
            Text(title)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            Text(value)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding()
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
    }
}
