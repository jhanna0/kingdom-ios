import Foundation

// MARK: - Player Activity

struct PlayerActivity: Codable, Equatable {
    let type: String  // "idle", "working", "patrolling", "training", "crafting", "scouting"
    let details: String?
    let expires_at: String?  // ISO8601 datetime
    
    var displayText: String {
        details ?? type.capitalized
    }
    
    var icon: String {
        switch type {
        case "working":
            return "hammer.fill"
        case "patrolling":
            return "figure.walk"
        case "training":
            return "figure.strengthtraining.traditional"
        case "crafting":
            return "hammer.circle.fill"
        case "scouting":
            return "eye.fill"
        case "sabotage":
            return "exclamationmark.triangle.fill"
        default:
            return "circle"
        }
    }
    
    var color: String {
        switch type {
        case "working":
            return "blue"
        case "patrolling":
            return "green"
        case "training":
            return "purple"
        case "crafting":
            return "orange"
        case "scouting":
            return "yellow"
        case "sabotage":
            return "red"
        default:
            return "gray"
        }
    }
}

// MARK: - Player Equipment

struct PlayerEquipmentData: Codable, Equatable {
    let weapon_tier: Int?
    let weapon_attack_bonus: Int?
    let armor_tier: Int?
    let armor_defense_bonus: Int?
}

// MARK: - Player Public Profile

struct PlayerPublicProfile: Codable, Identifiable {
    // Identity
    let id: Int
    let display_name: String
    let avatar_url: String?
    
    // Location
    let current_kingdom_id: String?
    let current_kingdom_name: String?
    let hometown_kingdom_id: String?
    
    // Stats
    let level: Int
    let reputation: Int
    let honor: Int
    
    // Combat stats
    let attack_power: Int
    let defense_power: Int
    let leadership: Int
    let building_skill: Int
    let intelligence: Int
    
    // Equipment
    let equipment: PlayerEquipmentData
    
    // Achievements
    let total_checkins: Int
    let total_conquests: Int
    let kingdoms_ruled: Int
    let coups_won: Int
    let contracts_completed: Int
    
    // Current activity
    let activity: PlayerActivity
    
    // Timestamps
    let last_login: String?
    let created_at: String
    
    var totalCombatPower: Int {
        attack_power + defense_power + (equipment.weapon_attack_bonus ?? 0) + (equipment.armor_defense_bonus ?? 0)
    }
}

// MARK: - Player In Kingdom

struct PlayerInKingdom: Codable, Identifiable {
    let id: Int
    let display_name: String
    let avatar_url: String?
    let level: Int
    let reputation: Int
    let attack_power: Int
    let defense_power: Int
    let leadership: Int
    let activity: PlayerActivity
    let is_ruler: Bool
    let is_online: Bool
    
    var statusIcon: String {
        if is_online {
            return "circle.fill"
        } else {
            return "circle"
        }
    }
    
    var statusColor: String {
        is_online ? "green" : "gray"
    }
}

// MARK: - API Responses

struct PlayersInKingdomResponse: Codable {
    let kingdom_id: String
    let kingdom_name: String
    let total_players: Int
    let online_count: Int
    let players: [PlayerInKingdom]
}

struct ActivePlayersResponse: Codable {
    let total: Int
    let players: [PlayerInKingdom]
}

