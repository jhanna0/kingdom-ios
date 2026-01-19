import Foundation

// MARK: - Config

struct ResearchConfig: Codable {
    let goldCost: Int
    let phase1Preparation: PreparationConfig
    let phase2Synthesis: SynthesisConfig
    
    enum CodingKeys: String, CodingKey {
        case goldCost = "gold_cost"
        case phase1Preparation = "phase1_preparation"
        case phase2Synthesis = "phase2_synthesis"
    }
}

struct PreparationConfig: Codable {
    let stat: String
    let statDisplayName: String
    let baseInfusions: Int
    let infusionsPerStat: Int
    let stableThreshold: Int
    let stableFillAmount: Double
    let volatileFillAmount: Double
    let reagentNames: [String]
    let stableLabel: String
    let volatileLabel: String
    
    enum CodingKeys: String, CodingKey {
        case stat
        case statDisplayName = "stat_display_name"
        case baseInfusions = "base_infusions"
        case infusionsPerStat = "infusions_per_stat"
        case stableThreshold = "stable_threshold"
        case stableFillAmount = "stable_fill_amount"
        case volatileFillAmount = "volatile_fill_amount"
        case reagentNames = "reagent_names"
        case stableLabel = "stable_label"
        case volatileLabel = "volatile_label"
    }
}

struct SynthesisConfig: Codable {
    let stat: String
    let statDisplayName: String
    let baseInfusions: Int
    let infusionsPerStat: Int
    let stableThreshold: Int
    let purityGains: [PurityGainRange]
    let volatilePurityGain: Int
    let finalInfusion: FinalInfusionConfig
    let progressMessages: ProgressMessages
    let resultTiers: [ResultTier]
    let stableLabel: String
    let volatileLabel: String
    let purityLabel: String
    let potentialLabel: String
    
    enum CodingKeys: String, CodingKey {
        case stat
        case statDisplayName = "stat_display_name"
        case baseInfusions = "base_infusions"
        case infusionsPerStat = "infusions_per_stat"
        case stableThreshold = "stable_threshold"
        case purityGains = "purity_gains"
        case volatilePurityGain = "volatile_purity_gain"
        case finalInfusion = "final_infusion"
        case progressMessages = "progress_messages"
        case resultTiers = "result_tiers"
        case stableLabel = "stable_label"
        case volatileLabel = "volatile_label"
        case purityLabel = "purity_label"
        case potentialLabel = "potential_label"
    }
}

struct PurityGainRange: Codable {
    let minValue: Int
    let maxValue: Int
    let gainMin: Int
    let gainMax: Int
    let quality: String
    
    enum CodingKeys: String, CodingKey {
        case minValue = "min_value"
        case maxValue = "max_value"
        case gainMin = "gain_min"
        case gainMax = "gain_max"
        case quality
    }
}

struct FinalInfusionConfig: Codable {
    let enabled: Bool
    let gainMultiplier: Double
    let label: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case enabled
        case gainMultiplier = "gain_multiplier"
        case label, description
    }
}

struct ProgressMessages: Codable {
    let starting: String
    let low: String
    let warming: String
    let close: String
    let excellent: String
}

struct ResultTier: Codable, Identifiable {
    let id: String
    let minPurity: Int
    let maxPurity: Int
    let label: String
    let title: String
    let description: String
    let blueprints: Int
    let gpMin: Int
    let gpMax: Int
    let color: String
    let icon: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case minPurity = "min_purity"
        case maxPurity = "max_purity"
        case label, title, description, blueprints
        case gpMin = "gp_min"
        case gpMax = "gp_max"
        case color, icon
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
    let phase1Preparation: PreparationPhaseResult
    let phase2Synthesis: SynthesisPhaseResult
    let outcome: OutcomeResult
    
    enum CodingKeys: String, CodingKey {
        case phase1Preparation = "phase1_preparation"
        case phase2Synthesis = "phase2_synthesis"
        case outcome
    }
}

// MARK: - Phase 1: Preparation

struct PreparationPhaseResult: Codable {
    let reagents: [ReagentResult]
    let potential: Int
    let config: PreparationConfig
}

struct ReagentResult: Codable, Identifiable {
    let name: String
    let infusions: [Infusion]
    let finalFill: Double
    let amountSelected: Int
    let contribution: Double
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name, infusions
        case finalFill = "final_fill"
        case amountSelected = "amount_selected"
        case contribution
    }
}

struct Infusion: Codable, Identifiable {
    let value: Int
    let stable: Bool
    let fillAdded: Double
    let totalFill: Double
    
    var id: UUID { UUID() }
    
    enum CodingKeys: String, CodingKey {
        case value, stable
        case fillAdded = "fill_added"
        case totalFill = "total_fill"
    }
}

// MARK: - Phase 2: Synthesis

struct SynthesisPhaseResult: Codable {
    let infusions: [SynthesisInfusion]
    let finalInfusion: SynthesisInfusion?
    let finalPurity: Int
    let potential: Int
    let totalInfusions: Int
    let resultTierId: String?
    let config: SynthesisConfig
    
    enum CodingKeys: String, CodingKey {
        case infusions
        case finalInfusion = "final_infusion"
        case finalPurity = "final_purity"
        case potential
        case totalInfusions = "total_infusions"
        case resultTierId = "result_tier_id"
        case config
    }
}

struct SynthesisInfusion: Codable, Identifiable {
    let value: Int
    let stable: Bool
    let quality: String?
    let purityGained: Int
    let purityAfter: Int
    let isFinal: Bool
    
    var id: UUID { UUID() }
    
    enum CodingKeys: String, CodingKey {
        case value, stable, quality
        case purityGained = "purity_gained"
        case purityAfter = "purity_after"
        case isFinal = "is_final"
    }
}

// MARK: - Outcome

struct OutcomeResult: Codable {
    let success: Bool
    let isEureka: Bool
    let blueprints: Int
    let gp: Int
    let title: String
    let message: String
    let tierId: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case isEureka = "is_eureka"
        case blueprints, gp, title, message
        case tierId = "tier_id"
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
    let preparationAnimationMs: Int
    let synthesisAnimationMs: Int
    let infusionAnimationMs: Int
    let finalInfusionAnimationMs: Int
    
    enum CodingKeys: String, CodingKey {
        case preparationAnimationMs = "preparation_animation_ms"
        case synthesisAnimationMs = "synthesis_animation_ms"
        case infusionAnimationMs = "infusion_animation_ms"
        case finalInfusionAnimationMs = "final_infusion_animation_ms"
    }
}
