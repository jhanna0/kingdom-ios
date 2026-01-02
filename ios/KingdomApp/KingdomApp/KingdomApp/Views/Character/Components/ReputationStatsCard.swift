import SwiftUI

/// Reusable reputation display card - brutalist style
struct ReputationStatsCard: View {
    let reputation: Int
    let honor: Int?  // Optional - not all contexts have honor
    let showAbilities: Bool  // Whether to show the ability unlocks
    
    init(reputation: Int, honor: Int? = nil, showAbilities: Bool = true) {
        self.reputation = reputation
        self.honor = honor
        self.showAbilities = showAbilities
    }
    
    private var reputationTier: ReputationTier {
        ReputationTier.from(reputation: reputation)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header with icon and title
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Tier icon with brutalist badge
                Image(systemName: reputationTier.icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .brutalistBadge(
                        backgroundColor: reputationTier.color,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reputationTier.displayName)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        Text("\(reputation) reputation")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if let honor = honor {
                            Text("•")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Text("\(honor) honor")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                    }
                }
                
                Spacer()
            }
            
            if showAbilities {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                // Abilities unlocked
                VStack(alignment: .leading, spacing: 8) {
                    Text("Abilities Unlocked")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Single column for better readability
                    VStack(spacing: 8) {
                        abilityRow(
                            icon: "checkmark.circle.fill",
                            text: "Accept contracts",
                            unlocked: true
                        )
                        
                        abilityRow(
                            icon: "house.fill",
                            text: "Buy property",
                            unlocked: reputation >= 50,
                            requirement: 50
                        )
                        
                        abilityRow(
                            icon: "hand.raised.fill",
                            text: "Vote on coups",
                            unlocked: reputation >= 150,
                            requirement: 150
                        )
                        
                        abilityRow(
                            icon: "flag.fill",
                            text: "Propose coups",
                            unlocked: reputation >= 300,
                            requirement: 300
                        )
                        
                        abilityRow(
                            icon: "star.fill",
                            text: "Vote counts 2x",
                            unlocked: reputation >= 500,
                            requirement: 500
                        )
                        
                        abilityRow(
                            icon: "crown.fill",
                            text: "Vote counts 3x",
                            unlocked: reputation >= 1000,
                            requirement: 1000
                        )
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func abilityRow(icon: String, text: String, unlocked: Bool, requirement: Int? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconMini)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .brutalistBadge(
                    backgroundColor: unlocked ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight,
                    cornerRadius: 6,
                    shadowOffset: 1,
                    borderWidth: 1.5
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(text)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if !unlocked, let req = requirement {
                    Text("\(req) rep")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(unlocked ? KingdomTheme.Colors.inkMedium.opacity(0.1) : KingdomTheme.Colors.inkDark.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(unlocked ? KingdomTheme.Colors.inkMedium.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ReputationStatsCard(reputation: 250, honor: 85, showAbilities: true)
        ReputationStatsCard(reputation: 750, showAbilities: false)
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
