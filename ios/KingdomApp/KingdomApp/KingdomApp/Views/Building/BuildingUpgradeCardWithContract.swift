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
    
    private var contractCost: Int {
        return upgradeCost?.suggestedReward ?? 0
    }
    
    private var canAfford: Bool {
        return upgradeCost?.canAfford ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.goldWarm)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(KingdomTheme.Typography.title3())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Level \(currentLevel)/\(maxLevel)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            if !isMaxLevel {
                // Benefit
                Text(benefit)
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.vertical, 4)
                
                if hasActiveContract {
                    // Show active contract indicator for THIS building
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text("Contract active for this building")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(KingdomTheme.Colors.parchmentRich)
                    .cornerRadius(8)
                } else if hasAnyActiveContract {
                    // Show warning that another building has an active contract
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("Complete current contract before starting a new one")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(KingdomTheme.Colors.parchmentRich)
                    .cornerRadius(8)
                } else {
                    // Show contract cost prominently
                    VStack(spacing: 8) {
                        // Cost display
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contract Cost")
                                    .font(KingdomTheme.Typography.caption2())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.caption)
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                    Text("\(contractCost)g")
                                        .font(KingdomTheme.Typography.headline())
                                        .fontWeight(.bold)
                                        .foregroundColor(canAfford ? KingdomTheme.Colors.gold : .red)
                                }
                            }
                            
                            Spacer()
                            
                            // Treasury display
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Treasury")
                                    .font(KingdomTheme.Typography.caption2())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.caption)
                                        .foregroundColor(canAfford ? KingdomTheme.Colors.inkMedium : .red)
                                    Text("\(kingdom.treasuryGold)g")
                                        .font(KingdomTheme.Typography.caption())
                                        .fontWeight(.semibold)
                                        .foregroundColor(canAfford ? KingdomTheme.Colors.inkDark : .red)
                                }
                            }
                        }
                        
                        // Actions and button on same row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Actions Required")
                                    .font(KingdomTheme.Typography.caption2())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "hammer.fill")
                                        .font(.caption)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    Text("\(actionsRequired)")
                                        .font(KingdomTheme.Typography.headline())
                                        .fontWeight(.bold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: onCreateContract) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 12))
                                    Text("Post Contract")
                                        .font(KingdomTheme.Typography.caption())
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(canAfford ? KingdomTheme.Colors.buttonWarning : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(KingdomTheme.CornerRadius.medium)
                            }
                            .disabled(!canAfford)
                        }
                    }
                    .padding(12)
                    .background(KingdomTheme.Colors.parchmentRich)
                    .cornerRadius(8)
                }
            } else {
                Text("Maximum level reached")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .italic()
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight, hasShadow: false)
    }
}


