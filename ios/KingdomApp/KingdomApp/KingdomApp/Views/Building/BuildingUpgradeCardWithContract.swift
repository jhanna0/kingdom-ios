import SwiftUI

struct BuildingUpgradeCardWithContract: View {
    let icon: String
    let name: String
    let currentLevel: Int
    let maxLevel: Int
    let benefit: String
    let hasActiveContract: Bool
    let onCreateContract: () -> Void
    
    var isMaxLevel: Bool {
        currentLevel >= maxLevel
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
                Text(benefit)
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.vertical, 4)
                
                if hasActiveContract {
                    // Show active contract indicator
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
                } else {
                    // Create contract
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Contract")
                                .font(KingdomTheme.Typography.caption())
                                .fontWeight(.semibold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Workers build, you pay reward")
                                .font(KingdomTheme.Typography.caption2())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        Spacer()
                        
                        Button(action: onCreateContract) {
                            Text("Post")
                                .font(KingdomTheme.Typography.caption())
                        }
                        .buttonStyle(.medievalSubtle(color: KingdomTheme.Colors.buttonWarning))
                    }
                    .padding(8)
                    .background(KingdomTheme.Colors.parchmentDark.opacity(0.5))
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


