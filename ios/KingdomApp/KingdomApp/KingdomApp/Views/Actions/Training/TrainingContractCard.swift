import SwiftUI

// MARK: - Training Contract Card

struct TrainingContractCard: View {
    let contract: TrainingContract
    let status: ActionStatus
    let fetchedAt: Date
    let currentTime: Date
    let isEnabled: Bool
    let globalCooldownActive: Bool
    let blockingAction: String?
    let onAction: () -> Void
    
    var calculatedSecondsRemaining: Int {
        let elapsed = currentTime.timeIntervalSince(fetchedAt)
        let remaining = max(0, Double(status.secondsRemaining) - elapsed)
        return Int(remaining)
    }
    
    var isReady: Bool {
        return !globalCooldownActive && (status.ready || calculatedSecondsRemaining <= 0)
    }
    
    var iconName: String {
        switch contract.type {
        case "attack": return "bolt.fill"
        case "defense": return "shield.fill"
        case "leadership": return "crown.fill"
        case "building": return "hammer.fill"
        default: return "star.fill"
        }
    }
    
    var title: String {
        switch contract.type {
        case "attack": return "Attack Training"
        case "defense": return "Defense Training"
        case "leadership": return "Leadership Training"
        case "building": return "Building Training"
        default: return "Training"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isReady ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
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
            } else if isReady && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Train Now")
                    }
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else if !isEnabled {
                Text("Check in to a kingdom to train")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KingdomTheme.Colors.parchmentDark)
                    .cornerRadius(KingdomTheme.CornerRadius.medium)
            } else {
                CooldownTimer(
                    secondsRemaining: calculatedSecondsRemaining,
                    totalSeconds: Int(status.cooldownMinutes * 60)
                )
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
}

