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
    
    // Ruled kingdom (first one if multiple)
    let ruled_kingdom_id: String?
    let ruled_kingdom_name: String?
    
    // Stats
    let level: Int
    let reputation: Int
    
    // Dynamic skills data - renders without hardcoding!
    let skills_data: [SkillData]
    
    // Equipment
    let equipment: PlayerEquipmentData
    
    // Skill data structure (matches backend)
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
    
    // Pets
    let pets: [PetData]?
    
    // Claimed achievements grouped by category
    let achievement_groups: [AchievementGroup]?
    
    // Subscriber customization (server-driven)
    let is_subscriber: Bool?
    let subscriber_customization: APISubscriberCustomization?
    
    // Achievement stats
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
    
    // Helper to get skill value by type
    func skillTier(for skillType: String) -> Int {
        skills_data.first { $0.skill_type == skillType }?.current_tier ?? 0
    }
    
    var totalCombatPower: Int {
        skillTier(for: "attack") + skillTier(for: "defense") + (equipment.weapon_attack_bonus ?? 0) + (equipment.armor_defense_bonus ?? 0)
    }
    
    /// Check if this user is a subscriber
    var isSubscriber: Bool {
        is_subscriber ?? false
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


// MARK: - Pet Data

struct PetData: Codable, Identifiable {
    let id: String  // e.g., "pet_fish"
    let quantity: Int
    let display_name: String
    let icon: String
    let color: String
    let description: String
    let source: String?
}

// MARK: - Player Achievement (for profile display)

struct PlayerAchievement: Codable, Identifiable {
    let id: Int  // achievement_definitions.id
    let achievement_type: String
    let tier: Int
    let display_name: String
    let icon: String?
    let category: String
    let color: String  // Theme color name from backend
    let claimed_at: String?
}

// MARK: - Achievement Group (grouped by category)

struct AchievementGroup: Codable, Identifiable {
    let category: String
    let display_name: String
    let icon: String
    let achievements: [PlayerAchievement]
    
    var id: String { category }
}


