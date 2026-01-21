import Foundation

// MARK: - Science Minigame Models
// High/Low guessing game - test your scientific intuition!
// Backend PRE-CALCULATES all numbers. Frontend is DUMB - just displays and sends guesses.

// MARK: - Round Data (from backend)

struct ScienceRound: Codable, Identifiable {
    let round_num: Int
    let shown_number: Int
    let is_revealed: Bool
    let hidden_number: Int?    // Only present after round is played
    let guess: String?         // "high" or "low"
    let is_correct: Bool?
    
    var id: Int { round_num }
}

// MARK: - Reward

struct ScienceReward: Codable {
    let item: String
    let amount: Int
    let display_name: String
    let icon: String
    let color: String
}

// MARK: - Potential Rewards (what you'd get if you collect now)

struct SciencePotentialRewards: Codable {
    let gold: Int
    let blueprint: Int
    let rewards: [ScienceReward]
    let message: String?
}

// MARK: - Session

struct ScienceSession: Codable {
    let session_id: String
    let current_number: Int
    let current_round: Int
    let streak: Int
    let max_streak: Int
    let is_game_over: Bool
    let can_guess: Bool
    let can_collect: Bool
    let has_won_max: Bool
    let potential_rewards: SciencePotentialRewards
    let rounds: [ScienceRound]
    let min_number: Int
    let max_number: Int
}

// MARK: - Stats

struct SciencePlayerStats: Codable {
    let experiments_completed: Int
    let total_guesses: Int
    let correct_guesses: Int
    let accuracy: Double
    let best_streak: Int
    let perfect_games: Int
    let total_gold_earned: Int
    let total_blueprints_earned: Int
}

// MARK: - Skill Info

struct ScienceSkillInfo: Codable {
    let skill: String
    let level: Int
}

// MARK: - Config (UI strings from backend)

struct ScienceSkillConfig: Codable {
    let skill: String
    let display_name: String
    let icon: String
}

struct ScienceUIStrings: Codable {
    let title: String
    let subtitle: String
    let instruction: String
    let streak_label: String
    let high_button: String
    let low_button: String
    let correct: String
    let wrong: String
    let collect_prompt: String
    let final_win: String
}

struct ScienceThemeConfig: Codable {
    let background_color: String
    let card_color: String
    let accent_color: String
    let number_color: String
    let streak_colors: [String: String]
}

// MARK: - Streak Rewards (per streak tier)

struct ScienceStreakReward: Codable, Identifiable {
    let streak: Int
    let gold: Int
    let blueprint: Int
    let message: String?
    
    var id: Int { streak }
}

struct ScienceConfig: Codable {
    let skill: ScienceSkillConfig
    let ui: ScienceUIStrings
    let theme: ScienceThemeConfig
    let min_level: Int
    let entry_cost: Int
    let max_guesses: Int?
    let streak_rewards: [ScienceStreakReward]?
}

// MARK: - API Responses

struct ScienceStartResponse: Codable {
    let success: Bool
    let session: ScienceSession
    let skill_info: ScienceSkillInfo?
    let cost: Int?
}

struct ScienceGuessResponse: Codable {
    let success: Bool
    let is_correct: Bool
    let guess: String
    let shown_number: Int
    let hidden_number: Int
    let correct_answer: String
    let streak: Int
    let current_round: Int
    let is_game_over: Bool
    let has_won_max: Bool
    let potential_rewards: SciencePotentialRewards
    let next_number: Int?
    let round: ScienceRound
    let session: ScienceSession
}

struct ScienceCollectResponse: Codable {
    let success: Bool
    let streak: Int
    let rewards: [ScienceReward]
    let gold: Int
    let blueprint: Int
    let message: String?
    let stats: SciencePlayerStats?
}

struct ScienceEndResponse: Codable {
    let success: Bool
}
