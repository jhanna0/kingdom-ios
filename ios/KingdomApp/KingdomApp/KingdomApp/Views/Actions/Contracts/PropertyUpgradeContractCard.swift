import SwiftUI

// MARK: - Property Upgrade Contract Card

struct PropertyUpgradeContractCard: View {
    let contract: PropertyUpgradeContract
    let fetchedAt: Date
    let currentTime: Date
    let globalCooldownActive: Bool
    let blockingAction: String?
    let globalCooldownSecondsRemaining: Int
    let onAction: () -> Void
    
    var isReady: Bool {
        return !globalCooldownActive && (contract.canAfford ?? true)
    }
    
    var canAfford: Bool {
        return contract.canAfford ?? true
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
    
    var iconColor: Color {
        // Consistent green for all property upgrades
        return KingdomTheme.Colors.buttonSuccess
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
                        backgroundColor: iconColor,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Building \(contract.targetTierName)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // Cooldown time with hourglass (2 hours for property upgrades)
                        cooldownBadge(minutes: 120)
                        
                        // Per-action resource costs as badges
                        if let costs = contract.perActionCosts {
                            ForEach(costs, id: \.resource) { cost in
                                HStack(spacing: 4) {
                                    Image(systemName: cost.icon)
                                        .font(FontStyles.iconMini)
                                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                                    Text("\(cost.amount)")
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
                    
                    HStack(spacing: 4) {
                        Text("\(contract.actionsCompleted)/\(contract.actionsRequired) actions")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("•")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("\(Int(contract.progress * 100))%")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
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
                            .fill(KingdomTheme.Colors.buttonSuccess)
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
            } else if !canAfford {
                Text("Need resources")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else if isReady {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Work on Property")
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
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

