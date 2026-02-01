import Foundation

// MARK: - Startup Response (Combined endpoint)

/// Combined response from /game/startup - replaces separate calls to:
/// - /cities/current
/// - /player/state?kingdom_id=X
/// - /auth/me (last_login update)
struct StartupResponse: Codable {
    let city: CityBoundaryResponse
    let player: APIPlayerState
    let server_time: String
}

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
    let id: Int
    let display_name: String
    let email: String?
    let avatar_url: String?
    
    // Territory
    let hometown_kingdom_id: String?
    let hometown_kingdom_name: String?
    let current_kingdom_id: String?
    let current_kingdom_name: String?
    let travel_event: TravelEvent?
    
    // Progression
    let gold: Int
    let food: Int?  // Total food (meat + berries + other is_food resources)
    let level: Int
    let experience: Int
    let skill_points: Int
    
    // Stats
    let attack_power: Int
    let defense_power: Int
    let leadership: Int
    let building_skill: Int
    let intelligence: Int
    let science: Int
    let faith: Int
    
    // Combat
    let attack_debuff: Int
    let debuff_expires_at: String?
    
    // Reputation
    let reputation: Int
    
    // Activity
    let total_checkins: Int
    let total_conquests: Int
    let kingdoms_ruled: Int
    let coups_won: Int
    let coups_failed: Int
    let times_executed: Int
    let executions_ordered: Int
    let contracts_completed: Int
    let total_work_contributed: Int
    let total_training_purchases: Int
    
    // Flags
    let has_claimed_starting_city: Bool
    let is_alive: Bool
    let is_ruler: Bool
    let is_verified: Bool
    
    // Legacy resources
    let iron: Int
    let steel: Int
    let wood: Int
    
    // Equipment
    let equipped_weapon: APIEquipmentItem?
    let equipped_armor: APIEquipmentItem?
    
    // Properties
    let properties: [APIPropertyItem]?
    
    // Timestamps
    let created_at: String?
    let updated_at: String?
    let last_login: String?
    
    // Dynamic data
    let training_costs: TrainingCostsFromAPI?
    let active_perks: ActivePerks?
    let skills_data: [SkillData]?
    let resources_data: [ResourceData]?
    let inventory: [InventoryItem]?
    let pets: [PetData]?
    
    struct TrainingCostsFromAPI: Codable {
        let attack: Int
        let defense: Int
        let leadership: Int
        let building: Int
        let intelligence: Int
        let science: Int
        let faith: Int
        let philosophy: Int?
        let merchant: Int?
    }
    
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
    
    struct ResourceData: Codable, Identifiable {
        let key: String
        let amount: Int
        let display_name: String
        let icon: String
        let color: String
        let category: String
        let display_order: Int
        let description: String?
        
        var id: String { key }
    }
    
    struct InventoryItem: Codable, Identifiable {
        let item_id: String
        let quantity: Int
        
        var id: String { item_id }
    }
    
    struct PetData: Codable, Identifiable {
        let id: String  // e.g., "pet_fish"
        let quantity: Int
        let display_name: String
        let icon: String
        let color: String
        let description: String
        let source: String?
    }
    
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

