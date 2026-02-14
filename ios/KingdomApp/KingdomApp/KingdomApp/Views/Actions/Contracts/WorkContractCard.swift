import SwiftUI

// MARK: - Work Contract Card

struct WorkContractCard: View {
    let contract: Contract
    let status: ActionStatus
    let fetchedAt: Date
    let currentTime: Date
    let globalCooldownActive: Bool
    let blockingAction: String?
    let globalCooldownSecondsRemaining: Int
    let onAction: () -> Void
    let onRefresh: (() -> Void)?  // Callback to refresh after book use
    
    @State private var showBookPopup = false
    
    init(
        contract: Contract,
        status: ActionStatus,
        fetchedAt: Date,
        currentTime: Date,
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
    
    // Build cost items for this contract (food + resources)
    private func buildCostItems() -> [CostItem] {
        var items: [CostItem] = []
        
        // Food cost from status
        if let food = status.foodCost, food > 0 {
            items.append(CostItem(
                icon: "fork.knife",
                amount: food,
                color: KingdomTheme.Colors.buttonWarning,
                canAfford: status.canAffordFood ?? true
            ))
        }
        
        // Per-action resource costs from contract
        if let costs = contract.perActionCosts {
            for cost in costs {
                items.append(CostItem(
                    icon: cost.icon,
                    amount: cost.amount,
                    color: KingdomTheme.Colors.buttonWarning,
                    canAfford: true  // Resource affordability checked elsewhere
                ))
            }
        }
        
        return items
    }
    
    // Build reward items for this contract (gold per action)
    private func buildRewardItems() -> [RewardItem] {
        var items: [RewardItem] = []
        
        if contract.actionReward > 0 {
            items.append(RewardItem(
                icon: "g.circle.fill",
                amount: contract.actionReward,
                color: KingdomTheme.Colors.goldLight
            ))
        }
        
        return items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header: Icon + Title + Cooldown
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                // Icon in brutalist badge
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: ActionIconHelper.actionColor(for: "work"),
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(contract.buildingDisplayName ?? contract.buildingType)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // Cooldown time with hourglass
                        if let cooldownMinutes = status.cooldownMinutes {
                            cooldownBadge(minutes: cooldownMinutes)
                        }
                    }
                    
                    if let benefit = contract.buildingBenefit {
                        Text("Unlocks: \(benefit)")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(contract.actionsCompleted)/\(contract.totalActionsRequired) actions")
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
            
            // Cost and Reward Row (wraps if needed)
            ActionCostRewardRow(costs: buildCostItems(), rewards: buildRewardItems())
            
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
            } else if isReady {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Work on This")
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
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
                slot: "building",
                actionType: blockingAction,
                cooldownSecondsRemaining: calculatedSecondsRemaining,
                isShowing: $showBookPopup,
                onUseBook: {
                    Task {
                        let response = await StoreService.shared.useBook(on: "building", actionType: blockingAction)
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

