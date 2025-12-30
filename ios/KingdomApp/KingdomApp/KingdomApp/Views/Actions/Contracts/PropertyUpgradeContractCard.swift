import SwiftUI

// MARK: - Property Upgrade Contract Card

struct PropertyUpgradeContractCard: View {
    let contract: PropertyUpgradeContract
    let fetchedAt: Date
    let currentTime: Date
    let globalCooldownActive: Bool
    let blockingAction: String?
    let onAction: () -> Void
    
    var isReady: Bool {
        return !globalCooldownActive
    }
    
    var iconName: String {
        switch contract.toTier {
        case 2: return "house.fill"
        case 3: return "hammer.fill"
        case 4: return "building.columns.fill"
        case 5: return "crown.fill"
        default: return "building.2.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isReady ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Building \(contract.targetTierName)")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 4) {
                        Text("\(contract.actionsCompleted)/\(contract.actionsRequired) actions")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("•")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("\(Int(contract.progress * 100))%")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 8)
                    
                    ZStack {
                        Rectangle()
                            .fill(KingdomTheme.Colors.gold)
                            .frame(width: geometry.size.width * contract.progress, height: 8)
                        
                        // Animated diagonal stripes
                        AnimatedStripes()
                            .frame(width: geometry.size.width * contract.progress, height: 8)
                            .mask(
                                Rectangle()
                                    .frame(width: geometry.size.width * contract.progress, height: 8)
                            )
                    }
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            if globalCooldownActive {
                let blockingActionDisplay = actionNameToDisplayName(blockingAction)
                Text("You are already \(blockingActionDisplay)")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KingdomTheme.Colors.parchmentDark)
                    .cornerRadius(KingdomTheme.CornerRadius.medium)
            } else if isReady {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Work on Property")
                    }
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
}

