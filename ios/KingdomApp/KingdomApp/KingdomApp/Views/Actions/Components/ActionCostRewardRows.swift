import SwiftUI

// MARK: - Cost Item (single cost badge)

struct CostItem: Identifiable {
    let id = UUID()
    let icon: String
    let amount: Int
    let color: Color
    let canAfford: Bool
    
    init(icon: String, amount: Int, color: Color = KingdomTheme.Colors.buttonWarning, canAfford: Bool = true) {
        self.icon = icon
        self.amount = amount
        self.color = color
        self.canAfford = canAfford
    }
}

// MARK: - Reward Item (single reward badge)

struct RewardItem: Identifiable {
    let id = UUID()
    let icon: String
    let amount: Int
    let color: Color
    
    init(icon: String, amount: Int, color: Color) {
        self.icon = icon
        self.amount = amount
        self.color = color
    }
}

// MARK: - Cost Row

/// Displays a row of costs with a "COST" label
/// Used in action cards to show food, gold, and resource costs
struct ActionCostRow: View {
    let costs: [CostItem]
    
    var body: some View {
        if !costs.isEmpty {
            HStack(spacing: 8) {
                Text("COST")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(width: 40, alignment: .leading)
                
                HStack(spacing: 6) {
                    ForEach(costs) { cost in
                        costBadge(cost: cost)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func costBadge(cost: CostItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: cost.icon)
                .font(FontStyles.iconMini)
                .foregroundColor(cost.canAfford ? KingdomTheme.Colors.inkMedium : .red)
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

// MARK: - Reward Row

/// Displays a row of rewards with a "REWARD" label
/// Used in action cards to show gold, reputation, and XP rewards
struct ActionRewardRow: View {
    let rewards: [RewardItem]
    
    var body: some View {
        if !rewards.isEmpty {
            HStack(spacing: 8) {
                Text("EARN")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(width: 40, alignment: .leading)
                
                HStack(spacing: 6) {
                    ForEach(rewards) { reward in
                        rewardBadge(reward: reward)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func rewardBadge(reward: RewardItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: reward.icon)
                .font(FontStyles.iconMini)
                .foregroundColor(reward.color)
            Text("\(reward.amount)")
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

// MARK: - Combined Cost/Reward Row

/// Displays costs and rewards as two grouped badges
/// [COST 🍖5 🪵10]  [EARN 💰15 ⭐3]
struct ActionCostRewardRow: View {
    let costs: [CostItem]
    let rewards: [RewardItem]
    
    var body: some View {
        if !costs.isEmpty || !rewards.isEmpty {
            HStack(spacing: 12) {
                // Cost badge - contains label + all costs
                if !costs.isEmpty {
                    costGroupBadge()
                }
                
                // Earn badge - contains label + all rewards
                if !rewards.isEmpty {
                    earnGroupBadge()
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func costGroupBadge() -> some View {
        HStack(spacing: 8) {
            Text("COST")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            ForEach(costs) { cost in
                HStack(spacing: 3) {
                    Image(systemName: cost.icon)
                        .font(FontStyles.iconMini)
                        .foregroundColor(cost.canAfford ? KingdomTheme.Colors.inkMedium : .red)
                    Text("\(cost.amount)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
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
    private func earnGroupBadge() -> some View {
        HStack(spacing: 8) {
            Text("EARN")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            ForEach(rewards) { reward in
                HStack(spacing: 3) {
                    Image(systemName: reward.icon)
                        .font(FontStyles.iconMini)
                        .foregroundColor(reward.color)
                    Text("\(reward.amount)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
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


// MARK: - Helper to build costs from ActionStatus

extension ActionStatus {
    /// Build cost items from this action status
    func buildCostItems(playerFoodTotal: Int? = nil) -> [CostItem] {
        var items: [CostItem] = []
        
        // Food cost (most actions have this)
        if let food = foodCost, food > 0 {
            let canAfford = canAffordFood ?? (playerFoodTotal.map { $0 >= food } ?? true)
            items.append(CostItem(
                icon: "fork.knife",
                amount: food,
                color: KingdomTheme.Colors.buttonWarning,
                canAfford: canAfford
            ))
        }
        
        // Gold cost (scout/infiltrate)
        if let gold = cost, gold > 0 {
            items.append(CostItem(
                icon: "g.circle.fill",
                amount: gold,
                color: KingdomTheme.Colors.goldLight,
                canAfford: true  // We could check player gold here
            ))
        }
        
        return items
    }
    
    /// Build reward items from this action status
    func buildRewardItems() -> [RewardItem] {
        var items: [RewardItem] = []
        
        if let reward = expectedReward {
            // Gold reward
            if let gold = reward.goldGross ?? reward.gold, gold > 0 {
                items.append(RewardItem(
                    icon: "g.circle.fill",
                    amount: gold,
                    color: KingdomTheme.Colors.goldLight
                ))
            }
            
            // Reputation reward
            if let rep = reward.reputation, rep > 0 {
                items.append(RewardItem(
                    icon: "star.fill",
                    amount: rep,
                    color: KingdomTheme.Colors.buttonPrimary
                ))
            }
            
            // XP reward
            if let xp = reward.experience, xp > 0 {
                items.append(RewardItem(
                    icon: "sparkles",
                    amount: xp,
                    color: KingdomTheme.Colors.buttonSuccess
                ))
            }
        }
        
        return items
    }
}

// MARK: - Helper to build costs from PropertyUpgradeContract

extension PropertyUpgradeContract {
    /// Build cost items for property upgrade work
    func buildCostItems() -> [CostItem] {
        var items: [CostItem] = []
        
        // Food cost
        if let food = foodCost, food > 0 {
            items.append(CostItem(
                icon: "fork.knife",
                amount: food,
                color: KingdomTheme.Colors.buttonWarning,
                canAfford: canAffordFood ?? true
            ))
        }
        
        // Per-action resource costs (wood, iron, etc.)
        if let costs = perActionCosts {
            for cost in costs {
                items.append(CostItem(
                    icon: cost.icon,
                    amount: cost.amount,
                    color: KingdomTheme.Colors.buttonWarning,
                    canAfford: canAfford ?? true
                ))
            }
        }
        
        return items
    }
}
