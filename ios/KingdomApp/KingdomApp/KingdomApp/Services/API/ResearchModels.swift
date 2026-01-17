import Foundation

// MARK: - Config

struct ResearchConfig: Codable {
    let goldCost: Int
    let phase1Fill: FillConfig
    let phase2Cooking: CookingConfig
    
    enum CodingKeys: String, CodingKey {
        case goldCost = "gold_cost"
        case phase1Fill = "phase1_fill"
        case phase2Cooking = "phase2_cooking"
    }
}

struct FillConfig: Codable {
    let stat: String
    let statDisplayName: String
    let baseRolls: Int
    let rollsPerStat: Int
    let hitThreshold: Int
    let hitFillAmount: Double
    let missFillAmount: Double
    let miniBarNames: [String]
    
    enum CodingKeys: String, CodingKey {
        case stat
        case statDisplayName = "stat_display_name"
        case baseRolls = "base_rolls"
        case rollsPerStat = "rolls_per_stat"
        case hitThreshold = "hit_threshold"
        case hitFillAmount = "hit_fill_amount"
        case missFillAmount = "miss_fill_amount"
        case miniBarNames = "mini_bar_names"
    }
}

struct CookingConfig: Codable {
    let stat: String
    let statDisplayName: String
    let baseAttempts: Int
    let attemptsPerStat: Int
    let rewardTiers: [RewardTier]
    
    enum CodingKeys: String, CodingKey {
        case stat
        case statDisplayName = "stat_display_name"
        case baseAttempts = "base_attempts"
        case attemptsPerStat = "attempts_per_stat"
        case rewardTiers = "reward_tiers"
    }
}

struct RewardTier: Codable, Identifiable {
    let id: String
    let minPercent: Int
    let maxPercent: Int
    let label: String
    let description: String
    let blueprints: Int
    let gpMin: Int
    let gpMax: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case minPercent = "min_percent"
        case maxPercent = "max_percent"
        case label, description, blueprints
        case gpMin = "gp_min"
        case gpMax = "gp_max"
    }
}

// MARK: - Experiment Response

struct ExperimentResponse: Codable {
    let experiment: ExperimentResult
    let playerStats: PlayerResearchStats
    let config: AnimationConfig
    
    enum CodingKeys: String, CodingKey {
        case experiment
        case playerStats = "player_stats"
        case config
    }
}

struct ExperimentResult: Codable {
    let phase1Fill: FillPhaseResult
    let phase2Cooking: CookingPhaseResult
    let outcome: OutcomeResult
    
    enum CodingKeys: String, CodingKey {
        case phase1Fill = "phase1_fill"
        case phase2Cooking = "phase2_cooking"
        case outcome
    }
}

// MARK: - Phase 1

struct FillPhaseResult: Codable {
    let miniBars: [MiniBarResult]
    let mainTubeFill: Double
    let config: FillConfig
    
    enum CodingKeys: String, CodingKey {
        case miniBars = "mini_bars"
        case mainTubeFill = "main_tube_fill"
        case config
    }
}

struct MiniBarResult: Codable, Identifiable {
    let name: String
    let rolls: [MiniRoll]
    let finalFill: Double
    let reagentSelect: Int
    let contribution: Double
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name, rolls
        case finalFill = "final_fill"
        case reagentSelect = "reagent_select"
        case contribution
    }
}

struct MiniRoll: Codable, Identifiable {
    let roll: Int
    let hit: Bool
    let fillAdded: Double
    let totalFill: Double
    
    var id: UUID { UUID() }
    
    enum CodingKeys: String, CodingKey {
        case roll, hit
        case fillAdded = "fill_added"
        case totalFill = "total_fill"
    }
}

// MARK: - Phase 2

struct CookingPhaseResult: Codable {
    let landings: [CookingLanding]
    let bestLanding: Int
    let totalAttempts: Int
    let landedTierId: String?
    let maxLanding: Int
    let config: CookingConfig
    
    enum CodingKeys: String, CodingKey {
        case landings
        case bestLanding = "best_landing"
        case totalAttempts = "total_attempts"
        case landedTierId = "landed_tier_id"
        case maxLanding = "max_landing"
        case config
    }
}

struct CookingLanding: Codable, Identifiable {
    let attemptNumber: Int
    let landingPosition: Int
    let isBest: Bool
    
    var id: Int { attemptNumber }
    
    enum CodingKeys: String, CodingKey {
        case attemptNumber = "attempt_number"
        case landingPosition = "landing_position"
        case isBest = "is_best"
    }
}

// MARK: - Outcome

struct OutcomeResult: Codable {
    let success: Bool
    let isCritical: Bool
    let blueprints: Int
    let gp: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case isCritical = "is_critical"
        case blueprints, gp, message
    }
}

// MARK: - Player Stats

struct PlayerResearchStats: Codable {
    let science: Int
    let philosophy: Int
    let building: Int
    let gold: Int
}

struct AnimationConfig: Codable {
    let fillAnimationMs: Int
    let stabilizeAnimationMs: Int
    let tapAnimationMs: Int
    
    enum CodingKeys: String, CodingKey {
        case fillAnimationMs = "fill_animation_ms"
        case stabilizeAnimationMs = "stabilize_animation_ms"
        case tapAnimationMs = "tap_animation_ms"
    }
}
