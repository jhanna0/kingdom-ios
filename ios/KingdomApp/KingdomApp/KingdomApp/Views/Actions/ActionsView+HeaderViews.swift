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
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: isHome ? "crown.fill" : "shield.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: isHome ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kingdom.name)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(isHome ? "Your Kingdom" : "Enemy Territory")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(isHome ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonDanger)
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
