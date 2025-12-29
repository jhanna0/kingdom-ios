import Foundation

// MARK: - Action Status Models

struct ActionStatus: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let cooldownMinutes: Double
    let isPatrolling: Bool?
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case cooldownMinutes = "cooldown_minutes"
        case isPatrolling = "is_patrolling"
    }
}

struct AllActionStatus: Codable {
    let work: ActionStatus
    let patrol: ActionStatus
    let sabotage: ActionStatus
    let mine: ActionStatus
    let scout: ActionStatus
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
    
    enum CodingKeys: String, CodingKey {
        case success, message
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
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case expiresAt = "expires_at"
    }
}

struct MineActionResponse: Codable {
    let success: Bool
    let message: String
    let ironGained: Int
    let totalIron: Int
    let nextMineAvailableAt: Date
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case ironGained = "iron_gained"
        case totalIron = "total_iron"
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
    
    enum CodingKeys: String, CodingKey {
        case success, message, intelligence
        case nextScoutAvailableAt = "next_scout_available_at"
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
    
    func workOnContract(contractId: String) async throws -> WorkActionResponse {
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
}

