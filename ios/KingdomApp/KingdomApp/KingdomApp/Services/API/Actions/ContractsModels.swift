import Foundation

// MARK: - Work Action Response

struct WorkActionResponse: Codable {
    let success: Bool
    let message: String
    let contractId: String
    let actionsCompleted: Int
    let totalActionsRequired: Int
    let progressPercent: Int
    let yourContribution: Int
    let isComplete: Bool
    let nextWorkAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case contractId = "contract_id"
        case actionsCompleted = "actions_completed"
        case totalActionsRequired = "total_actions_required"
        case progressPercent = "progress_percent"
        case yourContribution = "your_contribution"
        case isComplete = "is_complete"
        case nextWorkAvailableAt = "next_work_available_at"
    }
}

// MARK: - Per-Action Resource Cost (for property upgrades)

/// Dynamic resource cost - required per action during property upgrade work
struct PerActionResourceCost: Codable {
    let resource: String
    let amount: Int
    let displayName: String
    let icon: String
    
    enum CodingKeys: String, CodingKey {
        case resource, amount, icon
        case displayName = "display_name"
    }
}

// MARK: - Property Upgrade Contract

struct PropertyUpgradeContract: Codable, Identifiable {
    let contractId: String
    let propertyId: String
    let fromTier: Int
    let toTier: Int
    let targetTierName: String
    let actionsRequired: Int
    let actionsCompleted: Int
    let cost: Int
    let status: String
    let startedAt: String
    let endpoint: String?  // Dynamic endpoint from backend
    let perActionCosts: [PerActionResourceCost]?  // Resources required per work action
    let canAfford: Bool?  // Can player afford the per-action costs?
    
    var id: String { contractId }
    
    enum CodingKeys: String, CodingKey {
        case status
        case contractId = "contract_id"
        case propertyId = "property_id"
        case fromTier = "from_tier"
        case toTier = "to_tier"
        case targetTierName = "target_tier_name"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case cost
        case startedAt = "started_at"
        case endpoint
        case perActionCosts = "per_action_costs"
        case canAfford = "can_afford"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
    
    /// Format per-action costs for display (e.g. "6 wood, 4 iron")
    var perActionCostDescription: String? {
        guard let costs = perActionCosts, !costs.isEmpty else { return nil }
        return costs.map { "\($0.amount) \($0.displayName.lowercased())" }.joined(separator: ", ")
    }
}

// MARK: - Resource Consumed (result of an action)

struct ResourceConsumed: Codable {
    let resource: String
    let amount: Int
    let newTotal: Int
    
    enum CodingKeys: String, CodingKey {
        case resource, amount
        case newTotal = "new_total"
    }
}

// MARK: - Property Upgrade Action Response

struct PropertyUpgradeActionResponse: Codable {
    let success: Bool
    let message: String
    let contractId: String
    let propertyId: String
    let actionsCompleted: Int
    let actionsRequired: Int
    let progressPercent: Int
    let isComplete: Bool
    let newTier: Int?
    let resourcesConsumed: [ResourceConsumed]?  // NEW: What resources were required this action
    let perActionCosts: [PerActionResourceCost]?  // What future actions will cost
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case contractId = "contract_id"
        case propertyId = "property_id"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case newTier = "new_tier"
        case resourcesConsumed = "resources_required"
        case perActionCosts = "per_action_costs"
    }
}



