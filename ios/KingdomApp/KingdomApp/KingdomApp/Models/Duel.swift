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
        case id, name, description, icon
        case rollBonus = "roll_bonus"
        case hitChanceMod = "hit_chance_mod"
        case critRateMod = "crit_rate_mod"
        case pushMultWin = "push_mult_win"
        case pushMultLose = "push_mult_lose"
        case opponentHitMod = "opponent_hit_mod"
        case winsTies = "wins_ties"
    }
    
    /// Human-readable summary of the style's effects
    var effectsSummary: [String] {
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
    let styleLockTimeoutSeconds: Int?  // Time for style selection phase
    let invitationTimeoutMinutes: Int
    
    // Combat multipliers (for display)
    let criticalMultiplier: Double  // e.g., 1.5
    let pushBasePercent: Double     // e.g., 4.0
    let leadershipBonusPercent: Double  // e.g., 20
    
    // Hit chance bounds
    let minHitChancePercent: Int
    let maxHitChancePercent: Int
    
    // Crit rate
    let critRatePercent: Int
    
    // Wager limits
    let maxWagerGold: Int
    
    // Animation timing (ms)
    let rollAnimationMs: Int
    let rollPauseBetweenMs: Int  // Pause between consecutive rolls
    let critPopupDurationMs: Int
    let rollSweepStepMs: Int
    let styleRevealDurationMs: Int?  // How long to show style reveal

    // Round pacing
    let maxRollsPerRoundCap: Int?
    
    // Attack styles - ALL definitions from server
    let attackStyles: [AttackStyleConfig]?
    let defaultStyle: String?
    
    enum CodingKeys: String, CodingKey {
        case duelMode = "duel_mode"
        case turnTimeoutSeconds = "turn_timeout_seconds"
        case roundTimeoutSeconds = "round_timeout_seconds"
        case styleLockTimeoutSeconds = "style_lock_timeout_seconds"
        case invitationTimeoutMinutes = "invitation_timeout_minutes"
        case criticalMultiplier = "critical_multiplier"
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
    }
    
    /// Formatted critical multiplier string (e.g., "1.5x")
    var criticalMultiplierText: String {
        return "\(criticalMultiplier)x"
    }
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

/// A duel match - now with player-perspective fields from server
struct DuelMatch: Codable, Identifiable {
    let id: Int
    let matchCode: String
    let kingdomId: String
    let status: String
    
    // === PLAYER PERSPECTIVE (server-computed, no client logic needed) ===
    
    /// Is it your turn? (server-computed)
    let isYourTurn: Bool?
    
    /// Can you attack right now? (server-computed: is_your_turn && is_fighting)
    let canAttack: Bool?
    
    /// Can you claim timeout victory? (server-computed: !is_your_turn && turn_expired)
    let canClaimTimeout: Bool?
    
    /// Bar position from YOUR perspective (0-100, higher = winning)
    let yourBarPosition: Double?

    // === ROUND SYSTEM (simultaneous; no turns) ===
    let roundNumber: Int?
    let roundExpiresAt: String?
    let canSubmitRound: Bool?
    let hasSubmittedRound: Bool?
    let opponentHasSubmittedRound: Bool?
    let yourRoundRollsCount: Int?
    
    // === ATTACK STYLE SYSTEM ===
    let inStylePhase: Bool?        // Are we in the style selection phase?
    let canLockStyle: Bool?        // Can the player lock a style right now?
    let myStyle: String?           // Your locked style (or nil)
    let myStyleLocked: Bool?       // Have you locked your style?
    let opponentStyleLocked: Bool? // Has opponent locked their style?
    let opponentStyle: String?     // Opponent's style (only revealed after both locked)
    let styleLockExpiresAt: String?
    let bothStylesLocked: Bool?
    
    /// Your swings used this turn
    let yourSwingsUsed: Int?
    
    /// Your swings remaining this turn
    let yourSwingsRemaining: Int?
    
    /// Your max swings this turn
    let yourMaxSwings: Int?
    
    /// Your info (from your perspective)
    let you: DuelPlayerInfo?
    
    /// Opponent info (from your perspective)
    let opponentInfo: DuelPlayerInfo?
    
    /// Current attacker's odds (for probability bar)
    let currentOdds: DuelOdds?
    
    /// Rolls this turn with attacker name
    let turnRolls: [DuelTurnRoll]?
    
    /// Winner from your perspective
    let winnerPerspective: DuelWinnerPerspective?
    
    // === METADATA ===
    let wagerGold: Int
    let turnExpiresAt: String?
    let createdAt: String?
    let startedAt: String?
    let completedAt: String?
    
    // === GAME CONFIG (from server - NO hardcoded frontend values!) ===
    let config: DuelGameConfig?
    
    // === LEGACY (for backwards compatibility during transition) ===
    let challenger: DuelPlayer  // Always present (non-optional)
    let opponent: DuelPlayer?   // Legacy format from "opponent_legacy" key
    let controlBar: Double?
    let currentTurn: String?
    
    // Old swing tracking (legacy)
    let turnSwingsUsed: Int?
    let turnMaxSwings: Int?
    let turnSwingsRemaining: Int?
    
    // Optional actions
    let actions: [DuelAction]?
    
    /// Legacy winner accessor (converts from perspective format)
    var winner: DuelWinner? {
        guard let wp = winnerPerspective else { return nil }
        return DuelWinner(id: wp.id, side: nil, goldEarned: wp.goldEarned)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchCode = "match_code"
        case kingdomId = "kingdom_id"
        case status
        
        // Player perspective (new format from to_dict_for_player)
        case isYourTurn = "is_your_turn"
        case canAttack = "can_attack"
        case canClaimTimeout = "can_claim_timeout"
        case yourBarPosition = "your_bar_position"

        // Round system
        case roundNumber = "round_number"
        case roundExpiresAt = "round_expires_at"
        case canSubmitRound = "can_submit_round"
        case hasSubmittedRound = "has_submitted_round"
        case opponentHasSubmittedRound = "opponent_has_submitted_round"
        case yourRoundRollsCount = "your_round_rolls_count"
        
        // Attack style system
        case inStylePhase = "in_style_phase"
        case canLockStyle = "can_lock_style"
        case myStyle = "my_style"
        case myStyleLocked = "my_style_locked"
        case opponentStyleLocked = "opponent_style_locked"
        case opponentStyle = "opponent_style"
        case styleLockExpiresAt = "style_lock_expires_at"
        case bothStylesLocked = "both_styles_locked"

        case yourSwingsUsed = "your_swings_used"
        case yourSwingsRemaining = "your_swings_remaining"
        case yourMaxSwings = "your_max_swings"
        case you
        case opponentInfo = "opponent"  // New format: simple {id, name, attack, defense}
        case currentOdds = "current_odds"
        case turnRolls = "turn_rolls"
        case winnerPerspective = "winner"
        
        // Metadata
        case wagerGold = "wager_gold"
        case turnExpiresAt = "turn_expires_at"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case config
        
        // Legacy (from to_dict - kept for backwards compatibility)
        case challenger
        case opponent = "opponent_legacy"  // Backend sends this as "opponent_legacy" in player-perspective view
        case controlBar = "control_bar"
        case currentTurn = "current_turn"
        // Note: winner is now a computed property that uses winnerPerspective
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

// MARK: - Round System Response Models

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
    let styles: [String: AnyCodable]?  // Style reveal after resolution

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
