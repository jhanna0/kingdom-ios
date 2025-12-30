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
                        .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.gold)
                        .frame(width: geometry.size.width * contract.progress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Action button
            Button(action: onAction) {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("Work on Property")
                }
            }
            .buttonStyle(.medieval(
                color: isReady ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled,
                fullWidth: true
            ))
            .disabled(!isReady)
            
            if globalCooldownActive {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("Complete \(blockingAction ?? "current action") first")
                        .font(KingdomTheme.Typography.caption())
                }
                .foregroundColor(KingdomTheme.Colors.buttonWarning)
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(KingdomTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.medium)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal)
    }
}

