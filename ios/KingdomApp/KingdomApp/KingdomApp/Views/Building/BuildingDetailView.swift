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
                        
                        // Cost - FULLY DYNAMIC from backend
                        costSection(tier: tier)
                        
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
    
    // FULLY DYNAMIC - Get from kingdom metadata
    private var buildingDisplayName: String {
        if let meta = kingdom.getBuildingMetadata(buildingType) {
            return meta.displayName
        }
        return buildingType.capitalized
    }
    
    private var buildingColor: Color {
        if let meta = kingdom.getBuildingMetadata(buildingType),
           let color = Color(hex: meta.colorHex) {
            return color
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private func getBackendUpgradeCost(tier: Int) -> Int {
        // Backend is source of truth - NO frontend calculations
        if tier == currentLevel + 1 {
            if let upgradeCost = kingdom.upgradeCost(buildingType) {
                return upgradeCost.constructionCost
            }
        }
        // For future tiers, just show 0 or hide them
        return 0
    }
    
    private func getTierBenefits(tier: Int) -> [String] {
        // FULLY DYNAMIC - Get benefits from backend tier info
        guard let meta = kingdom.getBuildingMetadata(buildingType) else {
            return ["Level \(tier)"]
        }
        
        // Find the tier info from allTiers
        if let tierInfo = meta.allTiers.first(where: { $0.tier == tier }) {
            var benefits = [tierInfo.benefit]
            // Add description as secondary benefit if it's different
            if !tierInfo.tierDescription.isEmpty && tierInfo.tierDescription != tierInfo.benefit {
                benefits.append(tierInfo.tierDescription)
            }
            return benefits
        }
        
        // Fallback if tier not found
        return ["Level \(tier)"]
    }
    
    // MARK: - Cost Section (FULLY DYNAMIC)
    
    @ViewBuilder
    private func costSection(tier: Int) -> some View {
        let perActionCosts = getTierPerActionCosts(tier: tier)
        let goldCost = getBackendUpgradeCost(tier: tier)
        let actionsRequired = getActionsRequired(tier: tier)
        
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "dollarsign.circle.fill", title: "Upgrade Cost")
            
            if actionsRequired > 0 || goldCost > 0 || !perActionCosts.isEmpty {
                // Cost table - horizontal scroll for many columns
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Table header
                        HStack(spacing: 16) {
                            Text("Upgrade")
                                .frame(width: 80, alignment: .leading)
                            
                            if actionsRequired > 0 {
                                Text("Actions")
                                    .frame(width: 60, alignment: .center)
                            }
                            
                            Text("Gold")
                                .frame(width: 60, alignment: .center)
                            
                            // Dynamic resource columns
                            ForEach(perActionCosts, id: \.resource) { cost in
                                Text(resourceDisplayName(cost.resource))
                                    .frame(width: 60, alignment: .center)
                            }
                        }
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        
                        Divider()
                            .overlay(Color.black.opacity(0.1))
                        
                        // Table row with values
                        HStack(spacing: 16) {
                            Text("Level \(tier)")
                                .frame(width: 80, alignment: .leading)
                            
                            if actionsRequired > 0 {
                                Text("\(actionsRequired)")
                                    .frame(width: 60, alignment: .center)
                            }
                            
                            Text("\(goldCost)g")
                                .frame(width: 60, alignment: .center)
                            
                            // Dynamic resource values (per action)
                            ForEach(perActionCosts, id: \.resource) { cost in
                                Text("\(cost.amount)/act")
                                    .frame(width: 60, alignment: .center)
                            }
                        }
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2)
                )
                .padding(.top, 4)
                
                // Total summary if there are per-action costs
                if !perActionCosts.isEmpty && actionsRequired > 0 {
                    Text("Total: \(buildTotalSummary(actions: actionsRequired, gold: goldCost, perActionCosts: perActionCosts))")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            } else {
                Text("Cost information not available")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
    }
    
    private func getTierPerActionCosts(tier: Int) -> [BuildingPerActionCost] {
        guard let meta = kingdom.getBuildingMetadata(buildingType),
              let tierInfo = meta.allTiers.first(where: { $0.tier == tier }) else {
            return []
        }
        return tierInfo.perActionCosts
    }
    
    private func getActionsRequired(tier: Int) -> Int {
        // For the next tier to upgrade, get from upgrade cost
        if tier == currentLevel + 1 {
            if let upgradeCost = kingdom.upgradeCost(buildingType) {
                return upgradeCost.actionsRequired
            }
        }
        return 0
    }
    
    private func resourceDisplayName(_ resource: String) -> String {
        // Get display name from TierManager, fallback to capitalized resource
        return TierManager.shared.resourceInfo(resource)?.displayName ?? resource.capitalized
    }
    
    private func buildTotalSummary(actions: Int, gold: Int, perActionCosts: [BuildingPerActionCost]) -> String {
        var parts: [String] = []
        
        parts.append("\(gold)g")
        
        for cost in perActionCosts {
            let total = cost.amount * actions
            let name = resourceDisplayName(cost.resource).lowercased()
            parts.append("\(total) \(name)")
        }
        
        return parts.joined(separator: ", ")
    }
}
