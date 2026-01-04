import SwiftUI

/// Full overview of all property tiers and their benefits
/// Shows users what they're working toward with brutalist styling
struct TierBenefitsView: View {
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Header
                headerCard
                
                // All 5 tiers
                ForEach(1...5, id: \.self) { tier in
                    tierCard(tier: tier)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Property Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
    
    // MARK: - Header
    
    private var headerCard: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "building.2")
                .font(FontStyles.iconExtraLarge)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.inkMedium,
                    cornerRadius: 16,
                    shadowOffset: 4,
                    borderWidth: 2.5
                )
            
            Text("Property Progression")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Upgrade your property to unlock new benefits")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(KingdomTheme.Spacing.large)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    // MARK: - Tier Card
    
    private func tierCard(tier: Int) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Tier header with icon
            HStack(spacing: KingdomTheme.Spacing.medium) {
                tierIcon(for: tier)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .brutalistBadge(
                        backgroundColor: tierColor(for: tier),
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tier \(tier)")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(tierColor(for: tier))
                    
                    Text(tierName(for: tier))
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(tierDescription(for: tier))
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Benefits section
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                ForEach(tierBenefits(for: tier), id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(tierColor(for: tier))
                            .frame(width: 20)
                        
                        Text(benefit)
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Cost and requirements
            HStack {
                if tier > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upgrade Cost")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                            Text("\(upgradeCost(from: tier - 1))")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Work Required")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Text("\(baseActionsRequired(for: tier - 1)) actions")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Purchase Cost")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                            Text("500+ (varies by location)")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Tier Data
    
    private func tierName(for tier: Int) -> String {
        switch tier {
        case 1: return "Land"
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"
        default: return "Property"
        }
    }
    
    private func tierDescription(for tier: Int) -> String {
        // Fetch from backend tier manager (single source of truth)
        return tierManager.propertyTierDescription(tier)
    }
    
    private func tierBenefits(for tier: Int) -> [String] {
        // Fetch from backend tier manager (single source of truth)
        return tierManager.propertyTierBenefits(tier)
    }
    
    private func upgradeCost(from tier: Int) -> Int {
        let baseCost = 500
        let nextTier = tier + 1
        return baseCost * Int(pow(2.0, Double(nextTier - 2)))
    }
    
    private func baseActionsRequired(for tier: Int) -> Int {
        return 5 + (tier * 2)
    }
    
    private func tierColor(for tier: Int) -> Color {
        // Consistent green for all property tiers
        return KingdomTheme.Colors.buttonSuccess
    }
    
    @ViewBuilder
    private func tierIcon(for tier: Int) -> some View {
        switch tier {
        case 1:
            Image(systemName: "rectangle.dashed")
        case 2:
            Image(systemName: "house.fill")
        case 3:
            Image(systemName: "hammer.fill")
        case 4:
            Image(systemName: "building.columns.fill")
        case 5:
            Image(systemName: "crown.fill")
        default:
            Image(systemName: "questionmark")
        }
    }
}
