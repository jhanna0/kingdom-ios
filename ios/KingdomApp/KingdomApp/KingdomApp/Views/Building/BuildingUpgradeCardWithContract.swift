import SwiftUI

struct BuildingUpgradeCardWithContract: View {
    let icon: String
    let name: String
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
    
    private var constructionCost: Int {
        return upgradeCost?.constructionCost ?? 0
    }
    
    private var canAfford: Bool {
        return upgradeCost?.canAfford ?? false
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
                        
                        // View all levels link
                        NavigationLink(destination: BuildingLevelsView(
                            buildingName: name,
                            icon: icon,
                            currentLevel: currentLevel,
                            maxLevel: maxLevel,
                            benefitForLevel: { level in benefit },
                            costForLevel: { level in constructionCost },
                            detailedBenefits: getDetailedBenefitsForBuilding(name: name)
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
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contract in Progress")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text("Citizens are working on this upgrade")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        Spacer()
                    }
                    .padding()
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning.opacity(0.12), cornerRadius: 10)
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
                    // Cost and action button
                    VStack(spacing: 12) {
                        // Stats row
                        HStack(spacing: 0) {
                            // Cost
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .font(FontStyles.iconMini)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    Text("\(constructionCost)g")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(canAfford ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.buttonDanger)
                                }
                                Text("COST")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
                            
                            Spacer().frame(width: 10)
                            
                            // Actions
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.walk")
                                        .font(FontStyles.iconMini)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                            
                            Spacer().frame(width: 10)
                            
                            // Treasury balance
                            VStack(spacing: 4) {
                                Text("\(kingdom.treasuryGold)g")
                                    .font(FontStyles.bodyLargeBold)
                                    .foregroundColor(canAfford ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonDanger)
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
                            backgroundColor: canAfford ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled,
                            cornerRadius: 12,
                            shadowOffset: canAfford ? 3 : 0,
                            borderWidth: 2
                        )
                        .disabled(!canAfford)
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
    
    private func getDetailedBenefitsForBuilding(name: String) -> ((Int) -> [String])? {
        switch name {
        case "Mine":
            return { level in
                switch level {
                case 1: return ["Unlock Stone mining", "+5 Stone/day"]
                case 2: return ["+10 Stone/day", "+5 Iron/day"]
                case 3: return ["+15 Stone/day", "+10 Iron/day", "+5 Steel/day"]
                case 4: return ["+20 Stone/day", "+15 Iron/day", "+10 Steel/day"]
                case 5: return ["All materials at 2x quantity", "Maximum production"]
                default: return []
                }
            }
        case "Market":
            return { level in
                switch level {
                case 1: return ["+15g/day passive income", "Basic trade routes"]
                case 2: return ["+35g/day passive income", "Improved merchants"]
                case 3: return ["+65g/day passive income", "Regional trade hub"]
                case 4: return ["+100g/day passive income", "Major trade center"]
                case 5: return ["+150g/day passive income", "Economic powerhouse"]
                default: return []
                }
            }
        case "Farm":
            return { level in
                let reduction: Int = {
                    switch level {
                    case 1: return 5
                    case 2: return 10
                    case 3: return 20
                    case 4: return 25
                    case 5: return 33
                    default: return 0
                    }
                }()
                return [
                    "Citizens complete contracts \(reduction)% faster",
                    "Speeds up all kingdom projects",
                    "Attracts more workers"
                ]
            }
        case "Education Hall":
            return { level in
                let reduction = level * 5
                return [
                    "-\(reduction)% training actions required",
                    "Citizens train skills faster",
                    "Knowledge hub for kingdom"
                ]
            }
        case "Walls":
            return { level in
                let defenders = level * 2
                return [
                    "+\(defenders) defenders during coups",
                    "Harder to overthrow kingdom",
                    "Protects citizens & treasury"
                ]
            }
        case "Vault":
            return { level in
                let protection = level * 20
                return [
                    "\(protection)% of treasury protected from theft",
                    "Reduces gold loss in coups",
                    "Deters vault heists"
                ]
            }
        default:
            return nil
        }
    }
}
