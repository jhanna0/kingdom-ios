import SwiftUI

// MARK: - Kingdom Overview

extension KingdomInfoSheetView {
    
    // MARK: - Kingdom Overview Card
    
    var kingdomOverviewCard: some View {
        VStack(spacing: 0) {
            // Present
            statRow(icon: "person.3.fill", iconColor: KingdomTheme.Colors.royalBlue, label: "Present", value: "\(kingdom.checkedInPlayers)")
            Divider()
            
            // Citizens
            statRow(icon: "person.2.circle.fill", iconColor: KingdomTheme.Colors.imperialGold, label: "Citizens", value: "\(kingdom.activeCitizens)")
            
            if !kingdom.isUnclaimed {
                Divider()
                statRow(icon: "percent", iconColor: KingdomTheme.Colors.buttonWarning, label: "Tax Rate", value: "\(kingdom.taxRate)%")
                Divider()
                statRow(icon: "figure.walk.arrival", iconColor: KingdomTheme.Colors.buttonPrimary, label: "Entry Fee", value: "\(kingdom.travelFee)g")
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    // MARK: - Stat Row Helper
    
    func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .brutalistBadge(backgroundColor: iconColor, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            
            Text(label)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Spacer()
            
            Text(value)
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.vertical, 8)
    }
}
