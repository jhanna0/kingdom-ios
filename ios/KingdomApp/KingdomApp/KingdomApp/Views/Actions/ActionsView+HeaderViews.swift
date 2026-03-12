import SwiftUI

// MARK: - Header Views

extension ActionsView {
    
    // MARK: - Header Section
    
    var headerSection: some View {
        kingdomContextCard
            .padding(.horizontal)
            .padding(.top, KingdomTheme.Spacing.small)
    }
    
    // MARK: - Kingdom Context Card
    
    @ViewBuilder
    var kingdomContextCard: some View {
        if let kingdom = currentKingdom {
            let isHome = viewModel.isHomeKingdom(kingdom)
            
            // Backend sends complete display info - just use it!
            let territoryInfo: (text: String, icon: String, color: Color) = {
                if let status = actionStatus?.territoryStatus {
                    // Use backend-provided values
                    let color = KingdomTheme.Colors.color(fromThemeName: status.color)
                    return (status.text, status.icon, color)
                } else {
                    // Fallback for old API versions
                    let text = "Unknown Territory"
                    let icon = "shield.fill"
                    let color = KingdomTheme.Colors.inkMedium
                    return (text, icon, color)
                }
            }()
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: territoryInfo.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: territoryInfo.color,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kingdom.name)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(territoryInfo.text)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(territoryInfo.color)
                }
                
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        } else {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.disabled,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Kingdom")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Enter a kingdom to perform actions")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        }
    }
}
