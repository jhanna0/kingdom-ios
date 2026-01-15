import Foundation

// MARK: - Hunt Models
// Models for the group hunting system

// MARK: - Enums

enum HuntPhase: String, Codable, CaseIterable {
    case lobby = "lobby"
    case track = "track"
    case approach = "approach"
    case strike = "strike"
    case blessing = "blessing"
    case results = "results"
    
    var displayName: String {
        switch self {
        case .lobby: return "Waiting"
        case .track: return "Tracking"
        case .approach: return "Approach"
        case .strike: return "The Hunt"
        case .blessing: return "Blessing"
        case .results: return "Results"
        }
    }
    
    var icon: String {
        switch self {
        case .lobby: return "person.3.fill"
        case .track: return "magnifyingglass"
        case .approach: return "figure.walk"
        case .strike: return "bolt.fill"
        case .blessing: return "sparkles"
        case .results: return "trophy.fill"
        }
    }
    
    var statUsed: String {
        switch self {
        case .track: return "intelligence"
        case .approach: return "defense"
        case .strike: return "attack_power"
        case .blessing: return "faith"
        default: return ""
        }
    }
}

enum HuntStatus: String, Codable {
    case lobby = "lobby"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Roll Models

enum RollOutcome: String, Codable {
    case criticalSuccess = "critical_success"
    case success = "success"
    case failure = "failure"
    case criticalFailure = "critical_failure"
    
    var displayName: String {
        switch self {
        case .criticalSuccess: return "Critical!"
        case .success: return "Success"
        case .failure: return "Miss"
        case .criticalFailure: return "Fumble!"
        }
    }
    
    var isSuccess: Bool {
        self == .criticalSuccess || self == .success
    }
    
    var isCritical: Bool {
        self == .criticalSuccess || self == .criticalFailure
    }
}

struct RollResult: Codable, Identifiable {
    let player_id: Int
    let player_name: String
    let stat_name: String
    let stat_value: Int
    let roll_value: Double
    let success_threshold: Double
    let outcome: RollOutcome
    let is_success: Bool
    let is_critical: Bool
    let contribution: Double
    
    var id: Int { player_id }
    
    /// Roll as percentage (0-100)
    var rollPercentage: Int {
        Int(roll_value * 100)
    }
    
    /// Threshold as percentage (0-100)
    var thresholdPercentage: Int {
        Int(success_threshold * 100)
    }
}

struct GroupRollResult: Codable {
    let phase_name: String
    let rolls: [RollResult]
    let total_contribution: Double
    let success_count: Int
    let critical_count: Int
    let group_size: Int
    let group_bonus: Double
    let success_rate: Double
    
    var successPercentage: Int {
        Int(success_rate * 100)
    }
}

// MARK: - Phase Result

struct PhaseResultData: Codable, Identifiable {
    let phase: String
    let phase_name: String
    let icon: String
    let group_roll: GroupRollResult
    let phase_score: Double
    let outcome_message: String
    let effects: [String: AnyCodableValue]?
    
    var id: String { phase }
    
    var huntPhase: HuntPhase {
        HuntPhase(rawValue: phase) ?? .lobby
    }
}

// MARK: - Participant

struct HuntParticipant: Codable, Identifiable {
    let player_id: Int
    let player_name: String
    let stats: [String: Int]?
    let is_ready: Bool
    let is_injured: Bool
    let total_contribution: Double
    let successful_rolls: Int
    let critical_rolls: Int
    let meat_earned: Int
    let items_earned: [String]?
    
    var id: Int { player_id }
}

// MARK: - Animal

struct HuntAnimal: Codable {
    let id: String?
    let name: String?
    let icon: String?
    let tier: Int?
    let hp: Int?
    let meat: Int?
    let rare_drop: RareDropInfo?  // Backwards compat - first rare item
    let potential_drops: [PotentialDropInfo]?  // All possible drops for this animal
}

// Rare drop info from backend - comes from RESOURCES config
struct RareDropInfo: Codable {
    let item_id: String
    let item_name: String
    let item_icon: String
}

// Potential drop info - includes rarity tier
struct PotentialDropInfo: Codable, Identifiable {
    let item_id: String
    let item_name: String
    let item_icon: String
    let item_color: String?
    let rarity: String?  // "uncommon" or "rare"
    
    var id: String { item_id }
}

// MARK: - Phase State (Multi-Roll System)

struct PhaseRoundResult: Codable, Identifiable {
    let round: Int
    let player_id: Int
    let player_name: String
    let roll: Int
    let stat: Int
    let is_success: Bool
    let is_critical: Bool
    let contribution: Double
    let message: String
    
    var id: String { "\(round)-\(player_id)" }
}

// MARK: - Drop Table Item Display (from backend!)
// Backend sends ALL display info - NO hardcoding on frontend!

struct DropTableItemConfig: Codable {
    let key: String      // e.g. "no_trail", "squirrel", "hit"
    let icon: String     // e.g. "❌", "🐿️", "⚔️"
    let name: String     // e.g. "Lost", "Squirrel", "Hit!"
    let color: String    // Hex color e.g. "#4CAF50"
}

// MARK: - Phase Display Config (TEMPLATE SYSTEM!)
// Backend sends ALL display data - frontend is just a dumb template
// This allows reuse for other minigames (fishing, mining, etc.)

struct PhaseDisplayConfig: Codable {
    // Phase info
    let phase_name: String
    let phase_icon: String
    let description: String
    let phase_color: String
    
    // Stat info
    let stat_name: String
    let stat_display_name: String
    let stat_icon: String
    let stat_value: Int
    
    // Hit chance - FLAT, not scaled by stat!
    let hit_chance: Int
    
    // Roll button
    let roll_button_label: String
    let roll_button_icon: String
    
    // Resolve button
    let resolve_button_label: String
    let resolve_button_icon: String
    
    // Drop table display - FULL CONFIG FROM BACKEND!
    let drop_table_title: String
    let drop_table_title_resolving: String
    let drop_table_items: [DropTableItemConfig]?  // All items with their display info!
    
    // Master roll marker icon - varies by phase/skill (leaf for track, scope for strike, sparkles for blessing)
    let master_roll_icon: String?
    
    // Roll messages
    let success_message: String
    let failure_message: String
    let critical_message: String
}

struct PhaseState: Codable {
    let phase: String
    let rounds_completed: Int
    let max_rolls: Int
    let total_score: Double
    let round_results: [PhaseRoundResult]
    
    // TEMPLATE SYSTEM: All display data from backend!
    let display: PhaseDisplayConfig?
    
    // Legacy fields
    let damage_dealt: Int
    let animal_remaining_hp: Int
    let escape_risk: Double
    let blessing_bonus: Double
    
    // DROP TABLE - Same for all phases! (creature odds, damage odds, loot odds)
    let drop_table_slots: [String: Int]?
    let creature_probabilities: [String: Double]
    
    let is_resolved: Bool
    let resolution_roll: Int?
    let resolution_outcome: String?  // The outcome key that was rolled
    let can_roll: Bool
    let can_resolve: Bool
    
    var huntPhase: HuntPhase {
        HuntPhase(rawValue: phase) ?? .lobby
    }
    
    var rollsRemaining: Int {
        max_rolls - rounds_completed
    }
    
    /// Get drop table probabilities (percentages)
    var dropTableOdds: [String: Double] {
        guard let slots = drop_table_slots else { return creature_probabilities }
        let total = Double(slots.values.reduce(0, +))
        guard total > 0 else { return [:] }
        return slots.mapValues { Double($0) / total }
    }
}

// MARK: - Rewards

struct ItemDetail: Codable {
    let id: String
    let display_name: String
    let icon: String
    let color: String
}

struct HuntRewards: Codable {
    let meat: Int
    let bonus_meat: Int
    let total_meat: Int
    let items: [String]
    let item_details: [ItemDetail]?  // Full item config from backend!
}

// MARK: - Hunt Session

struct HuntSession: Codable, Identifiable {
    let hunt_id: String
    let kingdom_id: String
    let created_by: Int
    let status: HuntStatus
    let current_phase: String
    let participants: [String: HuntParticipant]
    let animal: HuntAnimal?
    let track_score: Double
    let max_tier_unlocked: Int
    let is_spooked: Bool
    let animal_escaped: Bool
    let phase_state: PhaseState?  // Multi-roll phase tracking
    let phase_results: [PhaseResultData]
    let rewards: HuntRewards?
    let party_size: Int
    let created_at: String?
    let started_at: String?
    let completed_at: String?
    
    var id: String { hunt_id }
    
    var currentHuntPhase: HuntPhase {
        HuntPhase(rawValue: current_phase) ?? .lobby
    }
    
    var huntStatus: HuntStatus {
        status
    }
    
    var participantList: [HuntParticipant] {
        Array(participants.values).sorted { $0.player_id < $1.player_id }
    }
    
    var allReady: Bool {
        !participants.isEmpty && participants.values.allSatisfy { $0.is_ready }
    }
    
    var isComplete: Bool {
        status == .completed || status == .failed || status == .cancelled
    }
    
    /// Can perform another roll in current phase
    var canRoll: Bool {
        phase_state?.can_roll ?? false
    }
    
    /// Can resolve/finalize current phase
    var canResolve: Bool {
        phase_state?.can_resolve ?? false
    }
}

// MARK: - API Responses

struct HuntResponse: Codable {
    let success: Bool
    let message: String
    let hunt: HuntSession?
}

struct PhaseResultResponse: Codable {
    let success: Bool
    let message: String
    let phase_result: PhaseResultData?
    let hunt: HuntSession?
}

// MARK: - Multi-Roll Response

struct PhaseUpdate: Codable {
    let events: [String]?
    
    // DROP TABLE - Same for all phases!
    let drop_table_slots: [String: Int]?
    let new_probabilities: [String: Double]?  // Derived from slots
    let shift_applied: Bool?
    
    // Legacy/visual fields
    let tier_shift: Double?
    let damage: Int?
    let remaining_hp: Int?
    let total_damage: Int?
    let escaped: Bool?
    let killed: Bool?
    let counterattack: Bool?
    let bonus_added: Double?
    let total_bonus: Double?
}

struct RollResponse: Codable {
    let success: Bool
    let message: String
    let roll_result: PhaseRoundResult?
    let phase_state: PhaseState?
    let phase_update: PhaseUpdate?
    let hunt: HuntSession?
}

struct ActiveHuntResponse: Codable {
    let active_hunt: HuntSession?
}

// MARK: - Hunt Preview (Probability Display)
// NEW SYSTEM: Stat level = number of rolls, flat hit chance per roll

struct HuntPhasePreview: Codable {
    let phase_name: String
    let stat_used: String
    let stat_display_name: String?
    let stat_value: Int
    let max_rolls: Int
    let hit_chance_per_roll: Int
    let prob_at_least_one_success: Int
    let icon: String
    let description: String
    let roll_button_label: String?
    let phase_color: String?
    
    // Computed for backwards compat with views
    var percentage: Int { prob_at_least_one_success }
    var color: String { phase_color ?? "inkMedium" }
}

struct HuntAnimalPreview: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let tier: Int
    let meat: Int
    let hp: Int
    let required_tracking: Int
}

struct HuntPreviewResponse: Codable {
    let player_stats: [String: Int]?
    let phases: [String: HuntPhasePreview]
    let hit_chance_per_roll: Int?  // NEW: flat hit chance for all phases
    let animals: [HuntAnimalPreview]
}

// MARK: - Hunt Config

struct HuntTimingConfig: Codable {
    let lobby_timeout_seconds: Int
    let phase_duration_seconds: Int
    let results_duration_seconds: Int
    let cooldown_minutes: Int
}

struct HuntPartyConfig: Codable {
    let min_size: Int
    let max_size: Int
}

struct HuntPhaseConfig: Codable {
    let name: String
    let display_name: String
    let stat: String
    let icon: String
    let description: String
    // Rare item info (for blessing phase)
    let rare_item_name: String?
    let rare_item_icon: String?
}

struct DropTableDisplayItem: Codable {
    let key: String
    let icon: String
    let name: String
    let color: String
}

struct DropTablesConfig: Codable {
    let track: [DropTableDisplayItem]?
    let strike: [DropTableDisplayItem]?
    let blessing: [DropTableDisplayItem]?
}

struct HuntAnimalConfig: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let tier: Int
    let meat: Int
    let hp: Int
    let description: String
    let track_requirement: Int
}

struct HuntConfigResponse: Codable {
    let timing: HuntTimingConfig
    let party: HuntPartyConfig
    let phases: [String: HuntPhaseConfig]
    let animals: [HuntAnimalConfig]
    let tier_thresholds: [String: Int]
    let drop_tables: DropTablesConfig?
    
    /// Get blessing drop table items
    var blessingDropTable: [DropTableDisplayItem]? {
        drop_tables?.blessing
    }
    
    /// Get rare item name from blessing phase config
    var rareItemName: String? {
        phases["blessing"]?.rare_item_name
    }
    
    /// Get rare item icon from blessing phase config
    var rareItemIcon: String? {
        phases["blessing"]?.rare_item_icon
    }
}

// MARK: - AnyCodable for dynamic effects

enum AnyCodableValue: Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
        } else if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictValue)
        } else {
            self = .bool(false)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        }
    }
    
    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }
    
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    
    var arrayValue: [AnyCodableValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
}

