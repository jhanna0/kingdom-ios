import SwiftUI

// MARK: - Alliance Sections

extension KingdomInfoSheetView {
    
    // MARK: - Active Alliances Card (for player's hometown)
    
    @ViewBuilder
    var activeAlliancesSection: some View {
        if !kingdom.activeAlliances.isEmpty {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    
                    Text("Active Alliances")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    Text("\(kingdom.activeAlliances.count)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 6)
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                ForEach(kingdom.activeAlliances) { alliance in
                    allianceRow(alliance: alliance)
                }
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Alliance Row
    
    private func allianceRow(alliance: ActiveAlliance) -> some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "checkmark.shield.fill")
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alliance.alliedKingdomName)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let rulerName = alliance.alliedRulerName {
                    Text("Ruled by \(rulerName)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Spacer()
            
            Text("\(alliance.daysRemaining)d")
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
        }
        .padding(KingdomTheme.Spacing.small)
        .background(KingdomTheme.Colors.buttonSuccess.opacity(0.05))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(KingdomTheme.Colors.buttonSuccess.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - Alliance Status Banner (for allied kingdoms)
    
    @ViewBuilder
    var allianceStatusBanner: some View {
        if kingdom.activeAlliances.isEmpty, kingdom.isAllied, let allianceInfo = kingdom.allianceInfo {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allied Kingdom")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("\(allianceInfo.daysRemaining) days remaining")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.title)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.buttonSuccess.opacity(0.1), cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KingdomTheme.Colors.buttonSuccess, lineWidth: 2)
            )
            .padding(.horizontal)
        }
    }
}
