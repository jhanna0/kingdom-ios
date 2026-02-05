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
    let color: String?  // Theme color name from backend (e.g., "brown", "gray")
    let canAfford: Bool?  // Per-resource affordability (nil = assume true for backwards compat)
    
    enum CodingKeys: String, CodingKey {
        case resource, amount, icon, color
        case displayName = "display_name"
        case canAfford = "can_afford"
    }
}

// MARK: - Property Upgrade Contract

struct PropertyUpgradeContract: Codable, Identifiable {
    let contractId: String
    let propertyId: String
    let fromTier: Int
    let toTier: Int
    let targetTierName: String  // Contains option name (e.g., "Kitchen") or tier name as fallback
    let actionsRequired: Int
    let actionsCompleted: Int
    let cost: Int  // OLD: upfront payment (backwards compat)
    let status: String
    let startedAt: String
    let endpoint: String?  // Dynamic endpoint from backend
    let perActionCosts: [PerActionResourceCost]?  // Resources required per work action
    let canAfford: Bool?  // Can player afford the per-action costs?
    let foodCost: Int?  // Food cost per action (0.5 per minute of cooldown)
    let canAffordFood: Bool?  // Can player afford the food cost?
    
    // NEW: Pay-per-action gold system
    let goldPerAction: Double?  // Gold cost per action (before tax)
    let currentTaxRate: Int?    // Kingdom tax rate (for display)
    let canAffordGold: Bool?    // Can player afford the gold cost?
    
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
        case foodCost = "food_cost"
        case canAffordFood = "can_afford_food"
        case goldPerAction = "gold_per_action"
        case currentTaxRate = "current_tax_rate"
        case canAffordGold = "can_afford_gold"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
    
    /// Format per-action costs for display (e.g. "6 wood, 4 iron")
    var perActionCostDescription: String? {
        guard let costs = perActionCosts, !costs.isEmpty else { return nil }
        return costs.map { "\($0.amount) \($0.displayName.lowercased())" }.joined(separator: ", ")
    }
    
    /// Check if this is a new pay-per-action contract
    var isPayPerAction: Bool {
        return (goldPerAction ?? 0) > 0
    }
    
    /// Calculate gold cost with tax for display
    var goldCostWithTax: Double {
        let base = goldPerAction ?? 0
        let taxRate = Double(currentTaxRate ?? 0) / 100.0
        return base * (1 + taxRate)
    }
    
    /// Tax amount per action
    var taxAmount: Double {
        let base = goldPerAction ?? 0
        let taxRate = Double(currentTaxRate ?? 0) / 100.0
        return base * taxRate
    }
}

// MARK: - Workshop Contract (blueprint-based crafting)

struct WorkshopContract: Codable, Identifiable {
    let contractId: String
    let itemId: String
    let displayName: String
    let icon: String
    let color: String
    let type: String
    let tier: Int
    let attackBonus: Int
    let defenseBonus: Int
    let actionsRequired: Int
    let actionsCompleted: Int
    let progressPercent: Int
    let createdAt: String?
    let status: String
    let endpoint: String?
    
    var id: String { contractId }
    
    enum CodingKeys: String, CodingKey {
        case status, icon, color, type, tier, endpoint
        case contractId = "id"
        case itemId = "item_id"
        case displayName = "display_name"
        case attackBonus = "attack_bonus"
        case defenseBonus = "defense_bonus"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case progressPercent = "progress_percent"
        case createdAt = "created_at"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
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

// MARK: - Building Catchup Contract

/// Catchup work for buildings player didn't help construct.
/// Only shows buildings they've tried to access (not all buildings).
struct CatchupContract: Codable, Identifiable {
    let contractId: String
    let buildingType: String
    let buildingDisplayName: String
    let buildingIcon: String
    let kingdomId: String
    let actionsRequired: Int
    let actionsCompleted: Int
    let actionsRemaining: Int
    let progressPercent: Int
    let createdAt: String?
    let status: String
    let endpoint: String?
    
    var id: String { contractId }
    
    enum CodingKeys: String, CodingKey {
        case status, endpoint
        case contractId = "id"
        case buildingType = "building_type"
        case buildingDisplayName = "building_display_name"
        case buildingIcon = "building_icon"
        case kingdomId = "kingdom_id"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case actionsRemaining = "actions_remaining"
        case progressPercent = "progress_percent"
        case createdAt = "created_at"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
}
