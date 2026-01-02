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
                    .font(FontStyles.iconLarge)
                    .foregroundColor(isReady ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 4) {
                        Text("\(contract.actionsCompleted)/\(contract.actionsRequired) actions")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("•")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("\(Int(contract.progress * 100))%")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar - brutalist style
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 12)
                        .brutalistProgressBar()
                    
                    ZStack {
                        Rectangle()
                            .fill(KingdomTheme.Colors.gold)
                            .frame(width: max(0, geometry.size.width * contract.progress - 4), height: 8)
                            .offset(x: 2)
                        
                        // Animated diagonal stripes
                        AnimatedStripes()
                            .frame(width: max(0, geometry.size.width * contract.progress - 4), height: 8)
                            .offset(x: 2)
                            .mask(
                                Rectangle()
                                    .frame(width: max(0, geometry.size.width * contract.progress - 4), height: 8)
                            )
                    }
                }
            }
            .frame(height: 12)
            
            if globalCooldownActive {
                let blockingActionDisplay = actionNameToDisplayName(blockingAction)
                Text("You are already \(blockingActionDisplay)")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else if isReady && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Train Now")
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else if !isEnabled {
                Text("Check in to a kingdom to train")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else {
                CooldownTimer(
                    secondsRemaining: calculatedSecondsRemaining,
                    totalSeconds: Int(status.cooldownMinutes * 60)
                )
            }
        }
        .padding()
        .brutalistCard()
        .padding(.horizontal)
    }
}

