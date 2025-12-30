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
        VStack(alignment: .leading, spacing: 14) {
            // View all levels button
            NavigationLink(destination: BuildingLevelsView(
                buildingName: name,
                icon: icon,
                currentLevel: currentLevel,
                maxLevel: maxLevel,
                benefitForLevel: { level in benefit },
                costForLevel: { level in constructionCost },
                detailedBenefits: getDetailedBenefitsForBuilding(name: name)
            )) {
                HStack {
                    Image(systemName: "list.number")
                        .font(.caption)
                    Text("View All Levels")
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(KingdomTheme.Colors.buttonPrimary.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Header with icon, name, and level
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [KingdomTheme.Colors.gold.opacity(0.3), KingdomTheme.Colors.gold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        // Level indicator
                        HStack(spacing: 4) {
                            ForEach(1...maxLevel, id: \.self) { level in
                                Circle()
                                    .fill(level <= currentLevel ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.2))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        Text("Level \(currentLevel)/\(maxLevel)")
                            .font(.caption2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
            }
            
            if !isMaxLevel {
                Divider()
                
                // Benefit
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.gold.opacity(0.7))
                    Text(benefit)
                        .font(.subheadline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                if hasActiveContract {
                    // Active contract indicator
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        Text("Contract in progress")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
                    .cornerRadius(8)
                } else if hasAnyActiveContract {
                    // Blocked by another contract
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("Complete current contract first")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    // Cost and action button
                    VStack(spacing: 10) {
                        HStack(spacing: 16) {
                            // Cost
                            VStack(alignment: .leading, spacing: 3) {
                                Text("COST")
                                    .font(.caption2.bold())
                                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.caption)
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                    Text("\(constructionCost)g")
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundColor(canAfford ? KingdomTheme.Colors.inkDark : .red)
                                }
                            }
                            
                            // Actions
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ACTIONS")
                                    .font(.caption2.bold())
                                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.walk")
                                        .font(.caption)
                                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                                    Text("\(actionsRequired)")
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                }
                            }
                            
                            Spacer()
                            
                            // Treasury balance
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("TREASURY")
                                    .font(.caption2.bold())
                                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                                
                                Text("\(kingdom.treasuryGold)g")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(canAfford ? KingdomTheme.Colors.inkMedium : .red)
                            }
                        }
                        
                        // Post Contract button
                        Button(action: onCreateContract) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                Text("Post Contract")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(canAfford ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled)
                            .cornerRadius(10)
                        }
                        .disabled(!canAfford)
                    }
                }
            } else {
                // Max level reached
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Text("Maximum Level Reached")
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(KingdomTheme.Colors.gold.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.2), lineWidth: 1)
        )
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


