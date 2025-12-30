import Foundation

// MARK: - Kingdom Intelligence

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

// MARK: - Scout Action Response

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

