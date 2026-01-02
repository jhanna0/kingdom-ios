import SwiftUI

struct BuildingDetailView: View {
    let buildingType: String
    let currentLevel: Int
    let kingdom: Kingdom
    let player: Player
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTier: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Unified tier selector
                TierSelectorCard(
                    currentTier: currentLevel,
                    selectedTier: $selectedTier
                ) { tier in
                    VStack(alignment: .leading, spacing: 16) {
                        // Tier name
                        Text("Level \(tier)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Benefits
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "star.fill", title: "Benefits")
                            
                            ForEach(getTierBenefits(tier: tier), id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: tier <= currentLevel ? "checkmark.circle.fill" : "lock.circle.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(tier <= currentLevel ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                                        .frame(width: 20)
                                    
                                    Text(benefit)
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(tier <= currentLevel ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 2)
                        
                        // Cost
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "dollarsign.circle.fill", title: "Upgrade Cost")
                            
                            ResourceRow(
                                icon: "circle.fill",
                                iconColor: KingdomTheme.Colors.gold,
                                label: "Gold",
                                required: getUpgradeCost(tier: tier),
                                available: kingdom.treasuryGold
                            )
                        }
                        
                        // Status indicator
                        if tier <= currentLevel {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(FontStyles.iconSmall)
                                Text("Built")
                                    .font(FontStyles.bodyMediumBold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                        } else if tier == currentLevel + 1 {
                            if kingdom.rulerId == player.playerId {
                                HStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(FontStyles.iconSmall)
                                    Text("Available to upgrade")
                                        .font(FontStyles.bodySmall)
                                }
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(FontStyles.iconSmall)
                                    Text("Only the ruler can upgrade")
                                        .font(FontStyles.bodySmall)
                                }
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(FontStyles.iconSmall)
                                Text("Build Level \(currentLevel + 1) first")
                                    .font(FontStyles.bodySmall)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
                        }
                    }
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle(buildingDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedTier = min(currentLevel + 1, 5)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.gold)
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Computed Properties
    
    private var buildingDisplayName: String {
        switch buildingType {
        case "wall": return "Walls"
        case "vault": return "Vault"
        case "mine": return "Mine"
        case "market": return "Market"
        default: return buildingType.capitalized
        }
    }
    
    private func getUpgradeCost(tier: Int) -> Int {
        // Base costs scale exponentially
        let baseCost: Int
        switch buildingType {
        case "wall", "vault":
            baseCost = 500 // Defense buildings more expensive
        case "mine", "market":
            baseCost = 300 // Economy buildings cheaper
        default:
            baseCost = 400
        }
        
        // Exponential scaling: tier^2 * base
        return tier * tier * baseCost
    }
    
    private func getTierBenefits(tier: Int) -> [String] {
        switch buildingType {
        case "wall":
            return getWallBenefits(tier: tier)
        case "vault":
            return getVaultBenefits(tier: tier)
        case "mine":
            return getMineBenefits(tier: tier)
        case "market":
            return getMarketBenefits(tier: tier)
        default:
            return []
        }
    }
    
    private func getWallBenefits(tier: Int) -> [String] {
        let defenders = tier * 2
        var benefits = [
            "+\(defenders) defenders in battles",
            "Increases coup resistance"
        ]
        
        if tier >= 3 {
            benefits.append("Harder to invade")
        }
        if tier >= 5 {
            benefits.append("Maximum fortification")
        }
        
        return benefits
    }
    
    private func getVaultBenefits(tier: Int) -> [String] {
        let protection = tier * 20
        var benefits = [
            "\(protection)% of treasury protected",
            "Reduces gold loss from coups"
        ]
        
        if tier >= 3 {
            benefits.append("Better heist protection")
        }
        if tier >= 5 {
            benefits.append("Maximum security")
        }
        
        return benefits
    }
    
    private func getMineBenefits(tier: Int) -> [String] {
        let hourlyIncome = tier * 5
        var benefits = [
            "+\(hourlyIncome)g per hour",
            "Passive gold generation"
        ]
        
        if tier >= 3 {
            benefits.append("Significant income boost")
        }
        if tier >= 5 {
            benefits.append("+25g/hr total passive income")
        }
        
        return benefits
    }
    
    private func getMarketBenefits(tier: Int) -> [String] {
        let hourlyIncome = tier * 3
        var benefits = [
            "+\(hourlyIncome)g per hour",
            "Trading hub income"
        ]
        
        if tier >= 3 {
            benefits.append("Attracts more traders")
        }
        if tier >= 5 {
            benefits.append("+15g/hr total trading income")
        }
        
        return benefits
    }
}

