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
    let onCreateContract: () -> Void
    
    var isMaxLevel: Bool {
        currentLevel >= maxLevel
    }
    
    // Calculate contract cost right here
    private var contractCost: Int {
        let nextLevel = currentLevel + 1
        let baseHours = 2.0 * pow(2.0, Double(nextLevel - 1))
        let populationMultiplier = 1.0 + (Double(kingdom.checkedInPlayers) / 30.0)
        let estimatedHours = baseHours * populationMultiplier
        
        let baseReward = 100 * nextLevel
        let timeBonus = Int(estimatedHours * 10.0)
        return baseReward + timeBonus
    }
    
    private var canAfford: Bool {
        kingdom.treasuryGold >= contractCost
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
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        Text("Contract active for this building")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(KingdomTheme.Colors.parchmentDark)
                    .cornerRadius(8)
                } else if hasAnyActiveContract {
                    // Show warning that another building has an active contract
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        Text("Complete current contract before starting a new one")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
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
                        
                        // Post contract button
                        Button(action: onCreateContract) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text(canAfford ? "Post Contract" : "Insufficient Funds")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.medieval(color: canAfford ? KingdomTheme.Colors.buttonWarning : .gray, fullWidth: true))
                        .disabled(!canAfford)  // Button is already disabled by hasAnyActiveContract check above
                    }
                    .padding(12)
                    .background(KingdomTheme.Colors.parchmentDark.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? KingdomTheme.Colors.gold.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                    )
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


