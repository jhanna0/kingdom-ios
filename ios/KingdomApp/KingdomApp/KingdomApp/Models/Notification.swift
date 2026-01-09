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
    
    enum CodingKeys: String, CodingKey {
        case type, priority, title, message, action
        case actionId = "action_id"
        case createdAt = "created_at"
        case coupData = "coup_data"
        case invasionData = "invasion_data"
        case eventData = "event_data"
    }
    
    enum NotificationType: String, Codable {
        case contractReady = "contract_ready"
        case treasuryFull = "treasury_full"
        case levelUp = "level_up"
        case skillPoints = "skill_points"
        case checkinReady = "checkin_ready"
        case coupVoteNeeded = "coup_vote_needed"
        case coupInProgress = "coup_in_progress"
        case coupAgainstYou = "coup_against_you"
        case coupResolved = "coup_resolved"
        case invasionAgainstYou = "invasion_against_you"
        case allyUnderAttack = "ally_under_attack"
        case invasionDefenseNeeded = "invasion_defense_needed"
        case invasionInProgress = "invasion_in_progress"
        case invasionResolved = "invasion_resolved"
        // Kingdom events
        case kingdomEvent = "kingdom_event"
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

struct InitiatorStats: Codable {
    let reputation: Int
    let kingdomReputation: Int
    let attackPower: Int
    let defensePower: Int
    let leadership: Int
    let buildingSkill: Int
    let intelligence: Int
    let contractsCompleted: Int
    let totalWorkContributed: Int
    let level: Int
    
    enum CodingKeys: String, CodingKey {
        case reputation
        case kingdomReputation = "kingdom_reputation"
        case attackPower = "attack_power"
        case defensePower = "defense_power"
        case leadership
        case buildingSkill = "building_skill"
        case intelligence
        case contractsCompleted = "contracts_completed"
        case totalWorkContributed = "total_work_contributed"
        case level
    }
}

struct CoupNotificationData: Codable, Identifiable {
    let id: Int
    let kingdomId: String
    let kingdomName: String
    let initiatorName: String
    let initiatorStats: InitiatorStats?
    let timeRemainingSeconds: Int
    let attackerCount: Int
    let defenderCount: Int
    let userSide: String?
    let canJoin: Bool
    let attackerVictory: Bool?
    let userWon: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case initiatorName = "initiator_name"
        case initiatorStats = "initiator_stats"
        case timeRemainingSeconds = "time_remaining_seconds"
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
        case userSide = "user_side"
        case canJoin = "can_join"
        case attackerVictory = "attacker_victory"
        case userWon = "user_won"
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

