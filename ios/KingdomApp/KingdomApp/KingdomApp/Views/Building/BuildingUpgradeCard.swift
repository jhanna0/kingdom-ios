import SwiftUI

struct BuildingUpgradeCard: View {
    let icon: String
    let name: String
    let currentLevel: Int
    let maxLevel: Int
    let cost: Int
    let benefit: String
    let kingdomTreasury: Int
    let onUpgrade: () -> Void
    
    var canAfford: Bool {
        kingdomTreasury >= cost
    }
    
    var isMaxLevel: Bool {
        currentLevel >= maxLevel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
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
                Text(benefit)
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.vertical, 4)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption)
                        Text("\(cost)")
                            .font(KingdomTheme.Typography.headline())
                            .fontWeight(.bold)
                        Text("from treasury")
                            .font(KingdomTheme.Typography.caption())
                    }
                    .foregroundColor(canAfford ? KingdomTheme.Colors.inkMedium : .red)
                    
                    Spacer()
                    
                    Button(action: onUpgrade) {
                        Text("Upgrade")
                    }
                    .buttonStyle(.medieval(color: canAfford ? KingdomTheme.Colors.buttonPrimary : .gray))
                    .disabled(!canAfford)
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
