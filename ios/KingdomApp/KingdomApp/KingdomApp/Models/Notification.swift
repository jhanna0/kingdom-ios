import Foundation

// MARK: - Notification Models

struct ActivityNotification: Codable, Identifiable {
    let id = UUID()
    let type: NotificationType
    let priority: NotificationPriority
    let title: String
    let message: String
    let action: String
    let actionId: String?
    let createdAt: String
    let coupData: CoupNotificationData?
    let invasionData: InvasionNotificationData?
    let eventData: KingdomEventData?
    let allianceData: AllianceNotificationData?
    
    // DYNAMIC from backend - no switch statements needed!
    let icon: String?  // SF Symbol name from backend
    let iconColor: String?  // Theme color name from backend
    let priorityColor: String?  // Priority-based color from backend
    let borderColor: String?  // Border color from backend
    
    enum CodingKeys: String, CodingKey {
        case type, priority, title, message, action
        case actionId = "action_id"
        case createdAt = "created_at"
        case coupData = "coup_data"
        case invasionData = "invasion_data"
        case eventData = "event_data"
        case allianceData = "alliance_data"
        case icon
        case iconColor = "icon_color"
        case priorityColor = "priority_color"
        case borderColor = "border_color"
    }
    
    enum NotificationType: String, Codable {
        case contractReady = "contract_ready"
        case treasuryFull = "treasury_full"
        case levelUp = "level_up"
        case skillPoints = "skill_points"
        case checkinReady = "checkin_ready"
        // Coup V2 - Pledge phase
        case coupPledgeNeeded = "coup_pledge_needed"
        case coupPledgeWaiting = "coup_pledge_waiting"
        case coupAgainstYou = "coup_against_you"
        // Coup V2 - Battle phase
        case coupBattleActive = "coup_battle_active"
        case coupBattleAgainstYou = "coup_battle_against_you"
        // Coup - Resolution
        case coupResolved = "coup_resolved"
        // Legacy (for backwards compatibility)
        case coupVoteNeeded = "coup_vote_needed"
        case coupInProgress = "coup_in_progress"
        // Invasions
        case invasionAgainstYou = "invasion_against_you"
        case allyUnderAttack = "ally_under_attack"
        case invasionDefenseNeeded = "invasion_defense_needed"
        case invasionInProgress = "invasion_in_progress"
        case invasionResolved = "invasion_resolved"
        // Kingdom events
        case kingdomEvent = "kingdom_event"
        // Alliance events
        case allianceRequestReceived = "alliance_request_received"
        case allianceRequestSent = "alliance_request_sent"
        case allianceAccepted = "alliance_accepted"
        case allianceDeclined = "alliance_declined"
    }
    
    enum NotificationPriority: String, Codable {
        case critical
        case high
        case medium
        case low
        
        var color: String {
            switch self {
            case .critical: return "red"
            case .high: return "orange"
            case .medium: return "yellow"
            case .low: return "gray"
            }
        }
    }
}

// MARK: - Coup V2 Models

/// Full character sheet for the coup initiator
struct InitiatorStats: Codable {
    let level: Int
    let kingdomReputation: Int
    let attackPower: Int
    let defensePower: Int
    let leadership: Int
    let buildingSkill: Int
    let intelligence: Int
    let contractsCompleted: Int
    let totalWorkContributed: Int
    let coupsWon: Int
    let coupsFailed: Int
    
    enum CodingKeys: String, CodingKey {
        case level
        case kingdomReputation = "kingdom_reputation"
        case attackPower = "attack_power"
        case defensePower = "defense_power"
        case leadership
        case buildingSkill = "building_skill"
        case intelligence
        case contractsCompleted = "contracts_completed"
        case totalWorkContributed = "total_work_contributed"
        case coupsWon = "coups_won"
        case coupsFailed = "coups_failed"
    }
}

/// A player participating in a coup, with stats for display
struct CoupParticipant: Codable, Identifiable {
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

struct CoupNotificationData: Codable, Identifiable {
    let id: Int
    let kingdomId: String
    let kingdomName: String
    let initiatorName: String
    let initiatorStats: InitiatorStats?
    let status: String  // 'pledge', 'battle', 'resolved'
    let timeRemainingSeconds: Int
    let attackerCount: Int
    let defenderCount: Int
    let userSide: String?
    let canPledge: Bool
    let attackerVictory: Bool?
    let userWon: Bool?
    let goldPerWinner: Int?
    let isNewRuler: Bool?  // True if this user just became ruler via coup
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case initiatorName = "initiator_name"
        case initiatorStats = "initiator_stats"
        case status
        case timeRemainingSeconds = "time_remaining_seconds"
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
        case userSide = "user_side"
        case canPledge = "can_pledge"
        case attackerVictory = "attacker_victory"
        case userWon = "user_won"
        case goldPerWinner = "gold_per_winner"
        case isNewRuler = "is_new_ruler"
    }
    
    /// Formatted time remaining in current phase
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
    
    /// Is this coup in pledge phase?
    var isPledgePhase: Bool {
        status == "pledge"
    }
    
    /// Is this coup in battle phase?
    var isBattlePhase: Bool {
        status == "battle"
    }
    
    /// Is this coup resolved?
    var isResolved: Bool {
        status == "resolved"
    }
}

struct InvasionNotificationData: Codable, Identifiable {
    let id: Int
    let targetKingdomId: String
    let targetKingdomName: String
    let attackingFromKingdomId: String
    let attackingFromKingdomName: String
    let initiatorName: String
    let timeRemainingSeconds: Int
    let attackerCount: Int
    let defenderCount: Int
    let userSide: String?
    let canJoin: Bool
    let attackerVictory: Bool?
    let userWon: Bool?
    let userWasAttacker: Bool?
    let userIsRuler: Bool?
    let isAllied: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case targetKingdomId = "target_kingdom_id"
        case targetKingdomName = "target_kingdom_name"
        case attackingFromKingdomId = "attacking_from_kingdom_id"
        case attackingFromKingdomName = "attacking_from_kingdom_name"
        case initiatorName = "initiator_name"
        case timeRemainingSeconds = "time_remaining_seconds"
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
        case userSide = "user_side"
        case canJoin = "can_join"
        case attackerVictory = "attacker_victory"
        case userWon = "user_won"
        case userWasAttacker = "user_was_attacker"
        case userIsRuler = "user_is_ruler"
        case isAllied = "is_allied"
    }
    
    var timeRemainingFormatted: String {
        let minutes = timeRemainingSeconds / 60
        let seconds = timeRemainingSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Alliance Notification Data

struct AllianceNotificationData: Codable, Identifiable {
    let id: Int
    let initiatorEmpireId: String?
    let initiatorEmpireName: String?
    let initiatorRulerName: String?
    let targetEmpireId: String?
    let targetEmpireName: String?
    let otherEmpireId: String?
    let otherEmpireName: String?
    let otherRulerName: String?
    let hoursToRespond: Int?
    let daysRemaining: Int?
    let createdAt: String?
    let proposalExpiresAt: String?
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case initiatorEmpireId = "initiator_empire_id"
        case initiatorEmpireName = "initiator_empire_name"
        case initiatorRulerName = "initiator_ruler_name"
        case targetEmpireId = "target_empire_id"
        case targetEmpireName = "target_empire_name"
        case otherEmpireId = "other_empire_id"
        case otherEmpireName = "other_empire_name"
        case otherRulerName = "other_ruler_name"
        case hoursToRespond = "hours_to_respond"
        case daysRemaining = "days_remaining"
        case createdAt = "created_at"
        case proposalExpiresAt = "proposal_expires_at"
        case expiresAt = "expires_at"
    }
    
    var hoursToRespondFormatted: String {
        guard let hours = hoursToRespond else { return "Unknown" }
        if hours > 24 {
            let days = hours / 24
            return "\(days) days"
        } else {
            return "\(hours) hours"
        }
    }
}

// MARK: - Kingdom Event Data

struct KingdomEventData: Codable {
    let eventId: Int
    let eventType: String
    let rulerName: String
    let message: String
    let oldValue: Int?
    let newValue: Int?
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventType = "event_type"
        case rulerName = "ruler_name"
        case message
        case oldValue = "old_value"
        case newValue = "new_value"
    }
}

// MARK: - Activity Response

struct ActivityResponse: Codable {
    let success: Bool
    let summary: ActivitySummary
    let notifications: [ActivityNotification]
    let contracts: ContractActivity
    let kingdoms: [ActivityKingdomUpdate]
    let unreadKingdomEvents: Int?
    let serverTime: String
    
    enum CodingKeys: String, CodingKey {
        case success, summary, notifications, contracts, kingdoms
        case unreadKingdomEvents = "unread_kingdom_events"
        case serverTime = "server_time"
    }
}

struct ActivitySummary: Codable {
    let gold: Int
    let level: Int
    let experience: Int
    let xpToNextLevel: Int
    let skillPoints: Int
    let reputation: Int
    let kingdomsRuled: Int
    let activeContracts: Int
    let readyContracts: Int
    
    enum CodingKeys: String, CodingKey {
        case gold, level, experience, reputation
        case xpToNextLevel = "xp_to_next_level"
        case skillPoints = "skill_points"
        case kingdomsRuled = "kingdoms_ruled"
        case activeContracts = "active_contracts"
        case readyContracts = "ready_contracts"
    }
}

struct ContractActivity: Codable {
    let readyToComplete: [ActivityReadyContract]
    let inProgress: [ActivityProgressContract]
    
    enum CodingKeys: String, CodingKey {
        case readyToComplete = "ready_to_complete"
        case inProgress = "in_progress"
    }
}

struct ActivityReadyContract: Codable, Identifiable {
    let id: Int
    let kingdomName: String
    let buildingType: String
    let buildingLevel: Int
    let reward: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomName = "kingdom_name"
        case buildingType = "building_type"
        case buildingLevel = "building_level"
        case reward
    }
}

struct ActivityProgressContract: Codable, Identifiable {
    let id: Int
    let kingdomName: String
    let buildingType: String
    let progress: Double
    let actionsRemaining: Int
    let actionsCompleted: Int
    let totalActionsRequired: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomName = "kingdom_name"
        case buildingType = "building_type"
        case progress
        case actionsRemaining = "actions_remaining"
        case actionsCompleted = "actions_completed"
        case totalActionsRequired = "total_actions_required"
    }
}

struct ActivityKingdomUpdate: Codable, Identifiable {
    let id: String
    let name: String
    let level: Int
    let population: Int
    let treasury: Int
    let openContracts: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, level, population, treasury
        case openContracts = "open_contracts"
    }
}

