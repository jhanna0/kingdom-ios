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
    
    // Time requirements (scaled by population and building level)
    let basePopulation: Int // Population when contract was created
    let baseHoursRequired: Double // Base time with ideal workers
    var workStartedAt: Date? // When first worker accepted
    
    // Rewards
    let rewardPool: Int // Total gold to distribute equally
    
    // Workers: playerIDs signed up (equal pay for all)
    var workers: Set<String>
    
    // Status
    let createdBy: String // Ruler's player ID
    let createdAt: Date
    var completedAt: Date?
    var status: ContractStatus
    
    enum ContractStatus: String, Codable {
        case open       // Posted, waiting for workers
        case inProgress // Workers signed up, timer running
        case completed  // Finished, building upgraded
        case cancelled  // Cancelled by ruler
    }
    
    // MARK: - Computed Properties
    
    var workerCount: Int {
        workers.count
    }
    
    var isComplete: Bool {
        status == .completed
    }
    
    /// Time to complete based on number of workers
    /// More workers = faster completion (parallel work)
    var hoursToComplete: Double {
        let idealWorkers = 3.0  // Ideal team size
        let workerMultiplier = idealWorkers / max(Double(workerCount), 1.0)
        return baseHoursRequired * workerMultiplier
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard let startTime = workStartedAt, status == .inProgress else {
            return status == .completed ? 1.0 : 0.0
        }
        
        let elapsed = Date().timeIntervalSince(startTime) / 3600.0 // hours
        let progress = elapsed / hoursToComplete
        return min(progress, 1.0)
    }
    
    /// Time remaining in hours
    var hoursRemaining: Double? {
        guard let startTime = workStartedAt, status == .inProgress else {
            return nil
        }
        
        let elapsed = Date().timeIntervalSince(startTime) / 3600.0
        let remaining = hoursToComplete - elapsed
        return max(remaining, 0.0)
    }
    
    /// Check if contract is ready to complete
    var isReadyToComplete: Bool {
        guard let remaining = hoursRemaining else { return false }
        return remaining <= 0.0
    }
    
    /// Reward per worker (equal split)
    var rewardPerWorker: Int {
        guard workerCount > 0 else { return 0 }
        return rewardPool / workerCount
    }
    
    // MARK: - Mutations
    
    /// Add a worker to the contract
    mutating func addWorker(_ playerId: String) {
        workers.insert(playerId)
        
        // Start timer if this is the first worker
        if workStartedAt == nil {
            workStartedAt = Date()
            status = .inProgress
        }
    }
    
    /// Remove a worker from the contract
    mutating func removeWorker(_ playerId: String) {
        workers.remove(playerId)
        
        // If no workers left, reset to open
        if workers.isEmpty {
            workStartedAt = nil
            status = .open
        }
    }
    
    /// Mark contract as completed
    mutating func complete() {
        status = .completed
        completedAt = Date()
    }
    
    // MARK: - Factory Method
    
    /// Create a new contract with time scaled by population and building level
    static func create(
        kingdomId: String,
        kingdomName: String,
        buildingType: String,
        buildingLevel: Int,
        population: Int,
        rewardPool: Int,
        createdBy: String
    ) -> Contract {
        // Scale time required based on building level and population
        // Higher levels = longer time
        // More population = more defensive structures needed = longer time
        
        // Base time with 3 ideal workers:
        // Level 1: 2-4 hours
        // Level 2: 4-8 hours
        // Level 3: 8-16 hours
        // Level 4: 16-32 hours
        // Level 5: 32-64 hours
        
        let baseHours = 2.0 * pow(2.0, Double(buildingLevel - 1))
        let populationMultiplier = 1.0 + (Double(population) / 30.0) // +33% time per 10 people
        let totalHours = baseHours * populationMultiplier
        
        return Contract(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            buildingType: buildingType,
            buildingLevel: buildingLevel,
            basePopulation: population,
            baseHoursRequired: totalHours,
            workStartedAt: nil,
            rewardPool: rewardPool,
            workers: [],
            createdBy: createdBy,
            createdAt: Date(),
            completedAt: nil,
            status: .open
        )
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
        basePopulation: 15,
        baseHoursRequired: 4.0,
        workStartedAt: Date().addingTimeInterval(-7200), // Started 2 hours ago
        rewardPool: 500,
        workers: ["player1", "player2"],
        createdBy: "ruler1",
        createdAt: Date().addingTimeInterval(-10800),
        completedAt: nil,
        status: .inProgress
    )
    
    static let samples = [
        Contract(
            id: UUID().uuidString,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            buildingType: "Market",
            buildingLevel: 2,
            basePopulation: 15,
            baseHoursRequired: 4.0,
            workStartedAt: Date().addingTimeInterval(-7200), // Started 2 hours ago
            rewardPool: 500,
            workers: ["player1", "player2"],
            createdBy: "ruler1",
            createdAt: Date().addingTimeInterval(-10800),
            completedAt: nil,
            status: .inProgress
        ),
        Contract(
            id: UUID().uuidString,
            kingdomId: "kingdom2",
            kingdomName: "Riverwatch",
            buildingType: "Walls",
            buildingLevel: 3,
            basePopulation: 25,
            baseHoursRequired: 10.0,
            workStartedAt: nil,
            rewardPool: 800,
            workers: [],
            createdBy: "ruler2",
            createdAt: Date(),
            completedAt: nil,
            status: .open
        ),
        Contract(
            id: UUID().uuidString,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            buildingType: "Vault",
            buildingLevel: 4,
            basePopulation: 20,
            baseHoursRequired: 20.0,
            workStartedAt: Date().addingTimeInterval(-50400), // Started 14 hours ago
            rewardPool: 1200,
            workers: ["player3", "player4", "player5"],
            createdBy: "ruler1",
            createdAt: Date().addingTimeInterval(-54000),
            completedAt: nil,
            status: .inProgress
        )
    ]
}

