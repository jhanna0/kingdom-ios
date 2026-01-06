import Foundation

// MARK: - Travel Event

struct TravelEvent: Codable, Equatable {
    let entered_kingdom: Bool
    let kingdom_name: String
    let travel_fee_paid: Int
    let free_travel_reason: String?
    let denied: Bool?
    let denial_reason: String?
}

// MARK: - Player State Models

/// Complete player state from API
struct APIPlayerState: Codable {
    // Identity
    let id: Int  // User ID from database (auto-increment integer)
    let display_name: String
    let email: String?
    let avatar_url: String?
    
    // Kingdom & Territory
    let hometown_kingdom_id: String?  // Player's hometown (used for royal blue territory color)
    let origin_kingdom_id: String?    // DEPRECATED - no longer returned by API
    let home_kingdom_id: String?      // DEPRECATED - no longer returned by API (use hometown_kingdom_id)
    let current_kingdom_id: String?   // Where the player currently is (ID)
    let current_kingdom_name: String? // Where the player currently is (name)
    let fiefs_ruled: [String]?
    let travel_event: TravelEvent?
    
    // Core Stats
    let gold: Int
    let level: Int
    let experience: Int
    let skill_points: Int
    
    // Combat Stats
    let attack_power: Int
    let defense_power: Int
    let leadership: Int
    let building_skill: Int
    let intelligence: Int
    let science: Int
    let faith: Int
    
    // Debuffs
    let attack_debuff: Int
    let debuff_expires_at: String?
    
    // Reputation
    let reputation: Int
    let honor: Int
    let kingdom_reputation: [String: Int]?
    
    // Check-in tracking
    let check_in_history: [String: Int]?
    let last_check_in: String?
    let last_daily_check_in: String?
    
    // Activity tracking
    let total_checkins: Int
    let total_conquests: Int
    let kingdoms_ruled: Int
    let coups_won: Int
    let coups_failed: Int
    let times_executed: Int
    let executions_ordered: Int
    let last_coup_attempt: String?
    
    // Contract & Work
    let contracts_completed: Int
    let total_work_contributed: Int
    let total_training_purchases: Int
    
    // Training costs (calculated by backend)
    let training_costs: TrainingCostsFromAPI?
    
    struct TrainingCostsFromAPI: Codable {
        let attack: Int
        let defense: Int
        let leadership: Int
        let building: Int
        let intelligence: Int
        let science: Int
        let faith: Int
    }
    
    // Active perks (calculated by backend)
    let active_perks: ActivePerks?
    
    struct ActivePerks: Codable {
        let combat: [PerkEntry]
        let training: [PerkEntry]
        let building: [PerkEntry]
        let espionage: [PerkEntry]
        let political: [PerkEntry]
        let travel: [PerkEntry]
        let total_power: Int
    }
    
    struct PerkEntry: Codable {
        let stat: String?
        let bonus: Int?
        let description: String?
        let source: String
        let source_type: String
        let expires_at: String?
    }
    
    // DYNAMIC SKILLS DATA - Frontend can render skills without hardcoding!
    let skills_data: [SkillData]?
    
    struct SkillData: Codable, Identifiable {
        let skill_type: String
        let display_name: String
        let icon: String
        let category: String
        let description: String
        let current_tier: Int
        let max_tier: Int
        let training_cost: Int
        let current_benefits: [String]
        let display_order: Int
        
        var id: String { skill_type }
    }
    
    // Resources
    let iron: Int
    let steel: Int
    let wood: Int
    
    // Daily Actions
    let last_mining_action: String?
    let last_crafting_action: String?
    let last_building_action: String?
    let last_spy_action: String?
    
    // Equipment
    let equipped_weapon: APIEquipmentItem?
    let equipped_armor: APIEquipmentItem?
    let equipped_shield: APIEquipmentItem?
    let inventory: [APIEquipmentItem]?
    let crafting_queue: [APIEquipmentItem]?
    let crafting_progress: [String: Int]?
    
    // Properties
    let properties: [APIPropertyItem]?
    
    // Rewards
    let total_rewards_received: Int
    let last_reward_received: String?
    let last_reward_amount: Int
    
    // Status
    let is_alive: Bool
    let is_ruler: Bool
    let is_verified: Bool
    
    // Timestamps
    let created_at: String?
    let updated_at: String?
    let last_login: String?
}

struct APIEquipmentItem: Codable {
    let id: String
    let type: String
    let tier: Int
    let attack_bonus: Int?
    let defense_bonus: Int?
    let crafted_at: String?
    let craft_start_time: String?
    let craft_duration: Double?
}

struct APIPropertyItem: Codable {
    let id: String
    let type: String
    let kingdom_id: String
    let kingdom_name: String
    let owner_id: String
    let owner_name: String
    let tier: Int
    let purchased_at: String?
    let last_upgraded: String?
    let last_income_collection: String?
}

// MARK: - Request/Response Models

struct PlayerStateResponse: Codable {
    let player_state: APIPlayerState
    let location_info: LocationInfo?
}

struct LocationInfo: Codable {
    let in_kingdom: Bool
    let current_kingdom: LocationKingdomInfo?
    let is_home_kingdom: Bool
    let available_actions: [String]
    let check_in_result: CheckInResult?
}

struct PlayerSyncRequest: Codable {
    let player_state: [String: AnyCodable]
    let last_sync_time: String?
}

struct PlayerSyncResponse: Codable {
    let success: Bool
    let message: String
    let player_state: APIPlayerState
    let server_time: String
}

struct GoldResponse: Codable {
    let success: Bool
    let new_gold: Int
}

struct ExperienceResponse: Codable {
    let success: Bool
    let new_level: Int
    let new_experience: Int
    let levels_gained: Int
    let skill_points: Int
}

struct ReputationResponse: Codable {
    let success: Bool
    let new_reputation: Int
    let kingdom_reputation: Int?
}

struct TrainResponse: Codable {
    let success: Bool
    let stat: String
    let new_level: Int
    let cost: Int
    let remaining_gold: Int
}

struct SkillPointResponse: Codable {
    let success: Bool
    let stat: String
    let new_level: Int
    let remaining_skill_points: Int
}

struct LocationKingdomInfo: Codable {
    let id: String
    let name: String
    let ruler_id: Int?
    let ruler_name: String?
    let level: Int
    let population: Int
    let wall_level: Int
    let vault_level: Int
    let mine_level: Int
    let market_level: Int
}

struct CheckInResult: Codable {
    let checked_in: Bool
    let message: String
    let rewards: CheckInRewards
    let levels_gained: Int?
}

struct CheckInRewards: Codable {
    let gold: Int
    let experience: Int
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

