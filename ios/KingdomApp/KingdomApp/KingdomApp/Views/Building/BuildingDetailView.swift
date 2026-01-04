import SwiftUI

struct BuildingDetailView: View {
    let buildingType: String
    let currentLevel: Int
    let kingdom: Kingdom
    let player: Player
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    
    @State private var selectedTier: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Unified tier selector
                TierSelectorCard(
                    currentTier: currentLevel,
                    selectedTier: $selectedTier,
                    accentColor: buildingColor
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
                                        .foregroundColor(tier <= currentLevel ? buildingColor : KingdomTheme.Colors.inkDark.opacity(0.3))
                                        .frame(width: 20)
                                    
                                    Text(benefit)
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(tier <= currentLevel ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(buildingColor.opacity(0.3))
                            .frame(height: 2)
                        
                        // Cost
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "dollarsign.circle.fill", title: "Upgrade Cost")
                            
                            ResourceRow(
                                icon: "g.circle.fill",
                                iconColor: KingdomTheme.Colors.goldLight,
                                label: "Gold",
                                required: getUpgradeCost(tier: tier),
                                available: kingdom.treasuryGold
                            )
                        }
                        
                        // Status indicator - MapHUD style
                        if tier <= currentLevel {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Built")
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
                        } else if tier == currentLevel + 1 {
                            if kingdom.rulerId == player.playerId {
                                HStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Available to upgrade")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(KingdomTheme.Colors.inkDark)
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
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Only the ruler can upgrade")
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
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Build Level \(currentLevel + 1) first")
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
                .foregroundColor(buildingColor.opacity(0.5))
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Computed Properties
    
    private var buildingDisplayName: String {
        return BuildingConfig.get(buildingType).displayName
    }
    
    private var buildingColor: Color {
        return BuildingConfig.get(buildingType).color
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
        // Use TierManager building info with dynamic benefit calculation
        // Benefits are calculated based on building type and tier
        switch buildingType {
        case "wall":
            let defenders = tier * 2
            var benefits = ["+\(defenders) defenders in battles", "Increases coup resistance"]
            if tier >= 3 { benefits.append("Harder to invade") }
            if tier >= 5 { benefits.append("Maximum fortification") }
            return benefits
        case "vault":
            let protection = tier * 20
            var benefits = ["\(protection)% of treasury protected", "Reduces gold loss from coups"]
            if tier >= 3 { benefits.append("Better heist protection") }
            if tier >= 5 { benefits.append("Maximum security") }
            return benefits
        case "mine":
            let hourlyIncome = tier * 5
            var benefits = ["+\(hourlyIncome)g per hour", "Passive gold generation"]
            if tier >= 3 { benefits.append("Significant income boost") }
            if tier >= 5 { benefits.append("+25g/hr total passive income") }
            return benefits
        case "market":
            let hourlyIncome = tier * 3
            var benefits = ["+\(hourlyIncome)g per hour", "Trading hub income"]
            if tier >= 3 { benefits.append("Attracts more traders") }
            if tier >= 5 { benefits.append("+15g/hr total trading income") }
            return benefits
        case "farm":
            let reduction = [5, 10, 20, 25, 33][min(tier - 1, 4)]
            return ["Contracts complete \(reduction)% faster", "Increases kingdom efficiency"]
        case "education":
            let reduction = tier * 5
            return ["Citizens train skills \(reduction)% faster", "Improves skill training"]
        default:
            return [tierManager.buildingTierDescription(buildingType, tier: tier)]
        }
    }
}
