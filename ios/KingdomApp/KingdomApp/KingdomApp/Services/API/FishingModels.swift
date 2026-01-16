import Foundation

// MARK: - Fishing Models
// Models for the chill fishing minigame

// MARK: - Enums

enum FishingPhase: String, Codable {
    case idle = "idle"
    case casting = "casting"
    case reeling = "reeling"
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .casting: return "Casting"
        case .reeling: return "Reeling"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "figure.fishing"
        case .casting: return "water.waves"
        case .reeling: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Roll Result

struct FishingRollResult: Codable, Identifiable {
    let round: Int
    let roll: Int
    let is_success: Bool
    let is_critical: Bool
    let message: String
    let slots_after: [String: Int]?  // Slot state AFTER this roll (for animating shifts)
    
    var id: Int { round }
}

// MARK: - Drop Table Display

struct FishingDropTableItem: Codable {
    let key: String
    let icon: String
    let name: String
    let color: String  // Theme color name (e.g., "royalBlue", "buttonSuccess")
}

// MARK: - Fish Data

struct FishData: Codable {
    let name: String?
    let tier: Int?
    let icon: String?
    let meat_min: Int?
    let meat_max: Int?
    let description: String?
}

// MARK: - Outcome Display

struct FishingOutcomeDisplay: Codable {
    let key: String
    let name: String
    let icon: String
    let color: String
    let fish_data: FishData?
    let meat_earned: Int?
    let pet_fish_dropped: Bool?
}

// MARK: - Phase Result (Pre-calculated rolls)

struct FishingPhaseResult: Codable {
    let phase: String
    let rolls: [FishingRollResult]
    let base_slots: [String: Int]?   // Starting slots BEFORE any rolls
    let final_slots: [String: Int]
    let final_probabilities: [String: Double]
    let master_roll: Int
    let outcome: String
    let outcome_display: FishingOutcomeDisplay
    let animation_delay_ms: Int
    
    var fishingPhase: FishingPhase {
        FishingPhase(rawValue: phase) ?? .idle
    }
}

// MARK: - Session Stats

struct FishingSessionStats: Codable {
    let casts_attempted: Int
    let successful_catches: Int
    let fish_escaped: Int
}

// MARK: - Session

struct FishingSession: Codable {
    let session_id: String
    let total_meat: Int
    let fish_caught: Int
    let pet_fish_dropped: Bool
    let current_fish: String?
    let current_fish_data: FishData?
    let stats: FishingSessionStats?
}

// MARK: - Config

struct FishingPhaseConfig: Codable {
    let name: String
    let display_name: String
    let stat: String
    let stat_display_name: String
    let icon: String
    let description: String
    let success_effect: String
    let failure_effect: String
    let critical_effect: String
    let stat_icon: String
    let roll_button_label: String
    let roll_button_icon: String
    let phase_color: String
    let drop_table_title: String
    let min_rolls: Int
    let drop_table: [String: Int]?
    let drop_table_display: [FishingDropTableItem]?
}

struct FishingConfig: Codable {
    let fish: [String: FishData]
    let phases: [String: FishingPhaseConfig]
    let roll_hit_chance: Int
    let animation_delay_ms: Int
}

// MARK: - Player Stats (fishing-relevant)

struct FishingPlayerStats: Codable {
    let building: Int
    let defense: Int
}

struct FishingSessionConfig: Codable {
    let cast_rolls: Int
    let reel_rolls: Int
    let hit_chance: Int
}

// MARK: - API Responses

struct FishingStartResponse: Codable {
    let success: Bool
    let message: String
    let session: FishingSession
    let player_stats: FishingPlayerStats
    let config: FishingSessionConfig
}

struct FishingCastResponse: Codable {
    let success: Bool
    let result: FishingPhaseResult
    let session: FishingSession
}

struct FishingReelResponse: Codable {
    let success: Bool
    let result: FishingPhaseResult
    let session: FishingSession
}

struct FishingEndRewards: Codable {
    let total_meat: Int
    let fish_caught: Int
    let pet_fish_dropped: Bool
    let stats: FishingEndStats?
}

struct FishingEndStats: Codable {
    let casts_attempted: Int
    let successful_catches: Int
    let fish_escaped: Int
    let catch_rate: Double
}

struct FishingEndResponse: Codable {
    let success: Bool
    let message: String
    let rewards: FishingEndRewards
}

struct FishingStatusResponse: Codable {
    let has_session: Bool
    let session: FishingSession?
    let player_stats: FishingPlayerStats?
    let config: FishingSessionConfig?
}
