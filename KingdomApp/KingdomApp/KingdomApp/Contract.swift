import Foundation

// MARK: - Contract System
// EVE Online-inspired contracts for kingdom building

struct Contract: Identifiable, Codable, Hashable {
    let id: String
    let kingdomId: String
    let kingdomName: String
    
    // What's being built
    let buildingType: String
    let buildingLevel: Int
    
    // Work requirements
    let totalWorkRequired: Int // Total work points needed
    var workCompleted: Int // Current progress
    
    // Rewards
    let rewardPool: Int // Total gold to distribute
    
    // Contributors: playerID -> work contributed
    var contributors: [String: Int]
    
    // Status
    let createdBy: String // Ruler's player ID
    let createdAt: Date
    var status: ContractStatus
    
    enum ContractStatus: String, Codable {
        case open
        case inProgress
        case completed
        case expired
    }
    
    // Computed properties
    var progress: Double {
        guard totalWorkRequired > 0 else { return 0 }
        return Double(workCompleted) / Double(totalWorkRequired)
    }
    
    var isComplete: Bool {
        workCompleted >= totalWorkRequired
    }
    
    var goldPerWorkPoint: Double {
        guard totalWorkRequired > 0 else { return 0 }
        return Double(rewardPool) / Double(totalWorkRequired)
    }
    
    // Calculate reward for a specific player
    func rewardForPlayer(_ playerId: String) -> Int {
        guard let contribution = contributors[playerId] else { return 0 }
        return Int(Double(contribution) * goldPerWorkPoint)
    }
}

// MARK: - Sample Data
extension Contract {
    static let sample = Contract(
        id: UUID().uuidString,
        kingdomId: "kingdom1",
        kingdomName: "Ashford",
        buildingType: "Market",
        buildingLevel: 2,
        totalWorkRequired: 1000,
        workCompleted: 350,
        rewardPool: 5000,
        contributors: [
            "player1": 200,
            "player2": 150
        ],
        createdBy: "ruler1",
        createdAt: Date(),
        status: .inProgress
    )
    
    static let samples = [
        Contract(
            id: UUID().uuidString,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            buildingType: "Market",
            buildingLevel: 2,
            totalWorkRequired: 1000,
            workCompleted: 350,
            rewardPool: 5000,
            contributors: ["player1": 200, "player2": 150],
            createdBy: "ruler1",
            createdAt: Date(),
            status: .inProgress
        ),
        Contract(
            id: UUID().uuidString,
            kingdomId: "kingdom2",
            kingdomName: "Riverwatch",
            buildingType: "Barracks",
            buildingLevel: 3,
            totalWorkRequired: 2500,
            workCompleted: 0,
            rewardPool: 12000,
            contributors: [:],
            createdBy: "ruler2",
            createdAt: Date(),
            status: .open
        ),
        Contract(
            id: UUID().uuidString,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            buildingType: "Keep",
            buildingLevel: 4,
            totalWorkRequired: 5000,
            workCompleted: 1200,
            rewardPool: 25000,
            contributors: ["player1": 500, "player3": 700],
            createdBy: "ruler1",
            createdAt: Date().addingTimeInterval(-86400),
            status: .inProgress
        )
    ]
}

