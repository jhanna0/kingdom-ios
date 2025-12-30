import Foundation

// MARK: - Action Status Models

struct ActionStatus: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let cooldownMinutes: Double
    let isPatrolling: Bool?
    let activePatrollers: Int?
    let currentStat: Int?
    let sessionsAvailable: Int?
    let purchaseCost: Int?
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case cooldownMinutes = "cooldown_minutes"
        case isPatrolling = "is_patrolling"
        case activePatrollers = "active_patrollers"
        case currentStat = "current_stat"
        case sessionsAvailable = "sessions_available"
        case purchaseCost = "purchase_cost"
    }
}

struct TrainingContract: Codable, Identifiable {
    let id: String
    let type: String
    let actionsRequired: Int
    let actionsCompleted: Int
    let costPaid: Int
    let createdAt: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, status
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case costPaid = "cost_paid"
        case createdAt = "created_at"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
}

struct TrainingCosts: Codable {
    let attack: Int
    let defense: Int
    let leadership: Int
    let building: Int
}

struct CraftingContract: Codable, Identifiable {
    let id: String
    let equipmentType: String
    let tier: Int
    let actionsRequired: Int
    let actionsCompleted: Int
    let goldPaid: Int
    let ironPaid: Int
    let steelPaid: Int
    let createdAt: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, tier, status
        case equipmentType = "equipment_type"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case goldPaid = "gold_paid"
        case ironPaid = "iron_paid"
        case steelPaid = "steel_paid"
        case createdAt = "created_at"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
}

struct CraftingCostTier: Codable {
    let gold: Int
    let iron: Int
    let steel: Int
    let actionsRequired: Int
    let statBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case gold, iron, steel
        case actionsRequired = "actions_required"
        case statBonus = "stat_bonus"
    }
}

struct CraftingCosts: Codable {
    let tier1: CraftingCostTier
    let tier2: CraftingCostTier
    let tier3: CraftingCostTier
    let tier4: CraftingCostTier
    let tier5: CraftingCostTier
    
    enum CodingKeys: String, CodingKey {
        case tier1 = "tier_1"
        case tier2 = "tier_2"
        case tier3 = "tier_3"
        case tier4 = "tier_4"
        case tier5 = "tier_5"
    }
    
    func cost(for tier: Int) -> CraftingCostTier? {
        switch tier {
        case 1: return tier1
        case 2: return tier2
        case 3: return tier3
        case 4: return tier4
        case 5: return tier5
        default: return nil
        }
    }
}

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
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
}

struct TrainingCostsResponse: Codable {
    let totalTrainingPurchases: Int
    let costs: TrainingCosts
    let currentStats: CurrentStats
    let gold: Int
    
    struct CurrentStats: Codable {
        let attack: Int
        let defense: Int
        let leadership: Int
        let building: Int
        let intelligence: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case costs, gold
        case totalTrainingPurchases = "total_training_purchases"
        case currentStats = "current_stats"
    }
}

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

struct AllActionStatus: Codable {
    let globalCooldown: GlobalCooldown
    let work: ActionStatus
    let patrol: ActionStatus
    let sabotage: ActionStatus
    let scout: ActionStatus
    let training: ActionStatus
    let crafting: ActionStatus
    let trainingContracts: [TrainingContract]
    let trainingCosts: TrainingCosts
    let craftingQueue: [CraftingContract]
    let craftingCosts: CraftingCosts
    let propertyUpgradeContracts: [PropertyUpgradeContract]?  // Optional for backwards compatibility
    let contracts: [APIContract]
    
    enum CodingKeys: String, CodingKey {
        case work, patrol, sabotage, scout, training, crafting, contracts
        case globalCooldown = "global_cooldown"
        case trainingContracts = "training_contracts"
        case trainingCosts = "training_costs"
        case craftingQueue = "crafting_queue"
        case craftingCosts = "crafting_costs"
        case propertyUpgradeContracts = "property_upgrade_contracts"
    }
}

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

struct PatrolActionResponse: Codable {
    let success: Bool
    let message: String
    let expiresAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case expiresAt = "expires_at"
    }
}

struct KingdomIntelligence: Codable {
    let kingdomName: String
    let rulerName: String
    let wallLevel: Int
    let vaultLevel: Int
    let mineLevel: Int
    let marketLevel: Int
    let treasuryGold: Int
    let checkedInPlayers: Int
    let population: Int
    
    enum CodingKeys: String, CodingKey {
        case kingdomName = "kingdom_name"
        case rulerName = "ruler_name"
        case wallLevel = "wall_level"
        case vaultLevel = "vault_level"
        case mineLevel = "mine_level"
        case marketLevel = "market_level"
        case treasuryGold = "treasury_gold"
        case checkedInPlayers = "checked_in_players"
        case population
    }
}

struct ScoutActionResponse: Codable {
    let success: Bool
    let message: String
    let intelligence: KingdomIntelligence
    let nextScoutAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, intelligence, rewards
        case nextScoutAvailableAt = "next_scout_available_at"
    }
}

struct ActionRewards: Codable {
    let gold: Int?
    let reputation: Int?
    let experience: Int?
    let iron: Int?
}

struct TrainingActionResponse: Codable {
    let success: Bool
    let message: String
    let contractId: String
    let trainingType: String
    let actionsCompleted: Int
    let actionsRequired: Int
    let progressPercent: Int
    let isComplete: Bool
    let nextTrainAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case contractId = "contract_id"
        case trainingType = "training_type"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case nextTrainAvailableAt = "next_train_available_at"
    }
}

struct PurchaseTrainingResponse: Codable {
    let success: Bool
    let message: String
    let trainingType: String
    let cost: Int
    let contractId: String
    let actionsRequired: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, cost
        case trainingType = "training_type"
        case contractId = "contract_id"
        case actionsRequired = "actions_required"
    }
}

struct PurchaseCraftResponse: Codable {
    let success: Bool
    let message: String
    let equipmentType: String
    let tier: Int
    let contractId: String
    let actionsRequired: Int
    let statBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, tier
        case equipmentType = "equipment_type"
        case contractId = "contract_id"
        case actionsRequired = "actions_required"
        case statBonus = "stat_bonus"
    }
}

struct CraftingActionResponse: Codable {
    struct EquipmentReward: Codable {
        let id: String
        let type: String
        let tier: Int
        let attackBonus: Int
        let defenseBonus: Int
        let craftedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, type, tier
            case attackBonus = "attack_bonus"
            case defenseBonus = "defense_bonus"
            case craftedAt = "crafted_at"
        }
    }
    
    struct CraftRewards: Codable {
        let xp: Int
        let equipment: EquipmentReward?
    }
    
    let success: Bool
    let message: String
    let contractId: String
    let actionsCompleted: Int
    let actionsRequired: Int
    let progressPercent: Int
    let isComplete: Bool
    let nextCraftAvailableAt: Date
    let rewards: CraftRewards
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case contractId = "contract_id"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case nextCraftAvailableAt = "next_craft_available_at"
    }
}

struct EquipResponse: Codable {
    let success: Bool
    let message: String
    let equipped: CraftingActionResponse.EquipmentReward?
}

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
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case contractId = "contract_id"
        case propertyId = "property_id"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case newTier = "new_tier"
    }
}

// MARK: - Sabotage Models

struct SabotageTarget: Codable, Identifiable {
    let contractId: Int
    let buildingType: String
    let buildingLevel: Int
    let progress: String
    let progressPercent: Int
    let createdAt: String?
    let potentialDelay: Int
    
    var id: Int { contractId }
    
    enum CodingKeys: String, CodingKey {
        case contractId = "contract_id"
        case buildingType = "building_type"
        case buildingLevel = "building_level"
        case progress
        case progressPercent = "progress_percent"
        case createdAt = "created_at"
        case potentialDelay = "potential_delay"
    }
}

struct SabotageTargetsResponse: Codable {
    struct Kingdom: Codable {
        let id: String
        let name: String
    }
    
    struct Cooldown: Codable {
        let ready: Bool
        let secondsRemaining: Int
        
        enum CodingKeys: String, CodingKey {
            case ready
            case secondsRemaining = "seconds_remaining"
        }
    }
    
    let kingdom: Kingdom
    let targets: [SabotageTarget]
    let sabotageCost: Int
    let canSabotage: Bool
    let cooldown: Cooldown
    let goldAvailable: Int
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case kingdom, targets, cooldown, message
        case sabotageCost = "sabotage_cost"
        case canSabotage = "can_sabotage"
        case goldAvailable = "gold_available"
    }
}

struct SabotageActionResponse: Codable {
    struct SabotageDetails: Codable {
        struct TargetContract: Codable {
            let id: Int
            let buildingType: String
            let buildingLevel: Int
            
            enum CodingKeys: String, CodingKey {
                case id
                case buildingType = "building_type"
                case buildingLevel = "building_level"
            }
        }
        
        let targetKingdom: String
        let targetContract: TargetContract
        let delayApplied: String
        let newTotalActions: Int
        let currentProgress: String
        
        enum CodingKeys: String, CodingKey {
            case targetKingdom = "target_kingdom"
            case targetContract = "target_contract"
            case delayApplied = "delay_applied"
            case newTotalActions = "new_total_actions"
            case currentProgress = "current_progress"
        }
    }
    
    struct Costs: Codable {
        let goldPaid: Int
        
        enum CodingKeys: String, CodingKey {
            case goldPaid = "gold_paid"
        }
    }
    
    struct Rewards: Codable {
        let gold: Int
        let reputation: Int
        let netGold: Int
        
        enum CodingKeys: String, CodingKey {
            case gold, reputation
            case netGold = "net_gold"
        }
    }
    
    struct Statistics: Codable {
        let totalSabotages: Int
        
        enum CodingKeys: String, CodingKey {
            case totalSabotages = "total_sabotages"
        }
    }
    
    let success: Bool
    let message: String
    let sabotage: SabotageDetails
    let costs: Costs
    let rewards: Rewards
    let nextSabotageAvailableAt: Date
    let statistics: Statistics
    
    enum CodingKeys: String, CodingKey {
        case success, message, sabotage, costs, rewards, statistics
        case nextSabotageAvailableAt = "next_sabotage_available_at"
    }
}

// MARK: - Actions API

class ActionsAPI {
    private let client = APIClient.shared
    
    // MARK: - Get Action Status
    
    func getActionStatus() async throws -> AllActionStatus {
        let request = client.request(endpoint: "/actions/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Work on Contract
    
    func workOnContract(contractId: Int) async throws -> WorkActionResponse {
        let request = client.request(endpoint: "/actions/work/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Start Patrol
    
    func startPatrol() async throws -> PatrolActionResponse {
        let request = client.request(endpoint: "/actions/patrol", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Scout Kingdom
    
    func scoutKingdom(kingdomId: String) async throws -> ScoutActionResponse {
        let request = client.request(endpoint: "/actions/scout/\(kingdomId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Training Costs
    
    func getTrainingCosts() async throws -> TrainingCostsResponse {
        let request = client.request(endpoint: "/actions/train/costs", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Purchase Training
    
    func purchaseTraining(type: String) async throws -> PurchaseTrainingResponse {
        let request = client.request(endpoint: "/actions/train/purchase?training_type=\(type)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Work on Training
    
    func workOnTraining(contractId: String) async throws -> TrainingActionResponse {
        let request = client.request(endpoint: "/actions/train/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Crafting
    
    func getCraftingCosts() async throws -> CraftingCosts {
        struct Response: Codable {
            let costs: CraftingCosts
        }
        let request = client.request(endpoint: "/actions/craft/costs", method: "GET")
        let response: Response = try await client.execute(request)
        return response.costs
    }
    
    func purchaseCraft(equipmentType: String, tier: Int) async throws -> PurchaseCraftResponse {
        let request = client.request(
            endpoint: "/actions/craft/purchase?equipment_type=\(equipmentType)&tier=\(tier)",
            method: "POST"
        )
        return try await client.execute(request)
    }
    
    func workOnCraft(contractId: String) async throws -> CraftingActionResponse {
        let request = client.request(endpoint: "/actions/craft/\(contractId)", method: "POST")
        let response: CraftingActionResponse = try await client.execute(request)
        return response
    }
    
    func equipItem(equipmentId: String) async throws -> EquipResponse {
        let request = client.request(endpoint: "/actions/equip/\(equipmentId)", method: "POST")
        let response: EquipResponse = try await client.execute(request)
        return response
    }
    
    func unequipItem(equipmentType: String) async throws -> EquipResponse {
        let request = client.request(endpoint: "/actions/unequip/\(equipmentType)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Sabotage
    
    func getSabotageTargets() async throws -> SabotageTargetsResponse {
        let request = client.request(endpoint: "/actions/sabotage/targets", method: "GET")
        return try await client.execute(request)
    }
    
    func sabotageContract(contractId: Int) async throws -> SabotageActionResponse {
        let request = client.request(endpoint: "/actions/sabotage/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Property Upgrade
    
    func workOnPropertyUpgrade(contractId: String) async throws -> PropertyUpgradeActionResponse {
        let request = client.request(endpoint: "/actions/work-property/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Coups
    
    func joinCoup(coupId: Int, side: String) async throws -> CoupJoinResponse {
        struct JoinRequest: Codable {
            let side: String
        }
        
        let body = JoinRequest(side: side)
        let request = try client.request(endpoint: "/coups/\(coupId)/join", method: "POST", body: body)
        return try await client.execute(request)
    }
}

// MARK: - Coup Response Models

struct CoupJoinResponse: Codable {
    let success: Bool
    let message: String
    let side: String
    let attackerCount: Int
    let defenderCount: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, side
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
    }
}

