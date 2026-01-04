import SwiftUI

// MARK: - Action Card

struct ActionCard: View {
    let title: String
    let icon: String
    let description: String
    let status: ActionStatus
    let fetchedAt: Date
    let currentTime: Date
    let isEnabled: Bool
    let activeCount: Int?
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                // Icon in brutalist badge
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: iconColor,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Show active count for patrol
                        if let count = activeCount {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(FontStyles.labelBadge)
                                Text("\(count)")
                                    .font(FontStyles.labelTiny)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .brutalistBadge(
                                backgroundColor: count > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
                                cornerRadius: 6,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                        }
                        
                        Spacer()
                        
                        // Cooldown time with hourglass
                        if let cooldownMinutes = status.cooldownMinutes {
                            cooldownBadge(minutes: cooldownMinutes)
                        }
                        
                        // Show expected rewards inline
                        if let reward = status.expectedReward {
                            expectedRewardViewInline(reward: reward)
                        }
                    }
                    
                    Text(description)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
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
                Text("Check in to a kingdom first")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else {
                CooldownTimer(
                    secondsRemaining: calculatedSecondsRemaining,
                    totalSeconds: Int((status.cooldownMinutes ?? 120) * 60)
                )
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private var iconColor: Color {
        // Use theme_color from API if available, otherwise fall back to action type
        if let themeColor = status.themeColor {
            return KingdomTheme.Colors.color(fromThemeName: themeColor)
        } else if let actionType = status.actionType {
            return ActionIconHelper.actionColor(for: actionType)
        } else {
            return KingdomTheme.Colors.inkMedium
        }
    }
    
    @ViewBuilder
    private func cooldownBadge(minutes: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(FontStyles.iconMini)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if minutes >= 60 {
                let hours = minutes / 60
                if hours >= 24 {
                    let days = hours / 24
                    Text(String(format: "%.0fd", days))
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                } else {
                    Text(String(format: "%.0fh", hours))
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            } else {
                Text("\(Int(minutes))m")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchment,
            cornerRadius: 6,
            shadowOffset: 1,
            borderWidth: 1.5
        )
    }
    
    @ViewBuilder
    private func expectedRewardViewInline(reward: ExpectedReward) -> some View {
        HStack(spacing: 6) {
            if let gold = reward.gold {
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.goldLight)
                    Text("\(gold)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    cornerRadius: 6,
                    shadowOffset: 1,
                    borderWidth: 1.5
                )
            } else if let goldGross = reward.goldGross {
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.goldLight)
                    Text("\(goldGross)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    cornerRadius: 6,
                    shadowOffset: 1,
                    borderWidth: 1.5
                )
            }
            
            if let reputation = reward.reputation {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    Text("\(reputation)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    cornerRadius: 6,
                    shadowOffset: 1,
                    borderWidth: 1.5
                )
            }
            
            if let experience = reward.experience {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    Text("\(experience)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchment,
                    cornerRadius: 6,
                    shadowOffset: 1,
                    borderWidth: 1.5
                )
            }
        }
    }
}


