import SwiftUI

/// View to see all property tiers at once with brutalist styling
struct PropertyTiersView: View {
    @ObservedObject var player: Player
    let property: Property?  // Optional - can view tiers without owning property
    @Environment(\.dismiss) var dismiss
    @State private var selectedTier: Int = 1
    private let tierManager = TierManager.shared
    
    private var currentTier: Int {
        property?.tier ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Tier selector with picker
                TierSelectorCard(
                    currentTier: currentTier,
                    selectedTier: $selectedTier,
                    accentColor: KingdomTheme.Colors.buttonSuccess
                ) { tier in
                    tierContent(tier: tier)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("All Property Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedTier = max(1, currentTier) // Start at tier 1 if no property
        }
    }
    
    private func tierContent(tier: Int) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Tier header with icon
            HStack(spacing: KingdomTheme.Spacing.medium) {
                tierIcon(tier)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: tierColor(tier),
                        cornerRadius: 10,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tierName(tier))
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Tier \(tier)")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(tierColor(tier))
                }
                
                Spacer()
                
                // Status badge - MapHUD style
                if tier <= currentTier {
                    Text("Unlocked")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black)
                                    .offset(x: 1, y: 1)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(KingdomTheme.Colors.inkMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black, lineWidth: 1.5)
                                    )
                            }
                        )
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Benefits
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                ForEach(tierBenefits(tier), id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
                            .frame(width: 20)
                        
                        Text(benefit)
                            .font(FontStyles.bodySmall)
                            .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Cost section
            if let cost = tierManager.propertyTierCost(tier), let actions = tierManager.propertyTierActions(tier) {
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    sectionHeader(icon: "dollarsign.circle.fill", title: "Base Cost")
                    
                    HStack(spacing: 12) {
                        // Gold cost
                        HStack(spacing: 6) {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                            Text("\(cost)g")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Text("•")
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        // Actions required
                        HStack(spacing: 6) {
                            Image(systemName: "hammer.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            Text("\(actions) actions")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                    }
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
            }
            
            // Status indicator - MapHUD style
            if tier <= currentTier {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Unlocked")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.inkMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else if currentTier == 0 && tier == 1 {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Purchase land to unlock")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else if tier > currentTier + 1 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text(currentTier == 0 ? "Purchase land first" : "Complete Tier \(currentTier + 1) first")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Available to Upgrade")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            }
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    @ViewBuilder
    private func tierIcon(_ tier: Int) -> some View {
        switch tier {
        case 1: Image(systemName: "rectangle.dashed")
        case 2: Image(systemName: "house.fill")
        case 3: Image(systemName: "hammer.fill")
        case 4: Image(systemName: "building.columns.fill")
        case 5: Image(systemName: "crown.fill")
        default: Image(systemName: "questionmark")
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        // Consistent green for all property tiers
        return KingdomTheme.Colors.buttonSuccess
    }
    
    private func tierName(_ tier: Int) -> String {
        // Fetch from backend tier manager (single source of truth)
        return tierManager.propertyTierName(tier)
    }
    
    private func tierBenefits(_ tier: Int) -> [String] {
        // Fetch from backend tier manager (single source of truth)
        return tierManager.propertyTierBenefits(tier)
    }
}
