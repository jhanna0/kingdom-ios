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
    let onRefresh: (() -> Void)?  // Callback to refresh after book use
    
    @State private var showBookPopup = false
    
    init(
        contract: TrainingContract,
        status: ActionStatus,
        fetchedAt: Date,
        currentTime: Date,
        isEnabled: Bool,
        globalCooldownActive: Bool,
        blockingAction: String?,
        globalCooldownSecondsRemaining: Int,
        onAction: @escaping () -> Void,
        onRefresh: (() -> Void)? = nil
    ) {
        self.contract = contract
        self.status = status
        self.fetchedAt = fetchedAt
        self.currentTime = currentTime
        self.isEnabled = isEnabled
        self.globalCooldownActive = globalCooldownActive
        self.blockingAction = blockingAction
        self.globalCooldownSecondsRemaining = globalCooldownSecondsRemaining
        self.onAction = onAction
        self.onRefresh = onRefresh
    }
    
    var calculatedSecondsRemaining: Int {
        let elapsed = currentTime.timeIntervalSince(fetchedAt)
        let remaining = max(0, Double(status.secondsRemaining) - elapsed)
        return Int(remaining)
    }
    
    var isReady: Bool {
        let canAffordFood = status.canAffordFood ?? true
        return !globalCooldownActive && canAffordFood && (status.ready || calculatedSecondsRemaining <= 0)
    }
    
    var skillConfig: SkillConfig {
        SkillConfig.get(contract.type)
    }
    
    var iconName: String {
        skillConfig.icon
    }
    
    var title: String {
        "\(skillConfig.displayName) Training"
    }
    
    var iconColor: Color {
        skillConfig.color
    }
    
    // Build cost items (food for training)
    private func buildCostItems() -> [CostItem] {
        var items: [CostItem] = []
        
        if let food = status.foodCost, food > 0 {
            items.append(CostItem(
                icon: "fork.knife",
                amount: food,
                color: KingdomTheme.Colors.buttonWarning,
                canAfford: status.canAffordFood ?? true
            ))
        }
        
        return items
    }
    
    // Build gold cost with tax (for pay-per-action contracts)
    private func buildGoldCost() -> CostItemWithTax? {
        return contract.buildGoldCostItem(canAfford: canAffordGold)
    }
    
    // Check if player can afford gold cost
    private var canAffordGold: Bool {
        // For now assume true - backend will validate
        // Future: pass player gold from parent view
        return true
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
                        Text(title)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // Cooldown time with hourglass
                        if let cooldownMinutes = status.cooldownMinutes {
                            cooldownBadge(minutes: cooldownMinutes)
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
            
            // Cost and Reward Row (with tax support for pay-per-action)
            ActionCostRewardRowWithTax(costs: buildCostItems(), goldCost: buildGoldCost(), rewards: status.buildRewardItems())
            
            // Progress bar - brutalist style
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 12)
                        .brutalistProgressBar()
                    
                    ZStack {
                        Rectangle()
                            .fill(KingdomTheme.Colors.inkMedium)
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
                
                ZStack {
                    Text("\(blockingActionDisplay) for \(minutes)m \(seconds)s")
                        .font(FontStyles.labelLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                    
                    if status.canUseBook == true {
                        HStack {
                            Spacer()
                            Button(action: { showBookPopup = true }) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .brutalistBadge(backgroundColor: .brown, cornerRadius: 6, shadowOffset: 2, borderWidth: 1.5)
                            }
                        }
                    }
                }
                .frame(height: 38)
                .padding(.horizontal, 12)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else if !(status.canAffordFood ?? true) {
                Text("Need food")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else if isReady && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Train")
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else if !isEnabled {
                Text("Training not available")
                    .font(FontStyles.labelLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else {
                CooldownTimer(
                    secondsRemaining: calculatedSecondsRemaining,
                    totalSeconds: Int(status.cooldownMinutes ?? 120 * 60),
                    onBookTap: status.canUseBook == true ? { showBookPopup = true } : nil
                )
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
        .fullScreenCover(isPresented: $showBookPopup) {
            BookUsagePopup(
                slot: "personal",
                actionType: blockingAction,
                cooldownSecondsRemaining: calculatedSecondsRemaining,
                isShowing: $showBookPopup,
                onUseBook: {
                    Task {
                        let response = await StoreService.shared.useBook(on: "personal", actionType: blockingAction)
                        if response?.success == true {
                            onRefresh?()
                        }
                    }
                },
                onBuyBooks: {
                    NotificationCenter.default.post(name: .openStore, object: nil)
                }
            )
            .background(ClearBackgroundView())
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
}

