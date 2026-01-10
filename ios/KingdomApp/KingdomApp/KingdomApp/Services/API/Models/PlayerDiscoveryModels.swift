import Foundation
import SwiftUI

// MARK: - Player Activity

struct PlayerActivity: Codable, Equatable {
    let type: String  // "idle", "working", "patrolling", "training", "crafting", "scouting"
    let details: String?
    let expires_at: String?  // ISO8601 datetime
    
    // Structured data for specific activity types
    let training_type: String?  // "attack", "defense", "leadership", etc.
    let equipment_type: String?  // "weapon", "armor"
    let tier: Int?
    
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
            // Use SkillConfig for training
            if let trainingType = training_type {
                return SkillConfig.get(trainingType).icon
            }
            return "figure.strengthtraining.traditional"
        case "crafting":
            // Use equipment-specific icons
            if let equipmentType = equipment_type {
                return equipmentType == "weapon" ? "bolt.fill" : "shield.fill"
            }
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
            return "purple"  // Default fallback
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
    
    // Return the actual SwiftUI Color (like ActivityLogEntry does)
    var actualColor: Color {
        switch type {
        case "working":
            return KingdomTheme.Colors.imperialGold
        case "patrolling":
            return KingdomTheme.Colors.buttonSuccess
        case "training":
            // Use SkillConfig colors directly!
            if let trainingType = training_type {
                return SkillConfig.get(trainingType).color
            }
            return KingdomTheme.Colors.buttonSpecial
        case "crafting":
            // Use equipment colors
            if let equipmentType = equipment_type {
                return equipmentType == "weapon" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
            }
            return KingdomTheme.Colors.buttonWarning
        case "scouting":
            return KingdomTheme.Colors.buttonWarning
        case "sabotage":
            return KingdomTheme.Colors.buttonDanger
        default:
            return KingdomTheme.Colors.inkMedium
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
    
    // Combat stats
    let attack_power: Int
    let defense_power: Int
    let leadership: Int
    let building_skill: Int
    let intelligence: Int
    let science: Int
    let faith: Int
    
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



