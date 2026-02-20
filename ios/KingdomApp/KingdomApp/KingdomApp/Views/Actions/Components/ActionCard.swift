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
    
    var canAffordFood: Bool {
        return status.canAffordFood ?? true
    }
    
    var isReady: Bool {
        return !globalCooldownActive && canAffordFood && (status.ready || calculatedSecondsRemaining <= 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header: Icon + Title + Cooldown badge
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
                    }
                    
                    Text(description)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            // Cost and Reward Row (wraps if needed)
            ActionCostRewardRow(costs: status.buildCostItems(), rewards: status.buildRewardItems())
            
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
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else if !canAffordFood && isEnabled {
                Text("Need food")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else if isReady && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: actionButtonIcon)
                        Text(actionButtonText)
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: actionButtonColor, fullWidth: true))
            } else if !isEnabled {
                Text("Check in to a kingdom first")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else {
                // Show simple cooldown for instant actions (scout/infiltrate)
                // Show progress bar for ongoing actions (farm, patrol, etc.)
                if status.actionType == "scout" {
                    let minutes = calculatedSecondsRemaining / 60
                    let seconds = calculatedSecondsRemaining % 60
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Ready in \(minutes)m \(seconds)s")
                            .font(FontStyles.labelLarge)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
                } else {
                    CooldownTimer(
                        secondsRemaining: calculatedSecondsRemaining,
                        totalSeconds: Int((status.cooldownMinutes ?? 90) * 60)
                    )
                }
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
    
    private var actionButtonColor: Color {
        // Use backend-provided button color if available
        if let buttonColor = status.buttonColor {
            return KingdomTheme.Colors.color(fromThemeName: buttonColor)
        }
        // Hostile actions (scout/infiltrate) use emerald/teal, beneficial actions use green
        if status.category == "hostile" || status.actionType == "scout" {
            return KingdomTheme.Colors.royalEmerald
        }
        return KingdomTheme.Colors.buttonSuccess
    }
    
    private var actionButtonIcon: String {
        // Use backend-provided button text to determine icon
        if let buttonText = status.buttonText {
            switch buttonText {
            case "Fight!":
                return "flame.fill"
            case "Join":
                return "person.badge.plus"
            case "View":
                return "eye.fill"
            default:
                break
            }
        }
        if status.category == "hostile" || status.actionType == "scout" {
            return "eye.fill"
        }
        return "play.fill"
    }
    
    private var actionButtonText: String {
        // Use backend-provided button text if available
        if let buttonText = status.buttonText {
            return buttonText
        }
        if status.actionType == "scout" {
            return "Infiltrate"
        }
        return "Start"
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
    
}


