import Foundation

// MARK: - Foraging Models
// Two-round system: Round 1 (berries) + Bonus Round 2 (seeds)
// Everything pre-calculated by backend, frontend just reveals + animates

// MARK: - Bush Cell (from backend)

struct ForagingBushCell: Codable, Identifiable {
    let position: Int
    let bush_type: String
    let icon: String
    let color: String
    let name: String
    let is_seed: Bool  // Is this the target for the current round?
    let is_seed_trail: Bool?  // Special cell that triggers bonus round
    let label: String?  // Label to show on the tile (e.g. "BONUS", "Rare Egg")
    
    var id: Int { position }
    
    var isSeedTrail: Bool { is_seed_trail ?? false }
}

// MARK: - Reward Config

struct ForagingRewardConfig: Codable {
    let item: String
    let display_name: String
    let icon: String
    let color: String
}

// MARK: - Round Data (single round)

// Single reward item in rewards array
struct ForagingReward: Codable {
    let item: String
    let display_name: String
    let icon: String
    let color: String
    let amount: Int
}

struct ForagingRoundData: Codable {
    let round_num: Int
    let grid: [ForagingBushCell]
    let max_reveals: Int
    let matches_to_win: Int
    let is_winner: Bool
    let winning_positions: [Int]
    let rewards: [ForagingReward]?   // All rewards for this round - generic!
    let has_seed_trail: Bool?        // Only Round 1: did we find a trail?
    let seed_trail_position: Int?    // Where in the grid array
    // Legacy fields
    let reward_amount: Int
    let reward_config: ForagingRewardConfig
    let hidden_icon: String
    let hidden_color: String
    
    var hasSeedTrail: Bool { has_seed_trail ?? false }
    var seedTrailPosition: Int { seed_trail_position ?? -1 }
}

// MARK: - Session (pre-calculated, both rounds!)

struct ForagingSession: Codable {
    let session_id: String
    let has_bonus_round: Bool        // Quick check: do we have Round 2?
    
    // Round data
    let round1: ForagingRoundData
    let round2: ForagingRoundData?   // Only present if seed trail found!
    
    // Legacy fields (for backwards compatibility)
    let grid: [ForagingBushCell]
    let max_reveals: Int
    let matches_to_win: Int
    let is_winner: Bool
    let winning_positions: [Int]
    let reward_amount: Int
    let reward_config: ForagingRewardConfig
    let hidden_icon: String
    let hidden_color: String
}

// MARK: - Bush Type Display (for legend)

struct ForagingBushTypeDisplay: Codable {
    let key: String
    let name: String
    let icon: String
    let color: String
}

// MARK: - Config

struct ForagingConfig: Codable {
    let grid_size: Int
    let max_reveals: Int
    let matches_to_win: Int
    let bush_types: [ForagingBushTypeDisplay]
    let hidden_icon: String
    let hidden_color: String
    let bonus_hidden_icon: String?
    let bonus_hidden_color: String?
}

// MARK: - Collected Reward (single item)

struct ForagingCollectedReward: Codable {
    let round: Int
    let item: String
    let amount: Int
    let display_name: String
}

// MARK: - API Responses

struct ForagingStartResponse: Codable {
    let success: Bool
    let session: ForagingSession
}

struct ForagingCollectResponse: Codable {
    let success: Bool
    let is_winner: Bool
    let rewards: [ForagingCollectedReward]?  // All rewards from both rounds
    // Legacy fields
    let reward_item: String?
    let reward_amount: Int
}

struct ForagingEndResponse: Codable {
    let success: Bool
}
