import Foundation

// MARK: - Duel Models

/// Status of a duel match
enum DuelStatus: String, Codable {
    case waiting
    case ready
    case fighting
    case complete
    case cancelled
    case expired
}

/// Outcome of a duel attack
enum DuelOutcome: String, Codable {
    case miss
    case hit
    case critical
}

/// Player info in a duel
struct DuelPlayer: Codable {
    let id: Int?
    let name: String?
    let stats: DuelPlayerStats?
}

/// Snapshot of player stats for the duel
struct DuelPlayerStats: Codable {
    let attack: Int
    let defense: Int
    let level: Int
    let leadership: Int?
    
    // Equipment breakdown (optional for backwards compatibility)
    let baseAttack: Int?
    let baseDefense: Int?
    let weaponBonus: Int?
    let armorBonus: Int?
    
    enum CodingKeys: String, CodingKey {
        case attack, defense, level, leadership
        case baseAttack = "base_attack"
        case baseDefense = "base_defense"
        case weaponBonus = "weapon_bonus"
        case armorBonus = "armor_bonus"
    }
    
    /// True if player has any equipment bonuses
    var hasEquipmentBonus: Bool {
        (weaponBonus ?? 0) > 0 || (armorBonus ?? 0) > 0
    }
    
    /// Formatted attack string showing breakdown
    var attackDisplayString: String {
        if let base = baseAttack, let weapon = weaponBonus, weapon > 0 {
            return "\(base)+\(weapon)"
        }
        return "\(attack)"
    }
    
    /// Formatted defense string showing breakdown
    var defenseDisplayString: String {
        if let base = baseDefense, let armor = armorBonus, armor > 0 {
            return "\(base)+\(armor)"
        }
        return "\(defense)"
    }
}

/// Winner information
struct DuelWinner: Codable {
    let id: Int?
    let side: String?
    let goldEarned: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case side
        case goldEarned = "gold_earned"
    }
}

/// A duel attack action (full version from database/action history)
struct DuelAction: Codable, Identifiable {
    let id: Int
    let matchId: Int
    let playerId: Int
    let side: String
    let rollValue: Double
    let outcome: String
    let pushAmount: Double
    let barBefore: Double
    let barAfter: Double
    let performedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case playerId = "player_id"
        case side
        case rollValue = "roll_value"
        case outcome
        case pushAmount = "push_amount"
        case barBefore = "bar_before"
        case barAfter = "bar_after"
        case performedAt = "performed_at"
    }
    
    var outcomeEmoji: String {
        switch outcome {
        case "critical": return "💥"
        case "hit": return "⚔️"
        default: return "💨"
        }
    }
    
    var outcomeColor: String {
        switch outcome {
        case "critical": return "yellow"
        case "hit": return "green"
        default: return "gray"
        }
    }
}

/// Simple player info for the "you" and "opponent" fields in player-perspective response
struct DuelPlayerInfo: Codable {
    let id: Int?
    let name: String?
    let attack: Int?
    let defense: Int?
    let leadership: Int?
}

/// Odds for probability bar display
struct DuelOdds: Codable {
    let miss: Int
    let hit: Int
    let crit: Int
}

/// Attack style definition from server - frontend renders what server sends
struct AttackStyleConfig: Codable, Identifiable {
    let id: String  // balanced, aggressive, precise, power, guard, feint
    let name: String
    let description: String
    let bullets: [String]?  // Server-provided bullet points (use these!)
    let icon: String  // SF Symbol name
    
    // Modifiers (for display to user)
    let rollBonus: Int
    let hitChanceMod: Int  // As percentage (e.g., -5, +8)
    let critRateMod: Int   // As percentage change (e.g., -25)
    let pushMultWin: Double
    let pushMultLose: Double
    let opponentHitMod: Int
    let winsTies: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, bullets, icon
        case rollBonus = "roll_bonus"
        case hitChanceMod = "hit_chance_mod"
        case critRateMod = "crit_rate_mod"
        case pushMultWin = "push_mult_win"
        case pushMultLose = "push_mult_lose"
        case opponentHitMod = "opponent_hit_mod"
        case winsTies = "wins_ties"
    }
    
    /// Human-readable summary of the style's effects - USE SERVER BULLETS
    var effectsSummary: [String] {
        // Use server-provided bullets (dumb renderer principle)
        if let bullets = bullets, !bullets.isEmpty {
            return bullets
        }
        // Fallback for old servers that don't send bullets
        var effects: [String] = []
        if rollBonus != 0 {
            effects.append(rollBonus > 0 ? "+\(rollBonus) roll" : "\(rollBonus) roll")
        }
        if hitChanceMod != 0 {
            effects.append(hitChanceMod > 0 ? "+\(hitChanceMod)% hit" : "\(hitChanceMod)% hit")
        }
        if critRateMod != 0 {
            effects.append("\(critRateMod)% crit rate")
        }
        if opponentHitMod != 0 {
            effects.append("Enemy \(opponentHitMod)% hit")
        }
        if pushMultWin != 1.0 {
            let pct = Int((pushMultWin - 1.0) * 100)
            effects.append("+\(pct)% push if win")
        }
        if pushMultLose != 1.0 {
            let pct = Int((pushMultLose - 1.0) * 100)
            effects.append("Enemy +\(pct)% if lose")
        }
        if winsTies {
            effects.append("Win ties")
        }
        return effects
    }
}

/// Game config from server - frontend has ZERO hardcoded values
struct DuelGameConfig: Codable {
    // Mode
    let duelMode: String?

    // Timing
    let turnTimeoutSeconds: Int
    let roundTimeoutSeconds: Int?
    let styleLockTimeoutSeconds: Int?
    let swingTimeoutSeconds: Int?
    let styleRevealDurationSeconds: Int?
    let invitationTimeoutMinutes: Int
    
    // Combat multipliers
    let criticalMultiplier: Double
    let criticalMultiplierText: String?
    let pushBasePercent: Double
    let leadershipBonusPercent: Double
    
    // Hit chance bounds
    let minHitChancePercent: Int
    let maxHitChancePercent: Int
    
    // Crit rate
    let critRatePercent: Int
    
    // Wager limits
    let maxWagerGold: Int
    
    // Animation timing (ms)
    let rollAnimationMs: Int
    let rollPauseBetweenMs: Int
    let critPopupDurationMs: Int
    let rollSweepStepMs: Int
    let styleRevealDurationMs: Int?

    // Round pacing
    let maxRollsPerRoundCap: Int?
    
    // Attack styles
    let attackStyles: [AttackStyleConfig]?
    let defaultStyle: String?
    
    // Outcome display config (labels, icons, colors for miss/hit/crit)
    let outcomes: [String: OutcomeDisplayConfig]?
    
    enum CodingKeys: String, CodingKey {
        case duelMode = "duel_mode"
        case turnTimeoutSeconds = "turn_timeout_seconds"
        case roundTimeoutSeconds = "round_timeout_seconds"
        case styleLockTimeoutSeconds = "style_lock_timeout_seconds"
        case swingTimeoutSeconds = "swing_timeout_seconds"
        case styleRevealDurationSeconds = "style_reveal_duration_seconds"
        case invitationTimeoutMinutes = "invitation_timeout_minutes"
        case criticalMultiplier = "critical_multiplier"
        case criticalMultiplierText = "critical_multiplier_text"
        case pushBasePercent = "push_base_percent"
        case leadershipBonusPercent = "leadership_bonus_percent"
        case minHitChancePercent = "min_hit_chance_percent"
        case maxHitChancePercent = "max_hit_chance_percent"
        case critRatePercent = "crit_rate_percent"
        case maxWagerGold = "max_wager_gold"
        case rollAnimationMs = "roll_animation_ms"
        case rollPauseBetweenMs = "roll_pause_between_ms"
        case critPopupDurationMs = "crit_popup_duration_ms"
        case rollSweepStepMs = "roll_sweep_step_ms"
        case styleRevealDurationMs = "style_reveal_duration_ms"
        case maxRollsPerRoundCap = "max_rolls_per_round_cap"
        case attackStyles = "attack_styles"
        case defaultStyle = "default_style"
        case outcomes
    }
}

/// Outcome display configuration from server
struct OutcomeDisplayConfig: Codable {
    let label: String
    let icon: String
    let color: String
}

/// Roll with attacker info (no isMe flag needed - server tells us who attacked)
struct DuelTurnRoll: Codable {
    let rollNumber: Int
    let value: Double
    let outcome: String
    let attackerName: String?
    
    enum CodingKeys: String, CodingKey {
        case rollNumber = "roll_number"
        case value, outcome
        case attackerName = "attacker_name"
    }
}

/// Winner from player's perspective
struct DuelWinnerPerspective: Codable {
    let id: Int?
    let didIWin: Bool?
    let goldEarned: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case didIWin = "did_i_win"
        case goldEarned = "gold_earned"
    }
}

/// A duel match - swing-by-swing system with player perspective
struct DuelMatch: Codable, Identifiable {
    let id: Int
    let matchCode: String
    let kingdomId: String
    let status: String
    
    // === ROUND STATE ===
    let roundNumber: Int?
    let roundPhase: String?  // style_selection, style_reveal, swinging, resolving
    let roundExpiresAt: String?
    
    // === STYLE PHASE ===
    let inStylePhase: Bool?
    let inStyleReveal: Bool?
    let canLockStyle: Bool?
    let myStyle: String?
    let myStyleLocked: Bool?
    let opponentStyle: String?
    let opponentStyleLocked: Bool?
    let bothStylesLocked: Bool?
    let styleLockExpiresAt: String?
    
    // === SWING PHASE (the core mechanic) ===
    let inSwingPhase: Bool?
    let canSwing: Bool?
    let canStop: Bool?
    let swingsUsed: Int?
    let swingsRemaining: Int?
    let maxSwings: Int?
    let baseMaxSwings: Int?  // Before style modifier
    let swingDelta: Int?  // Style effect on swings
    let opponentMaxSwings: Int?
    let opponentBaseSwings: Int?
    let opponentSwingDelta: Int?
    let bestOutcome: String?
    let myRolls: [[String: AnyCodable]]?  // All your rolls this round
    let submitted: Bool?
    let opponentSubmitted: Bool?
    let swingPhaseExpiresAt: String?
    
    // === BAR POSITION ===
    let yourBarPosition: Double?
    let controlBar: Double?
    
    // === ODDS (your attack vs opponent) ===
    let currentOdds: DuelOdds?
    let baseOdds: DuelOdds?  // Before style modifiers (for animation)
    
    // === OPPONENT'S ODDS (opponent's attack vs you) ===
    let opponentOdds: DuelOdds?
    let opponentBaseOdds: DuelOdds?
    
    // === TIMEOUT ===
    let canClaimTimeout: Bool?
    
    // === YOUR INFO ===
    let you: DuelPlayerInfo?
    
    // === OPPONENT INFO ===
    let opponentInfo: DuelPlayerInfo?
    
    // === WINNER ===
    let winnerPerspective: DuelWinnerPerspective?
    
    // === METADATA ===
    let wagerGold: Int
    let createdAt: String?
    let startedAt: String?
    let completedAt: String?
    let turnExpiresAt: String?
    
    // === GAME CONFIG ===
    let config: DuelGameConfig?
    
    // === LEGACY ===
    let challenger: DuelPlayer
    let opponent: DuelPlayer?
    let currentTurn: String?
    let isYourTurn: Bool?
    let canAttack: Bool?
    let hasSubmittedRound: Bool?
    let opponentHasSubmittedRound: Bool?
    let canSubmitRound: Bool?
    let yourRoundRollsCount: Int?
    let yourSwingsUsed: Int?
    let yourSwingsRemaining: Int?
    let yourMaxSwings: Int?
    let turnRolls: [DuelTurnRoll]?
    let turnSwingsUsed: Int?
    let turnMaxSwings: Int?
    let turnSwingsRemaining: Int?
    let actions: [DuelAction]?
    
    /// Legacy winner accessor
    var winner: DuelWinner? {
        guard let wp = winnerPerspective else { return nil }
        return DuelWinner(id: wp.id, side: nil, goldEarned: wp.goldEarned)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchCode = "match_code"
        case kingdomId = "kingdom_id"
        case status
        
        // Round state
        case roundNumber = "round_number"
        case roundPhase = "round_phase"
        case roundExpiresAt = "round_expires_at"
        
        // Style phase
        case inStylePhase = "in_style_phase"
        case inStyleReveal = "in_style_reveal"
        case canLockStyle = "can_lock_style"
        case myStyle = "my_style"
        case myStyleLocked = "my_style_locked"
        case opponentStyle = "opponent_style"
        case opponentStyleLocked = "opponent_style_locked"
        case bothStylesLocked = "both_styles_locked"
        case styleLockExpiresAt = "style_lock_expires_at"
        
        // Swing phase
        case inSwingPhase = "in_swing_phase"
        case canSwing = "can_swing"
        case canStop = "can_stop"
        case swingsUsed = "swings_used"
        case swingsRemaining = "swings_remaining"
        case maxSwings = "max_swings"
        case baseMaxSwings = "base_max_swings"
        case swingDelta = "swing_delta"
        case opponentMaxSwings = "opponent_max_swings"
        case opponentBaseSwings = "opponent_base_swings"
        case opponentSwingDelta = "opponent_swing_delta"
        case bestOutcome = "best_outcome"
        case myRolls = "my_rolls"
        case submitted
        case opponentSubmitted = "opponent_submitted"
        case swingPhaseExpiresAt = "swing_phase_expires_at"
        
        // Bar position
        case yourBarPosition = "your_bar_position"
        case controlBar = "control_bar"
        
        // Odds
        case currentOdds = "current_odds"
        case baseOdds = "base_odds"
        case opponentOdds = "opponent_odds"
        case opponentBaseOdds = "opponent_base_odds"
        
        // Timeout
        case canClaimTimeout = "can_claim_timeout"
        
        // Player info
        case you
        case opponentInfo = "opponent"
        
        // Winner
        case winnerPerspective = "winner"
        
        // Metadata
        case wagerGold = "wager_gold"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case turnExpiresAt = "turn_expires_at"
        case config
        
        // Legacy
        case challenger
        case opponent = "opponent_legacy"
        case currentTurn = "current_turn"
        case isYourTurn = "is_your_turn"
        case canAttack = "can_attack"
        case hasSubmittedRound = "has_submitted_round"
        case opponentHasSubmittedRound = "opponent_has_submitted_round"
        case canSubmitRound = "can_submit_round"
        case yourRoundRollsCount = "your_round_rolls_count"
        case yourSwingsUsed = "your_swings_used"
        case yourSwingsRemaining = "your_swings_remaining"
        case yourMaxSwings = "your_max_swings"
        case turnRolls = "turn_rolls"
        case turnSwingsUsed = "turn_swings_used"
        case turnMaxSwings = "turn_max_swings"
        case turnSwingsRemaining = "turn_swings_remaining"
        case actions
    }
    
    // MARK: - Status Helpers
    
    var isWaiting: Bool { status == "waiting" }
    var isPendingAcceptance: Bool { status == "pending_acceptance" }
    var isReady: Bool { status == "ready" }
    var isFighting: Bool { status == "fighting" }
    var isComplete: Bool { status == "complete" }
    var isCancelled: Bool { status == "cancelled" }
    var isExpired: Bool { status == "expired" }
    var isDeclined: Bool { status == "declined" }
    
    var isActive: Bool {
        isWaiting || isPendingAcceptance || isReady || isFighting
    }
    
    var statusText: String {
        switch status {
        case "waiting": return "Waiting for Opponent"
        case "pending_acceptance": return "Pending Confirmation"
        case "ready": return "Ready to Fight"
        case "fighting": return "Fighting!"
        case "complete": return "Complete"
        case "cancelled": return "Cancelled"
        case "declined": return "Declined"
        case "expired": return "Expired"
        default: return status
        }
    }
    
    // MARK: - Convenience Accessors (use server values, fallback to legacy)
    
    /// Your name (from server perspective)
    var myName: String { you?.name ?? "You" }
    
    /// Opponent's name (from server perspective)
    var opponentName: String { opponentInfo?.name ?? opponent?.name ?? "Opponent" }
    
    /// Your attack stat
    var myAttack: Int { you?.attack ?? 0 }
    
    /// Your defense stat
    var myDefense: Int { you?.defense ?? 0 }
    
    /// Opponent's attack stat
    var opponentAttack: Int { opponentInfo?.attack ?? opponent?.stats?.attack ?? 0 }
    
    /// Opponent's defense stat
    var opponentDefense: Int { opponentInfo?.defense ?? opponent?.stats?.defense ?? 0 }
}

/// Duel challenge from another player
struct DuelInvitation: Codable, Identifiable {
    let invitationId: Int
    let matchId: Int
    let inviterId: Int
    let inviterName: String
    let wagerGold: Int
    let kingdomId: String
    let challengerStats: DuelPlayerStats?
    let createdAt: String?
    
    var id: Int { invitationId }
    
    enum CodingKeys: String, CodingKey {
        case invitationId = "invitation_id"
        case matchId = "match_id"
        case inviterId = "inviter_id"
        case inviterName = "inviter_name"
        case wagerGold = "wager_gold"
        case kingdomId = "kingdom_id"
        case challengerStats = "challenger_stats"
        case createdAt = "created_at"
    }
}

/// Player's lifetime duel stats
struct DuelStats: Codable {
    let userId: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let totalMatches: Int
    let winRate: Double
    let totalGoldWon: Int
    let totalGoldLost: Int
    let winStreak: Int
    let bestWinStreak: Int
    let lastDuelAt: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case wins
        case losses
        case draws
        case totalMatches = "total_matches"
        case winRate = "win_rate"
        case totalGoldWon = "total_gold_won"
        case totalGoldLost = "total_gold_lost"
        case winStreak = "win_streak"
        case bestWinStreak = "best_win_streak"
        case lastDuelAt = "last_duel_at"
    }
    
    var winRatePercent: Int {
        Int(winRate * 100)
    }
}

/// Leaderboard entry
struct DuelLeaderboardEntry: Codable, Identifiable {
    let userId: Int
    let displayName: String
    let wins: Int
    let losses: Int
    let totalMatches: Int
    let winRate: Double
    let winStreak: Int
    let bestWinStreak: Int
    
    var id: Int { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case wins
        case losses
        case totalMatches = "total_matches"
        case winRate = "win_rate"
        case winStreak = "win_streak"
        case bestWinStreak = "best_win_streak"
    }
}

// MARK: - API Response Models

struct DuelResponse: Codable {
    let success: Bool
    let message: String
    let match: DuelMatch?
}

struct DuelAttackResponse: Codable {
    let success: Bool
    let message: String
    
    // Single swing data
    let roll: DuelRoll?
    let swingNumber: Int?
    let swingsRemaining: Int?
    let maxSwings: Int?
    let currentBestOutcome: String?
    let currentBestPush: Double?
    let allRolls: [DuelRoll]?
    let isLastSwing: Bool?
    let turnComplete: Bool?
    
    // Final action (only on last swing)
    let action: DuelActionResult?
    let match: DuelMatch?
    let winner: DuelWinner?
    let nextTurn: DuelNextTurn?
    let gameOver: Bool?
    
    // Odds
    let missChance: Int?
    let hitChancePct: Int?
    let critChance: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, roll, action, match, winner
        case swingNumber = "swing_number"
        case swingsRemaining = "swings_remaining"
        case maxSwings = "max_swings"
        case currentBestOutcome = "current_best_outcome"
        case currentBestPush = "current_best_push"
        case allRolls = "all_rolls"
        case isLastSwing = "is_last_swing"
        case turnComplete = "turn_complete"
        case nextTurn = "next_turn"
        case gameOver = "game_over"
        case missChance = "miss_chance"
        case hitChancePct = "hit_chance_pct"
        case critChance = "crit_chance"
    }
}

// MARK: - Swing-by-Swing Response Models

/// Response from executing ONE swing
struct DuelSwingResponse: Codable {
    let success: Bool
    let message: String
    let roll: DuelRoll?
    let outcome: String?
    let swingNumber: Int?
    let swingsRemaining: Int?
    let maxSwings: Int?
    let bestOutcome: String?
    let canSwing: Bool?
    let canStop: Bool?
    let autoSubmitted: Bool?
    let roundResolved: Bool?
    let resolution: DuelRoundResolution?
    let match: DuelMatch?
    let missChance: Int?
    let hitChancePct: Int?
    let critChance: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, roll, outcome, match, resolution
        case swingNumber = "swing_number"
        case swingsRemaining = "swings_remaining"
        case maxSwings = "max_swings"
        case bestOutcome = "best_outcome"
        case canSwing = "can_swing"
        case canStop = "can_stop"
        case autoSubmitted = "auto_submitted"
        case roundResolved = "round_resolved"
        case missChance = "miss_chance"
        case hitChancePct = "hit_chance_pct"
        case critChance = "crit_chance"
    }
}

/// Response from stopping (locking in best roll)
struct DuelStopResponse: Codable {
    let success: Bool
    let message: String
    let submitted: Bool?
    let bestOutcome: String?
    let waitingForOpponent: Bool?
    let roundResolved: Bool?
    let resolution: DuelRoundResolution?
    let match: DuelMatch?
    
    enum CodingKeys: String, CodingKey {
        case success, message, match, resolution
        case submitted
        case bestOutcome = "best_outcome"
        case waitingForOpponent = "waiting_for_opponent"
        case roundResolved = "round_resolved"
    }
}

/// Tiebreaker data for feint animation
struct DuelTiebreaker: Codable {
    let type: String?           // "feint_vs_feint" or "feint_wins"
    let winner: String?         // "challenger" or "opponent"
    let feintSide: String?      // Which side had feint (for feint_wins type)
    let challengerRoll: Double? // Roll value as percentage (0-100) for display
    let opponentRoll: Double?   // Roll value as percentage (0-100) for display
    
    enum CodingKeys: String, CodingKey {
        case type, winner
        case feintSide = "feint_side"
        case challengerRoll = "challenger_roll"
        case opponentRoll = "opponent_roll"
    }
    
    /// Whether this is a feint vs feint tiebreaker (shows roll numbers)
    var isFeintVsFeint: Bool {
        type == "feint_vs_feint"
    }
}

/// Round resolution data
struct DuelRoundResolution: Codable {
    let roundNumber: Int?
    let challengerBest: String?
    let opponentBest: String?
    let challengerRolls: [[String: AnyCodable]]?
    let opponentRolls: [[String: AnyCodable]]?
    let challengerStyle: String?
    let opponentStyle: String?
    let winnerSide: String?
    let decisiveOutcome: String?
    let feintWinner: String?
    let tiebreaker: DuelTiebreaker?  // Tiebreaker animation data
    let parried: Bool?
    let pushAmount: Double?
    let barBefore: Double?
    let barAfter: Double?
    let matchWinner: String?
    let gameOver: Bool?
    
    enum CodingKeys: String, CodingKey {
        case roundNumber = "round_number"
        case challengerBest = "challenger_best"
        case opponentBest = "opponent_best"
        case challengerRolls = "challenger_rolls"
        case opponentRolls = "opponent_rolls"
        case challengerStyle = "challenger_style"
        case opponentStyle = "opponent_style"
        case winnerSide = "winner_side"
        case decisiveOutcome = "decisive_outcome"
        case feintWinner = "feint_winner"
        case tiebreaker
        case parried
        case pushAmount = "push_amount"
        case barBefore = "bar_before"
        case barAfter = "bar_after"
        case matchWinner = "match_winner"
        case gameOver = "game_over"
    }
}

// MARK: - Legacy Round System Response

struct DuelRoundSwingResponse: Codable {
    let success: Bool
    let status: String?
    let message: String

    let roundNumber: Int?
    let roundExpiresAt: String?

    let yourRolls: [DuelRoll]?
    let opponentRolls: [DuelRoll]?

    let result: [String: AnyCodable]?
    let push: [String: AnyCodable]?
    let styles: [String: AnyCodable]?

    let match: DuelMatch?
    let winner: DuelWinner?
    let gameOver: Bool?

    let missChance: Int?
    let hitChancePct: Int?
    let critChance: Int?

    enum CodingKeys: String, CodingKey {
        case success, status, message, match, winner, result, push, styles
        case roundNumber = "round_number"
        case roundExpiresAt = "round_expires_at"
        case yourRolls = "your_rolls"
        case opponentRolls = "opponent_rolls"
        case gameOver = "game_over"
        case missChance = "miss_chance"
        case hitChancePct = "hit_chance_pct"
        case critChance = "crit_chance"
    }
}

/// Response from locking an attack style
struct DuelLockStyleResponse: Codable {
    let success: Bool
    let message: String
    let style: String?
    let bothStylesLocked: Bool?
    let match: DuelMatch?
    
    enum CodingKeys: String, CodingKey {
        case success, message, style, match
        case bothStylesLocked = "both_styles_locked"
    }
}

// Note: AnyCodable is defined in PlayerModels.swift - do not duplicate here

struct DuelNextTurn: Codable {
    let playerId: Int?
    let side: String?
    let expiresAt: String?
    let timeoutSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case side
        case expiresAt = "expires_at"
        case timeoutSeconds = "timeout_seconds"
    }
}

struct DuelRoll: Codable {
    let rollNumber: Int
    let value: Double
    let outcome: String
    
    enum CodingKeys: String, CodingKey {
        case rollNumber = "roll_number"
        case value, outcome
    }
}

struct DuelActionResult: Codable {
    let playerId: Int
    let side: String
    let outcome: String
    let pushAmount: Double
    let barBefore: Double
    let barAfter: Double
    
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case side
        case outcome
        case pushAmount = "push_amount"
        case barBefore = "bar_before"
        case barAfter = "bar_after"
    }
}

struct DuelInvitationsResponse: Codable {
    let success: Bool
    let invitations: [DuelInvitation]
}

struct DuelStatsResponse: Codable {
    let success: Bool
    let stats: DuelStats?
}

struct DuelLeaderboardResponse: Codable {
    let success: Bool
    let leaderboard: [DuelLeaderboardEntry]
}

struct DuelRecentMatchesResponse: Codable {
    let success: Bool
    let matches: [DuelMatch]
}

struct DuelPendingCountResponse: Codable {
    let count: Int
}
