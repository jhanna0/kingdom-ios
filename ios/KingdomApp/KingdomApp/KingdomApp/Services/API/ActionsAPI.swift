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

struct AllActionStatus: Codable {
    let work: ActionStatus
    let patrol: ActionStatus
    let sabotage: ActionStatus
    let mine: ActionStatus
    let scout: ActionStatus
    let trainAttack: ActionStatus
    let trainDefense: ActionStatus
    let trainLeadership: ActionStatus
    let trainBuilding: ActionStatus
    let contracts: [APIContract]
    
    enum CodingKeys: String, CodingKey {
        case work, patrol, sabotage, mine, scout, contracts
        case trainAttack = "train_attack"
        case trainDefense = "train_defense"
        case trainLeadership = "train_leadership"
        case trainBuilding = "train_building"
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

struct MineActionResponse: Codable {
    let success: Bool
    let message: String
    let nextMineAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case nextMineAvailableAt = "next_mine_available_at"
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
    let statType: String
    let newValue: Int
    let sessionsRemaining: Int
    let nextTrainAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case statType = "stat_type"
        case newValue = "new_value"
        case sessionsRemaining = "sessions_remaining"
        case nextTrainAvailableAt = "next_train_available_at"
    }
}

struct PurchaseTrainingResponse: Codable {
    let success: Bool
    let message: String
    let trainingType: String
    let cost: Int
    let sessionsAvailable: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, cost
        case trainingType = "training_type"
        case sessionsAvailable = "sessions_available"
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
    
    // MARK: - Mine Resources
    
    func mineResources() async throws -> MineActionResponse {
        let request = client.request(endpoint: "/actions/mine", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Scout Kingdom
    
    func scoutKingdom(kingdomId: String) async throws -> ScoutActionResponse {
        let request = client.request(endpoint: "/actions/scout/\(kingdomId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Purchase Training
    
    func purchaseAttackTraining() async throws -> PurchaseTrainingResponse {
        let request = client.request(endpoint: "/actions/train/attack/purchase", method: "POST")
        return try await client.execute(request)
    }
    
    func purchaseDefenseTraining() async throws -> PurchaseTrainingResponse {
        let request = client.request(endpoint: "/actions/train/defense/purchase", method: "POST")
        return try await client.execute(request)
    }
    
    func purchaseLeadershipTraining() async throws -> PurchaseTrainingResponse {
        let request = client.request(endpoint: "/actions/train/leadership/purchase", method: "POST")
        return try await client.execute(request)
    }
    
    func purchaseBuildingTraining() async throws -> PurchaseTrainingResponse {
        let request = client.request(endpoint: "/actions/train/building/purchase", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Training Actions
    
    func trainAttack() async throws -> TrainingActionResponse {
        let request = client.request(endpoint: "/actions/train/attack", method: "POST")
        return try await client.execute(request)
    }
    
    func trainDefense() async throws -> TrainingActionResponse {
        let request = client.request(endpoint: "/actions/train/defense", method: "POST")
        return try await client.execute(request)
    }
    
    func trainLeadership() async throws -> TrainingActionResponse {
        let request = client.request(endpoint: "/actions/train/leadership", method: "POST")
        return try await client.execute(request)
    }
    
    func trainBuilding() async throws -> TrainingActionResponse {
        let request = client.request(endpoint: "/actions/train/building", method: "POST")
        return try await client.execute(request)
    }
}

