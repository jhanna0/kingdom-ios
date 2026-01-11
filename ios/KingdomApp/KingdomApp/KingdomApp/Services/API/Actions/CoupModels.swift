import Foundation

// MARK: - Coup V2 API Models

// MARK: - Battle Phase Models

/// Territory status in a coup battle
struct CoupTerritory: Codable, Identifiable, Equatable {
    let name: String  // coupers_territory, crowns_territory, throne_room
    let displayName: String
    let icon: String
    let controlBar: Double  // 0-100 (0 = attackers, 100 = defenders)
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

/// Single roll result for coup battles
struct CoupRollResult: Codable, Identifiable, Equatable {
    let value: Double
    let outcome: String  // 'miss', 'hit', 'injure'
    
    var id: Double { value }
    
    var isHit: Bool { outcome == "hit" }
    var isInjure: Bool { outcome == "injure" }
    var isMiss: Bool { outcome == "miss" }
}

/// Response after fighting in a territory
struct CoupFightResponse: Codable, Equatable {
    let success: Bool
    let message: String
    
    // Roll results
    let rollCount: Int
    let rolls: [CoupRollResult]
    let bestOutcome: String  // 'miss', 'hit', 'injure'
    
    // Bar movement
    let pushAmount: Double
    let barBefore: Double
    let barAfter: Double
    
    // Territory status after fight
    let territory: CoupTerritory
    
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

// MARK: - Pledge Phase Models

/// Response after pledging to a side
struct CoupJoinResponse: Codable {
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

/// Response after initiating a coup
struct CoupInitiateResponse: Codable {
    let success: Bool
    let message: String
    let coupId: Int
    let pledgeEndTime: String
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case coupId = "coup_id"
        case pledgeEndTime = "pledge_end_time"
    }
}

/// Full coup event details from GET /coups/{id}
struct CoupEventResponse: Codable, Identifiable {
    let id: Int
    let kingdomId: String
    let kingdomName: String?
    let initiatorId: Int
    let initiatorName: String
    let initiatorStats: InitiatorStats?
    let rulerId: Int?  // Current ruler being challenged
    let rulerName: String?  // Current ruler's name
    let rulerStats: InitiatorStats?  // Ruler's character sheet
    let status: String  // 'pledge', 'battle', 'resolved'
    
    // Timing
    let startTime: String
    let pledgeEndTime: String
    let battleEndTime: String?
    let timeRemainingSeconds: Int
    
    // Participants - sorted by kingdom_reputation descending
    let attackers: [CoupParticipant]
    let defenders: [CoupParticipant]
    let attackerCount: Int
    let defenderCount: Int
    
    // User participation
    let userSide: String?
    let canPledge: Bool
    
    // Battle phase data
    let territories: [CoupTerritory]?
    let battleCooldownSeconds: Int?
    let isInjured: Bool?
    let injuryExpiresSeconds: Int?
    
    // Resolution
    let isResolved: Bool
    let attackerVictory: Bool?
    let resolvedAt: String?
    let winnerSide: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case initiatorId = "initiator_id"
        case initiatorName = "initiator_name"
        case initiatorStats = "initiator_stats"
        case rulerId = "ruler_id"
        case rulerName = "ruler_name"
        case rulerStats = "ruler_stats"
        case status
        case startTime = "start_time"
        case pledgeEndTime = "pledge_end_time"
        case battleEndTime = "battle_end_time"
        case timeRemainingSeconds = "time_remaining_seconds"
        case attackers, defenders
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
        case userSide = "user_side"
        case canPledge = "can_pledge"
        case territories
        case battleCooldownSeconds = "battle_cooldown_seconds"
        case isInjured = "is_injured"
        case injuryExpiresSeconds = "injury_expires_seconds"
        case isResolved = "is_resolved"
        case attackerVictory = "attacker_victory"
        case resolvedAt = "resolved_at"
        case winnerSide = "winner_side"
    }
    
    /// Is this coup in pledge phase?
    var isPledgePhase: Bool {
        status == "pledge"
    }
    
    /// Is this coup in battle phase?
    var isBattlePhase: Bool {
        status == "battle"
    }
    
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
    
    /// Formatted injury time
    var injuryFormatted: String {
        let seconds = injuryExpiresSeconds ?? 0
        if seconds <= 0 { return "" }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

/// Response with list of active coups
struct ActiveCoupsResponse: Codable {
    let activeCoups: [CoupEventResponse]
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case activeCoups = "active_coups"
        case count
    }
}

// MARK: - Fight Session Models (roll-by-roll like hunting)

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
    let rolls: [CoupRollResult]
    
    // Roll bar percentages (0-100) - from backend, no frontend calculations
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
    let roll: CoupRollResult
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
    let rolls: [CoupRollResult]
    let bestOutcome: String
    
    // Bar movement
    let pushAmount: Double
    let barBefore: Double
    let barAfter: Double
    
    // Territory status
    let territory: CoupTerritory
    
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

