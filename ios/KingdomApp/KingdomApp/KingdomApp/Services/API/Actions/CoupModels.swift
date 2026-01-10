import Foundation

// MARK: - Coup V2 API Models

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
    
    // Resolution
    let isResolved: Bool
    let attackerVictory: Bool?
    let resolvedAt: String?
    
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
        case isResolved = "is_resolved"
        case attackerVictory = "attacker_victory"
        case resolvedAt = "resolved_at"
    }
    
    /// Is this coup in pledge phase?
    var isPledgePhase: Bool {
        status == "pledge"
    }
    
    /// Is this coup in battle phase?
    var isBattlePhase: Bool {
        status == "battle"
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

