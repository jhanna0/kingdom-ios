import Foundation

// MARK: - Foraging Models
// Everything pre-calculated by backend, frontend just reveals locally

// MARK: - Bush Cell (from backend)

struct ForagingBushCell: Codable, Identifiable {
    let position: Int
    let bush_type: String
    let icon: String
    let color: String
    let name: String
    let is_seed: Bool
    
    var id: Int { position }
}

// MARK: - Reward Config

struct ForagingRewardConfig: Codable {
    let item: String
    let display_name: String
    let icon: String
    let color: String
}

// MARK: - Session (pre-calculated)

struct ForagingSession: Codable {
    let session_id: String
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
}

// MARK: - API Responses

struct ForagingStartResponse: Codable {
    let success: Bool
    let session: ForagingSession
}

struct ForagingCollectResponse: Codable {
    let success: Bool
    let is_winner: Bool
    let reward_item: String?
    let reward_amount: Int
}

struct ForagingEndResponse: Codable {
    let success: Bool
}
