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
    let globalCooldownSecondsRemaining: Int
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
    
    var iconColor: Color {
        // Keep specific colors for training types (not in ActionIconHelper)
        switch contract.type {
        case "attack": return KingdomTheme.Colors.buttonDanger
        case "defense": return KingdomTheme.Colors.buttonPrimary
        case "leadership": return KingdomTheme.Colors.gold
        case "building": return KingdomTheme.Colors.buttonWarning
        default: return ActionIconHelper.actionColor(for: "training")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                // Icon in brutalist badge
                Image(systemName: iconName)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: isReady ? iconColor : KingdomTheme.Colors.disabled,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
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
                let elapsed = currentTime.timeIntervalSince(fetchedAt)
                let calculatedRemaining = max(0, Double(globalCooldownSecondsRemaining) - elapsed)
                let remaining = Int(calculatedRemaining)
                let minutes = remaining / 60
                let seconds = remaining % 60
                
                Text("\(blockingActionDisplay) for \(minutes)m \(seconds)s")
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
                        Text("Start")
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
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
}

