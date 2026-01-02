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
    let cooldownMinutes: Double
    let isPatrolling: Bool?
    let activePatrollers: Int?
    let currentStat: Int?
    let sessionsAvailable: Int?
    let purchaseCost: Int?
    let expectedReward: ExpectedReward?
    
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
    }
}

// MARK: - All Action Status (Combined Response)

struct AllActionStatus: Codable {
    let globalCooldown: GlobalCooldown
    let work: ActionStatus
    let patrol: ActionStatus
    let farm: ActionStatus
    let sabotage: ActionStatus
    let scout: ActionStatus
    let training: ActionStatus
    let crafting: ActionStatus
    let trainingContracts: [TrainingContract]
    let trainingCosts: TrainingCosts
    let craftingQueue: [CraftingContract]
    let craftingCosts: CraftingCosts
    let propertyUpgradeContracts: [PropertyUpgradeContract]?
    let contracts: [APIContract]
    
    enum CodingKeys: String, CodingKey {
        case work, patrol, farm, sabotage, scout, training, crafting, contracts
        case globalCooldown = "global_cooldown"
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



