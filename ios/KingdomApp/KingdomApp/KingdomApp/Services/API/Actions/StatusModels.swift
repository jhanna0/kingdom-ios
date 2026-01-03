import Foundation

// MARK: - Global Cooldown

struct GlobalCooldown: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let blockingAction: String?
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case blockingAction = "blocking_action"
    }
}

// MARK: - Expected Reward

struct ExpectedReward: Codable {
    let gold: Int?
    let goldGross: Int?
    let goldBonusMultiplier: Double?
    let buildingSkill: Int?
    let reputation: Int?
    let experience: Int?
    
    enum CodingKeys: String, CodingKey {
        case gold
        case goldGross = "gold_gross"
        case goldBonusMultiplier = "gold_bonus_multiplier"
        case buildingSkill = "building_skill"
        case reputation
        case experience
    }
}

// MARK: - Action Status

struct ActionStatus: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let cooldownMinutes: Double?
    let isPatrolling: Bool?
    let activePatrollers: Int?
    let currentStat: Int?
    let sessionsAvailable: Int?
    let purchaseCost: Int?
    let expectedReward: ExpectedReward?
    
    // Action metadata (ALL from API - frontend is dumb renderer!)
    let unlocked: Bool?
    let actionType: String?
    let requirementsMet: Bool?
    let requirementDescription: String?
    let title: String?
    let icon: String?
    let description: String?
    let category: String?
    let themeColor: String?  // Maps to KingdomTheme.Colors
    let displayOrder: Int?
    let endpoint: String?  // FULLY DYNAMIC: Backend provides complete endpoint with all params
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case cooldownMinutes = "cooldown_minutes"
        case isPatrolling = "is_patrolling"
        case activePatrollers = "active_patrollers"
        case currentStat = "current_stat"
        case sessionsAvailable = "sessions_available"
        case purchaseCost = "purchase_cost"
        case expectedReward = "expected_reward"
        case unlocked
        case actionType = "action_type"
        case requirementsMet = "requirements_met"
        case requirementDescription = "requirement_description"
        case title, icon, description, category
        case themeColor = "theme_color"
        case displayOrder = "display_order"
        case endpoint
    }
}

// MARK: - All Action Status (Combined Response)

struct AllActionStatus: Codable {
    let globalCooldown: GlobalCooldown
    let actions: [String: ActionStatus]  // DYNAMIC - API decides what actions are available
    
    // Legacy fields for backward compatibility
    let work: ActionStatus
    let patrol: ActionStatus
    let farm: ActionStatus
    let sabotage: ActionStatus
    let scout: ActionStatus
    let training: ActionStatus
    let crafting: ActionStatus
    let vaultHeist: ActionStatus?
    
    let trainingContracts: [TrainingContract]
    let trainingCosts: TrainingCosts
    let craftingQueue: [CraftingContract]
    let craftingCosts: CraftingCosts
    let propertyUpgradeContracts: [PropertyUpgradeContract]?
    let contracts: [APIContract]
    
    enum CodingKeys: String, CodingKey {
        case globalCooldown = "global_cooldown"
        case actions
        case work, patrol, farm, sabotage, scout, training, crafting, contracts
        case vaultHeist = "vault_heist"
        case trainingContracts = "training_contracts"
        case trainingCosts = "training_costs"
        case craftingQueue = "crafting_queue"
        case craftingCosts = "crafting_costs"
        case propertyUpgradeContracts = "property_upgrade_contracts"
    }
}

// MARK: - Action Rewards

struct ActionRewards: Codable {
    let gold: Int?
    let reputation: Int?
    let experience: Int?
    let iron: Int?
}

// MARK: - Generic Action Response (Dynamic Actions)

/// Universal response model for all dynamic actions
/// Backend always returns: success, message, rewards (optional)
struct GenericActionResponse: Codable {
    let success: Bool
    let message: String
    let rewards: ActionRewards?
    
    // Optional fields that some actions may include
    let nextActionAvailableAt: Date?
    let nextFarmAvailableAt: Date?
    let nextWorkAvailableAt: Date?
    let nextScoutAvailableAt: Date?
    let nextSabotageAvailableAt: Date?
    let nextTrainAvailableAt: Date?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case nextActionAvailableAt = "next_action_available_at"
        case nextFarmAvailableAt = "next_farm_available_at"
        case nextWorkAvailableAt = "next_work_available_at"
        case nextScoutAvailableAt = "next_scout_available_at"
        case nextSabotageAvailableAt = "next_sabotage_available_at"
        case nextTrainAvailableAt = "next_train_available_at"
        case expiresAt = "expires_at"
    }
}



