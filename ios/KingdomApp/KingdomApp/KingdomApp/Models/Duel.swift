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

/// A duel attack action
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

/// A duel match
struct DuelMatch: Codable, Identifiable {
    let id: Int
    let matchCode: String
    let kingdomId: String
    let status: String
    
    let challenger: DuelPlayer
    let opponent: DuelPlayer?
    
    let controlBar: Double
    let currentTurn: String?
    let turnExpiresAt: String?
    
    let wagerGold: Int
    
    let winner: DuelWinner?
    
    let createdAt: String?
    let startedAt: String?
    let completedAt: String?
    let expiresAt: String?
    
    // Optional actions (included when fetching full match)
    let actions: [DuelAction]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchCode = "match_code"
        case kingdomId = "kingdom_id"
        case status
        case challenger
        case opponent
        case controlBar = "control_bar"
        case currentTurn = "current_turn"
        case turnExpiresAt = "turn_expires_at"
        case wagerGold = "wager_gold"
        case winner
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case expiresAt = "expires_at"
        case actions
    }
    
    // MARK: - Computed Properties
    
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
    
    /// Can an opponent join this match?
    var canJoin: Bool {
        isWaiting && opponent == nil
    }
    
    /// Does challenger need to confirm/decline the opponent?
    var needsChallengerConfirmation: Bool {
        isPendingAcceptance
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
    
    var statusColor: String {
        switch status {
        case "waiting": return "orange"
        case "ready": return "blue"
        case "fighting": return "red"
        case "complete": return "green"
        case "cancelled", "expired": return "gray"
        default: return "gray"
        }
    }
    
    /// Check if it's a specific player's turn
    func isPlayersTurn(playerId: Int) -> Bool {
        guard isFighting else { return false }
        if currentTurn == "challenger" {
            return challenger.id == playerId
        } else if currentTurn == "opponent" {
            return opponent?.id == playerId
        }
        return false
    }
    
    /// Get which side a player is on
    func playerSide(playerId: Int) -> String? {
        if challenger.id == playerId { return "challenger" }
        if opponent?.id == playerId { return "opponent" }
        return nil
    }
    
    /// Bar position from a player's perspective (0-100, where 100 = winning)
    func barForPlayer(playerId: Int) -> Double {
        let side = playerSide(playerId: playerId)
        if side == "challenger" {
            // Challenger wins at bar = 0, so invert
            return 100 - controlBar
        } else {
            // Opponent wins at bar = 100
            return controlBar
        }
    }
}

/// Duel invitation from another player
struct DuelInvitation: Codable, Identifiable {
    let invitationId: Int
    let matchId: Int
    let matchCode: String
    let inviterId: Int
    let inviterName: String
    let wagerGold: Int
    let kingdomId: String
    let createdAt: String?
    
    var id: Int { invitationId }
    
    enum CodingKeys: String, CodingKey {
        case invitationId = "invitation_id"
        case matchId = "match_id"
        case matchCode = "match_code"
        case inviterId = "inviter_id"
        case inviterName = "inviter_name"
        case wagerGold = "wager_gold"
        case kingdomId = "kingdom_id"
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
    let action: DuelActionResult?
    let match: DuelMatch?
    let winner: DuelWinner?
}

struct DuelActionResult: Codable {
    let playerId: Int
    let side: String
    let rollValue: Double
    let hitChance: Double
    let outcome: String
    let pushAmount: Double
    let barBefore: Double
    let barAfter: Double
    
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case side
        case rollValue = "roll_value"
        case hitChance = "hit_chance"
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
