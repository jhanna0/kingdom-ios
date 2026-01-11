import Foundation

// MARK: - Unified Battle System API Models
// Supports both Coups and Invasions with the same territory-based mechanics

// MARK: - Battle Types

/// Battle type enum for distinguishing coups vs invasions
enum BattleType: String, Codable {
    case coup = "coup"
    case invasion = "invasion"
    
    var displayName: String {
        switch self {
        case .coup: return "Coup"
        case .invasion: return "Invasion"
        }
    }
    
    var icon: String {
        switch self {
        case .coup: return "bolt.fill"
        case .invasion: return "flag.2.crossed.fill"
        }
    }
    
    /// Number of territories for this battle type
    var territoryCount: Int {
        switch self {
        case .coup: return 3
        case .invasion: return 5
        }
    }
    
    /// Win threshold (territories needed to win)
    var winThreshold: Int {
        switch self {
        case .coup: return 2
        case .invasion: return 3
        }
    }
}

// MARK: - Territory Models

/// Territory status in a battle (works for both coups and invasions)
struct BattleTerritory: Codable, Identifiable, Equatable {
    let name: String  // Internal name (e.g., throne_room, north, south)
    let displayName: String
    let icon: String
    let controlBar: Double  // 0-100 (0 = attackers captured, 100 = defenders captured)
    let capturedBy: String?  // 'attackers', 'defenders', or nil
    let capturedAt: String?
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case icon
        case controlBar = "control_bar"
        case capturedBy = "captured_by"
        case capturedAt = "captured_at"
    }
    
    /// Is this territory captured?
    var isCaptured: Bool {
        capturedBy != nil
    }
    
    /// Progress for attackers (0-1, where 1 = captured by attackers)
    var attackerProgress: Double {
        (100.0 - controlBar) / 100.0
    }
    
    /// Progress for defenders (0-1, where 1 = captured by defenders)
    var defenderProgress: Double {
        controlBar / 100.0
    }
}

/// Typealias for backwards compatibility
typealias CoupTerritory = BattleTerritory

// MARK: - Roll Models

/// Single roll result for battle fights
struct BattleRollResult: Codable, Identifiable, Equatable {
    let value: Double
    let outcome: String  // 'miss', 'hit', 'injure'
    
    var id: Double { value }
    
    var isHit: Bool { outcome == "hit" }
    var isInjure: Bool { outcome == "injure" }
    var isMiss: Bool { outcome == "miss" }
}

/// Typealias for backwards compatibility
typealias CoupRollResult = BattleRollResult

// MARK: - Participant Models

/// A player participating in a battle
struct BattleParticipant: Codable, Identifiable {
    let playerId: Int
    let playerName: String
    let kingdomReputation: Int
    let attackPower: Int
    let defensePower: Int
    let leadership: Int
    let level: Int
    
    var id: Int { playerId }
    
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case playerName = "player_name"
        case kingdomReputation = "kingdom_reputation"
        case attackPower = "attack_power"
        case defensePower = "defense_power"
        case leadership
        case level
    }
}

/// Typealias for backwards compatibility
typealias CoupParticipant = BattleParticipant

// MARK: - Initiate/Declare Responses

/// Response after initiating a coup or declaring an invasion
struct BattleInitiateResponse: Codable {
    let success: Bool
    let message: String
    let battleId: Int
    let battleType: String  // "coup" or "invasion"
    let pledgeEndTime: String
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case battleId = "battle_id"
        case battleType = "battle_type"
        case pledgeEndTime = "pledge_end_time"
    }
    
    var isCoup: Bool { battleType == "coup" }
    var isInvasion: Bool { battleType == "invasion" }
}

/// Backwards compatible alias - maps to battleId
struct CoupInitiateResponse: Codable {
    let success: Bool
    let message: String
    let coupId: Int
    let pledgeEndTime: String
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case coupId = "battle_id"  // Backend now returns battle_id
        case pledgeEndTime = "pledge_end_time"
    }
}

// MARK: - Join Response

/// Response after joining a battle
struct BattleJoinResponse: Codable {
    let success: Bool
    let message: String
    let side: String
    let attackerCount: Int
    let defenderCount: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, side
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
    }
}

/// Typealias for backwards compatibility
typealias CoupJoinResponse = BattleJoinResponse

// MARK: - Main Battle Event Response

/// Full battle event details from GET /battles/{id}
/// Works for both coups and invasions
struct BattleEventResponse: Codable, Identifiable {
    let id: Int
    let type: String  // "coup" or "invasion"
    
    // Target kingdom
    let kingdomId: String
    let kingdomName: String?
    
    // For invasions: attacking kingdom
    let attackingFromKingdomId: String?
    let attackingFromKingdomName: String?
    
    // Initiator
    let initiatorId: Int
    let initiatorName: String
    let initiatorStats: InitiatorStats?
    
    // Current ruler being challenged
    let rulerId: Int?
    let rulerName: String?
    let rulerStats: InitiatorStats?
    
    // Phase
    let status: String  // 'pledge', 'battle', 'resolved'
    
    // Timing
    let startTime: String
    let pledgeEndTime: String
    let timeRemainingSeconds: Int
    
    // Participants - sorted by kingdom_reputation descending
    let attackers: [BattleParticipant]
    let defenders: [BattleParticipant]
    let attackerCount: Int
    let defenderCount: Int
    
    // User participation
    let userSide: String?
    let canJoin: Bool
    
    // Battle phase data
    let territories: [BattleTerritory]?
    let battleCooldownSeconds: Int?
    let isInjured: Bool?
    let injuryExpiresSeconds: Int?
    
    // Invasion-specific
    let wallDefenseApplied: Int?
    
    // Resolution
    let isResolved: Bool
    let attackerVictory: Bool?
    let resolvedAt: String?
    let winnerSide: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case attackingFromKingdomId = "attacking_from_kingdom_id"
        case attackingFromKingdomName = "attacking_from_kingdom_name"
        case initiatorId = "initiator_id"
        case initiatorName = "initiator_name"
        case initiatorStats = "initiator_stats"
        case rulerId = "ruler_id"
        case rulerName = "ruler_name"
        case rulerStats = "ruler_stats"
        case status
        case startTime = "start_time"
        case pledgeEndTime = "pledge_end_time"
        case timeRemainingSeconds = "time_remaining_seconds"
        case attackers, defenders
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
        case userSide = "user_side"
        case canJoin = "can_join"
        case territories
        case battleCooldownSeconds = "battle_cooldown_seconds"
        case isInjured = "is_injured"
        case injuryExpiresSeconds = "injury_expires_seconds"
        case wallDefenseApplied = "wall_defense_applied"
        case isResolved = "is_resolved"
        case attackerVictory = "attacker_victory"
        case resolvedAt = "resolved_at"
        case winnerSide = "winner_side"
    }
    
    // MARK: - Computed Properties
    
    /// Battle type enum
    var battleType: BattleType {
        BattleType(rawValue: type) ?? .coup
    }
    
    /// Is this a coup?
    var isCoup: Bool { type == "coup" }
    
    /// Is this an invasion?
    var isInvasion: Bool { type == "invasion" }
    
    /// Is this battle in pledge phase?
    var isPledgePhase: Bool { status == "pledge" }
    
    /// Is this battle in battle phase?
    var isBattlePhase: Bool { status == "battle" }
    
    /// Can user fight right now?
    var canFight: Bool {
        guard isBattlePhase else { return false }
        guard userSide != nil else { return false }
        guard !(isInjured ?? false) else { return false }
        guard (battleCooldownSeconds ?? 0) <= 0 else { return false }
        return true
    }
    
    /// Formatted time remaining
    var timeRemainingFormatted: String {
        let hours = timeRemainingSeconds / 3600
        let minutes = (timeRemainingSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            let seconds = timeRemainingSeconds % 60
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(timeRemainingSeconds)s"
        }
    }
    
    /// Formatted battle cooldown
    var battleCooldownFormatted: String {
        let seconds = battleCooldownSeconds ?? 0
        if seconds <= 0 { return "Ready" }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    /// Win threshold for this battle type
    var winThreshold: Int {
        battleType.winThreshold
    }
    
    /// Attacker side label based on battle type
    var attackerLabel: String {
        isCoup ? "Coupers" : "Invaders"
    }
    
    /// Defender side label based on battle type
    var defenderLabel: String {
        isCoup ? "Crown" : "Defenders"
    }
    
    /// Captured count for attackers
    var attackerCaptures: Int {
        territories?.filter { $0.capturedBy == "attackers" }.count ?? 0
    }
    
    /// Captured count for defenders
    var defenderCaptures: Int {
        territories?.filter { $0.capturedBy == "defenders" }.count ?? 0
    }
}

/// Backwards compatible typealias
typealias CoupEventResponse = BattleEventResponse

// MARK: - Active Battles Response

/// Response with list of active battles
struct ActiveBattlesResponse: Codable {
    let activeBattles: [BattleEventResponse]
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case activeBattles = "active_battles"
        case count
    }
}

// MARK: - Fight Session Models (roll-by-roll)

/// Current state of a fight session
struct FightSessionResponse: Codable {
    let success: Bool
    let message: String
    
    // Session info
    let territoryName: String
    let territoryDisplayName: String
    let territoryIcon: String
    let side: String
    
    // Roll state
    let maxRolls: Int
    let rollsCompleted: Int
    let rollsRemaining: Int
    let rolls: [BattleRollResult]
    
    // Roll bar percentages (0-100)
    let missChance: Int
    let hitChance: Int
    let injureChance: Int
    
    let bestOutcome: String
    let canRoll: Bool
    
    // Bar info
    let barBefore: Double
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case territoryName = "territory_name"
        case territoryDisplayName = "territory_display_name"
        case territoryIcon = "territory_icon"
        case side
        case maxRolls = "max_rolls"
        case rollsCompleted = "rolls_completed"
        case rollsRemaining = "rolls_remaining"
        case rolls
        case missChance = "miss_chance"
        case hitChance = "hit_chance"
        case injureChance = "injure_chance"
        case bestOutcome = "best_outcome"
        case canRoll = "can_roll"
        case barBefore = "bar_before"
    }
}

/// Response after doing one roll
struct FightRollResponse: Codable {
    let success: Bool
    let message: String
    
    // The roll that was just done
    let roll: BattleRollResult
    let rollNumber: Int
    
    // Updated session state
    let rollsCompleted: Int
    let rollsRemaining: Int
    let bestOutcome: String
    let canRoll: Bool
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case roll
        case rollNumber = "roll_number"
        case rollsCompleted = "rolls_completed"
        case rollsRemaining = "rolls_remaining"
        case bestOutcome = "best_outcome"
        case canRoll = "can_roll"
    }
}

/// Response after resolving a fight
struct FightResolveResponse: Codable {
    let success: Bool
    let message: String
    
    // Roll summary
    let rollCount: Int
    let rolls: [BattleRollResult]
    let bestOutcome: String
    
    // Bar movement
    let pushAmount: Double
    let barBefore: Double
    let barAfter: Double
    
    // Territory status
    let territory: BattleTerritory
    
    // Injury info
    let injuredPlayerName: String?
    
    // Battle status
    let battleWon: Bool
    let winnerSide: String?
    
    // Cooldown
    let cooldownSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case rollCount = "roll_count"
        case rolls
        case bestOutcome = "best_outcome"
        case pushAmount = "push_amount"
        case barBefore = "bar_before"
        case barAfter = "bar_after"
        case territory
        case injuredPlayerName = "injured_player_name"
        case battleWon = "battle_won"
        case winnerSide = "winner_side"
        case cooldownSeconds = "cooldown_seconds"
    }
}

// MARK: - Eligibility Check

/// Check if user can initiate battles in a kingdom
struct BattleEligibilityResponse: Codable {
    let canInitiateCoup: Bool
    let coupReason: String?
    
    let canDeclareInvasion: Bool
    let invasionReason: String?
    
    let canJoinActiveBattle: Bool
    let activeBattleId: Int?
    let activeBattleType: String?
    let joinReason: String?
    
    enum CodingKeys: String, CodingKey {
        case canInitiateCoup = "can_initiate_coup"
        case coupReason = "coup_reason"
        case canDeclareInvasion = "can_declare_invasion"
        case invasionReason = "invasion_reason"
        case canJoinActiveBattle = "can_join_active_battle"
        case activeBattleId = "active_battle_id"
        case activeBattleType = "active_battle_type"
        case joinReason = "join_reason"
    }
}
