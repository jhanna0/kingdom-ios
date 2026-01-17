import Foundation

// MARK: - Config

struct ResearchConfig: Codable {
    let goldCost: Int
    let phases: ResearchPhases
    let rewards: [String: RewardConfig]
    let ui: ResearchUIConfig
    
    enum CodingKeys: String, CodingKey {
        case goldCost = "gold_cost"
        case phases, rewards, ui
    }
}

struct ResearchPhases: Codable {
    let fill: PhaseConfig
    let stabilize: PhaseConfig
    let build: PhaseConfig
}

struct PhaseConfig: Codable {
    let stat: String
    let statDisplayName: String
    let animationMs: Int
    
    enum CodingKeys: String, CodingKey {
        case stat
        case statDisplayName = "stat_display_name"
        case animationMs = "animation_ms"
    }
}

struct RewardConfig: Codable {
    let blueprints: Int
    let gpMin: Int
    let gpMax: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case blueprints
        case gpMin = "gp_min"
        case gpMax = "gp_max"
        case message
    }
}

struct ResearchUIConfig: Codable {
    let title: String
    let icon: String
}

// MARK: - Experiment Result

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
    let phase2Stabilize: StabilizePhaseResult
    let phase3Build: BuildPhaseResult
    let outcome: OutcomeResult
    
    enum CodingKeys: String, CodingKey {
        case phase1Fill = "phase1_fill"
        case phase2Stabilize = "phase2_stabilize"
        case phase3Build = "phase3_build"
        case outcome
    }
}

// MARK: - Phase 1: Fill (3 mini bars)

struct FillPhaseResult: Codable {
    let miniBars: [MiniBarResult]
    let mainTubeFill: Double
    let success: Bool
    let minRequired: Double
    
    enum CodingKeys: String, CodingKey {
        case miniBars = "mini_bars"
        case mainTubeFill = "main_tube_fill"
        case success
        case minRequired = "min_required"
    }
}

struct MiniBarResult: Codable, Identifiable {
    let name: String
    let rolls: [MiniRoll]
    let finalFill: Double
    let masterRoll: Int
    let masterHit: Bool
    let contribution: Double
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name, rolls
        case finalFill = "final_fill"
        case masterRoll = "master_roll"
        case masterHit = "master_hit"
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

// MARK: - Phase 2: Stabilize

struct StabilizePhaseResult: Codable {
    let rolls: [StabilizeRoll]
    let totalHits: Int
    let success: Bool
    let hitsNeeded: Int
    
    enum CodingKeys: String, CodingKey {
        case rolls
        case totalHits = "total_hits"
        case success
        case hitsNeeded = "hits_needed"
    }
}

struct StabilizeRoll: Codable, Identifiable {
    let rollNumber: Int
    let roll: Int
    let hit: Bool
    
    var id: Int { rollNumber }
    
    enum CodingKeys: String, CodingKey {
        case rollNumber = "roll_number"
        case roll, hit
    }
}

// MARK: - Phase 3: Build

struct BuildPhaseResult: Codable {
    let taps: [TapResult]
    let finalProgress: Int
    let success: Bool
    let progressNeeded: Int
    
    enum CodingKeys: String, CodingKey {
        case taps
        case finalProgress = "final_progress"
        case success
        case progressNeeded = "progress_needed"
    }
}

struct TapResult: Codable, Identifiable {
    let tapNumber: Int
    let hit: Bool
    let progressAdded: Int
    let totalProgress: Int
    
    var id: Int { tapNumber }
    
    enum CodingKeys: String, CodingKey {
        case tapNumber = "tap_number"
        case hit
        case progressAdded = "progress_added"
        case totalProgress = "total_progress"
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
