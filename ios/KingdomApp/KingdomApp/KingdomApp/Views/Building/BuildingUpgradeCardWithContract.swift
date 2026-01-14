import SwiftUI

struct BuildingUpgradeCardWithContract: View {
    let icon: String
    let name: String
    let buildingType: String  // For fetching dynamic tier info
    let currentLevel: Int
    let maxLevel: Int
    let benefit: String
    let hasActiveContract: Bool
    let hasAnyActiveContract: Bool  // Kingdom has ANY active contract
    let kingdom: Kingdom
    let upgradeCost: BuildingUpgradeCost?  // From backend
    let iconColor: Color  // Color for the icon badge
    let onCreateContract: () -> Void
    
    var isMaxLevel: Bool {
        currentLevel >= maxLevel
    }
    
    private var actionsRequired: Int {
        return upgradeCost?.actionsRequired ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header with icon, name, and level
            HStack(spacing: 14) {
                // Building icon with brutalist badge
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .brutalistBadge(
                        backgroundColor: iconColor,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(name)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // View all levels link - FULLY DYNAMIC from backend
                        NavigationLink(destination: BuildingLevelsView(
                            buildingName: name,
                            icon: icon,
                            currentLevel: currentLevel,
                            maxLevel: maxLevel,
                            benefitForLevel: { level in getBenefitForLevel(level) },
                            actionsForNextLevel: actionsRequired,
                            detailedBenefits: getDetailedBenefitsForBuilding(),
                            accentColor: iconColor
                        )) {
                            HStack(spacing: 4) {
                                Text("All Levels")
                                    .font(FontStyles.labelSmall)
                                Image(systemName: "chevron.right")
                                    .font(FontStyles.iconMini)
                            }
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        }
                    }
                    
                    // Level indicator dots
                    HStack(spacing: 6) {
                        ForEach(1...maxLevel, id: \.self) { level in
                            Circle()
                                .fill(level <= currentLevel ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkDark.opacity(0.15))
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: level <= currentLevel ? 1.5 : 0.5)
                                )
                        }
                        
                        Text("Level \(currentLevel)/\(maxLevel)")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .padding(.leading, 4)
                        
                        Spacer()
                        
                        // Estimated actions for next level (always show if not max)
                        if !isMaxLevel && actionsRequired > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "hammer.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                                Text("\(actionsRequired)")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.parchment,
                                cornerRadius: 6,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                        }
                    }
                }
            }
            
            if !isMaxLevel {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                // Next level benefit
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(currentLevel + 1) Benefit")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text(benefit)
                            .font(FontStyles.bodySmallBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
                
                if hasActiveContract {
                    // Active contract indicator
                    HStack(spacing: 10) {
                        Image(systemName: "hourglass")
                            .font(FontStyles.iconMedium)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contract in Progress")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            Text("Citizens are working on this upgrade")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(KingdomTheme.Colors.buttonSuccess.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(KingdomTheme.Colors.buttonSuccess, lineWidth: 2)
                    )
                } else if hasAnyActiveContract {
                    // Blocked by another contract
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Complete current contract first")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                } else {
                    // Action button
                    VStack(spacing: 12) {
                        // Stats row - Actions and Treasury
                        HStack(spacing: 12) {
                            // Actions required
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hammer.fill")
                                        .font(FontStyles.iconMini)
                                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                                    Text("\(actionsRequired)")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                }
                                Text("ACTIONS")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
                            
                            // Treasury balance
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .font(FontStyles.iconMini)
                                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                                    Text("\(kingdom.treasuryGold)g")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                }
                                Text("TREASURY")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
                        }
                        
                        // Post Contract button
                        Button(action: onCreateContract) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .font(FontStyles.iconSmall)
                                Text("Post Contract")
                                    .font(FontStyles.bodyMediumBold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.buttonPrimary,
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                // Max level reached
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maximum Level Reached")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("This building is fully upgraded")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    Spacer()
                }
                .padding()
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium.opacity(0.12), cornerRadius: 10)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // FULLY DYNAMIC - Get benefit for a specific level from backend
    private func getBenefitForLevel(_ level: Int) -> String {
        guard let meta = kingdom.getBuildingMetadata(buildingType),
              let tierInfo = meta.allTiers.first(where: { $0.tier == level }) else {
            return "Level \(level)"
        }
        return tierInfo.benefit
    }
    
    // FULLY DYNAMIC - Get detailed benefits for all levels from backend
    private func getDetailedBenefitsForBuilding() -> ((Int) -> [String])? {
        guard let meta = kingdom.getBuildingMetadata(buildingType) else {
            return nil
        }
        
        return { level in
            guard let tierInfo = meta.allTiers.first(where: { $0.tier == level }) else {
                return ["Level \(level)"]
            }
            
            var benefits = [tierInfo.benefit]
            if !tierInfo.tierDescription.isEmpty && tierInfo.tierDescription != tierInfo.benefit {
                benefits.append(tierInfo.tierDescription)
            }
            return benefits
        }
    }
}
