import SwiftUI

// MARK: - Locked Action Card

struct LockedActionCard: View {
    let title: String
    let icon: String
    let description: String
    let requirementText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                // Icon in brutalist badge (grayed out)
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.disabled,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.disabled)
                        
                        Image(systemName: "lock.fill")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(KingdomTheme.Colors.disabled)
                    }
                    
                    Text(description)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .opacity(0.5)
                }
                
                Spacer()
            }
            
            // Requirement text
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                Text(requirementText)
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .padding(KingdomTheme.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KingdomTheme.Colors.buttonDanger.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KingdomTheme.Colors.buttonDanger, lineWidth: 2)
            )
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        LockedActionCard(
            title: "Sabotage Contract",
            icon: "flame.fill",
            description: "Delay enemy construction projects",
            requirementText: "Requires Intelligence Tier 4 (current: Tier 2)"
        )
        
        LockedActionCard(
            title: "Vault Heist",
            icon: "banknote.fill",
            description: "Steal from enemy kingdom vault",
            requirementText: "Requires Intelligence Tier 5 (current: Tier 3)"
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}

