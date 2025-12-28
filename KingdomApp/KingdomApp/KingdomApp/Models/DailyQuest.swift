import Foundation

// MARK: - Daily Quest System
// Ruler-issued objectives for kingdom subjects

enum QuestType: String, Codable, CaseIterable {
    case mineResources = "Mine Resources"
    case craftWeapons = "Craft Weapons"
    case craftArmor = "Craft Armor"
    case maintainStreak = "Maintain Check-in Streak"
    case contributeToBuild = "Contribute to Buildings"
    case prepareForWar = "Prepare for War"
    case defendKingdom = "Defend the Realm"
    case tradeGoods = "Complete Trades"
    
    var icon: String {
        switch self {
        case .mineResources: return "⛏️"
        case .craftWeapons: return "🗡️"
        case .craftArmor: return "🛡️"
        case .maintainStreak: return "🔥"
        case .contributeToBuild: return "🔨"
        case .prepareForWar: return "⚔️"
        case .defendKingdom: return "🏰"
        case .tradeGoods: return "💰"
        }
    }
    
    var description: String {
        switch self {
        case .mineResources: return "Gather iron and steel from the mines"
        case .craftWeapons: return "Forge weapons for the kingdom's arsenal"
        case .craftArmor: return "Create protective equipment"
        case .maintainStreak: return "Check in daily without missing a day"
        case .contributeToBuild: return "Help upgrade kingdom structures"
        case .prepareForWar: return "Ready yourself for the coming battle"
        case .defendKingdom: return "Stand ready to defend against attacks"
        case .tradeGoods: return "Engage in commerce with fellow subjects"
        }
    }
}

enum QuestScope: String, Codable {
    case individual  // Each person must complete on their own
    case collective  // Kingdom-wide goal (all contributions count)
}

struct DailyQuest: Identifiable, Codable, Hashable {
    let id: String
    let kingdomId: String
    let kingdomName: String
    let type: QuestType
    let scope: QuestScope
    
    // Quest requirements
    let title: String
    let description: String
    let targetAmount: Int  // e.g., "Mine 100 iron" -> 100
    let targetUnit: String  // e.g., "iron", "weapons", "days"
    
    // Rewards
    let goldReward: Int  // Split among participants for collective
    let reputationReward: Int  // Per participant
    
    // Progress tracking
    var currentProgress: Int = 0
    var participants: Set<String> = []  // Player IDs who contributed
    var participantProgress: [String: Int] = [:]  // Individual progress
    
    // Timing
    let createdAt: Date
    let expiresAt: Date  // Usually end of week
    var completedAt: Date?
    let createdBy: String  // Ruler's player ID
    
    // Status
    var isComplete: Bool {
        return currentProgress >= targetAmount
    }
    
    var progress: Double {
        return min(1.0, Double(currentProgress) / Double(targetAmount))
    }
    
    var timeRemaining: TimeInterval {
        return max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var goldPerParticipant: Int {
        guard !participants.isEmpty else { return goldReward }
        return goldReward / participants.count
    }
    
    // MARK: - Mutations
    
    mutating func contribute(playerId: String, amount: Int) {
        participants.insert(playerId)
        currentProgress += amount
        participantProgress[playerId, default: 0] += amount
        
        if isComplete && completedAt == nil {
            completedAt = Date()
        }
    }
    
    // MARK: - Factory Methods
    
    static func createMiningQuest(
        kingdomId: String,
        kingdomName: String,
        targetIron: Int,
        goldReward: Int,
        createdBy: String
    ) -> DailyQuest {
        return DailyQuest(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            type: .mineResources,
            scope: .collective,
            title: "Mine \(targetIron) Iron This Week",
            description: "The forges hunger for ore! All subjects contribute to the mining quota.",
            targetAmount: targetIron,
            targetUnit: "iron",
            goldReward: goldReward,
            reputationReward: 10,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(7 * 24 * 3600),  // 1 week
            createdBy: createdBy
        )
    }
    
    static func createCraftingQuest(
        kingdomId: String,
        kingdomName: String,
        targetWeapons: Int,
        goldReward: Int,
        createdBy: String
    ) -> DailyQuest {
        return DailyQuest(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            type: .craftWeapons,
            scope: .collective,
            title: "\(targetWeapons) Subjects Craft Weapons",
            description: "The army needs arms! Craftsmen, to your anvils!",
            targetAmount: targetWeapons,
            targetUnit: "weapons",
            goldReward: goldReward,
            reputationReward: 15,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
            createdBy: createdBy
        )
    }
    
    static func createStreakQuest(
        kingdomId: String,
        kingdomName: String,
        targetPlayers: Int,
        streakDays: Int,
        goldReward: Int,
        createdBy: String
    ) -> DailyQuest {
        return DailyQuest(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            type: .maintainStreak,
            scope: .collective,
            title: "\(targetPlayers) Subjects Maintain \(streakDays)-Day Streak",
            description: "Loyalty is shown through presence. Check in daily!",
            targetAmount: targetPlayers,
            targetUnit: "players",
            goldReward: goldReward,
            reputationReward: 20,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(Double(streakDays) * 24 * 3600),
            createdBy: createdBy
        )
    }
    
    static func createWarPreparationQuest(
        kingdomId: String,
        kingdomName: String,
        requiredCheckIns: Int,
        createdBy: String
    ) -> DailyQuest {
        return DailyQuest(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            type: .prepareForWar,
            scope: .individual,
            title: "Prepare for War",
            description: "Check in daily for \(requiredCheckIns) days and join the upcoming invasion. Your signup fee will be paid by the ruler!",
            targetAmount: requiredCheckIns,
            targetUnit: "days",
            goldReward: 100,  // Free invasion signup
            reputationReward: 25,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(Double(requiredCheckIns + 1) * 24 * 3600),
            createdBy: createdBy
        )
    }
    
    static func createBuildingQuest(
        kingdomId: String,
        kingdomName: String,
        targetContributions: Int,
        goldReward: Int,
        createdBy: String
    ) -> DailyQuest {
        return DailyQuest(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            type: .contributeToBuild,
            scope: .collective,
            title: "Contribute \(targetContributions) Work Units",
            description: "Help upgrade our kingdom's fortifications!",
            targetAmount: targetContributions,
            targetUnit: "contributions",
            goldReward: goldReward,
            reputationReward: 10,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
            createdBy: createdBy
        )
    }
}

// MARK: - Sample Quests

extension DailyQuest {
    static let samples: [DailyQuest] = [
        DailyQuest(
            id: UUID().uuidString,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            type: .mineResources,
            scope: .collective,
            title: "Mine 100 Iron This Week",
            description: "The forges hunger for ore!",
            targetAmount: 100,
            targetUnit: "iron",
            goldReward: 500,
            reputationReward: 10,
            currentProgress: 45,
            participants: ["player1", "player2", "player3"],
            participantProgress: ["player1": 20, "player2": 15, "player3": 10],
            createdAt: Date().addingTimeInterval(-2 * 24 * 3600),
            expiresAt: Date().addingTimeInterval(5 * 24 * 3600),
            createdBy: "ruler1"
        ),
        DailyQuest(
            id: UUID().uuidString,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            type: .craftWeapons,
            scope: .collective,
            title: "5 Subjects Craft Weapons",
            description: "The army needs arms!",
            targetAmount: 5,
            targetUnit: "weapons",
            goldReward: 750,
            reputationReward: 15,
            currentProgress: 2,
            participants: ["player1", "player4"],
            participantProgress: ["player1": 1, "player4": 1],
            createdAt: Date().addingTimeInterval(-1 * 24 * 3600),
            expiresAt: Date().addingTimeInterval(6 * 24 * 3600),
            createdBy: "ruler1"
        ),
        DailyQuest(
            id: UUID().uuidString,
            kingdomId: "kingdom2",
            kingdomName: "Riverwatch",
            type: .maintainStreak,
            scope: .collective,
            title: "10 Subjects Maintain 7-Day Streak",
            description: "Loyalty is shown through presence!",
            targetAmount: 10,
            targetUnit: "players",
            goldReward: 1000,
            reputationReward: 20,
            currentProgress: 7,
            participants: ["player1", "player2", "player3", "player4", "player5", "player6", "player7"],
            participantProgress: [:],
            createdAt: Date().addingTimeInterval(-3 * 24 * 3600),
            expiresAt: Date().addingTimeInterval(4 * 24 * 3600),
            createdBy: "ruler2"
        )
    ]
}

