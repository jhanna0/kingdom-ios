import Foundation
import CoreLocation

/// Handles persistence of kingdom state to local storage
/// NOTE: This entire file should be replaced by backend API calls in the future
/// For now, it uses local file storage to maintain kingdom state between app sessions
class KingdomPersistence {
    static let shared = KingdomPersistence()
    
    private let cacheManager = CacheManager.shared
    private let saveKey = "kingdoms_local_state"
    
    private init() {}
    
    // MARK: - Kingdom State Persistence
    // TODO: Replace with backend API - GET /kingdoms
    
    /// Save all kingdoms to persistent storage
    func saveKingdoms(_ kingdoms: [Kingdom]) {
        let cachedKingdoms = kingdoms.map { CachedKingdomState(from: $0) }
        cacheManager.save(cachedKingdoms, forKey: saveKey)
        print("💾 Saved \(kingdoms.count) kingdoms to persistent storage")
    }
    
    /// Load all kingdoms from persistent storage
    func loadKingdoms() -> [Kingdom]? {
        guard let cachedKingdoms = cacheManager.load([CachedKingdomState].self, forKey: saveKey) else {
            print("⚠️ No saved kingdoms found")
            return nil
        }
        
        let kingdoms = cachedKingdoms.map { $0.toKingdom() }
        print("✅ Loaded \(kingdoms.count) kingdoms from persistent storage")
        return kingdoms
    }
    
    /// Clear all saved kingdom state
    func clearKingdoms() {
        cacheManager.remove(forKey: saveKey)
        print("🗑️ Cleared saved kingdoms")
    }
    
    // MARK: - Individual Kingdom Updates
    // TODO: Replace with backend API - PATCH /kingdoms/:id
    
    /// Save a single kingdom (useful for incremental updates)
    func updateKingdom(_ kingdom: Kingdom, in kingdoms: inout [Kingdom]) {
        if let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
            kingdoms[index] = kingdom
            saveKingdoms(kingdoms)
        }
    }
}

// MARK: - Cached Kingdom State

/// Full kingdom state for persistence (includes contracts)
/// TODO: This structure should match backend Kingdom model
struct CachedKingdomState: Codable {
    let id: String
    let name: String
    let rulerName: String
    let rulerId: String?
    let territory: CachedTerritory
    let color: String
    
    // Game stats
    let treasuryGold: Int
    let wallLevel: Int
    let vaultLevel: Int
    let checkedInPlayers: Int
    let mineLevel: Int
    let marketLevel: Int
    
    // Income tracking
    let lastIncomeCollection: Date
    let weeklyUniqueCheckIns: Int
    let totalIncomeCollected: Int
    let incomeHistory: [CachedIncomeRecord]
    
    // Active contract (if any)
    let activeContract: CachedContract?
    
    init(from kingdom: Kingdom) {
        self.id = kingdom.id.uuidString
        self.name = kingdom.name
        self.rulerName = kingdom.rulerName
        self.rulerId = kingdom.rulerId
        self.territory = CachedTerritory(from: kingdom.territory)
        self.color = String(describing: kingdom.color)
        
        self.treasuryGold = kingdom.treasuryGold
        self.wallLevel = kingdom.wallLevel
        self.vaultLevel = kingdom.vaultLevel
        self.checkedInPlayers = kingdom.checkedInPlayers
        self.mineLevel = kingdom.mineLevel
        self.marketLevel = kingdom.marketLevel
        
        self.lastIncomeCollection = kingdom.lastIncomeCollection
        self.weeklyUniqueCheckIns = kingdom.weeklyUniqueCheckIns
        self.totalIncomeCollected = kingdom.totalIncomeCollected
        self.incomeHistory = kingdom.incomeHistory.map { CachedIncomeRecord(from: $0) }
        
        self.activeContract = kingdom.activeContract.map { CachedContract(from: $0) }
    }
    
    func toKingdom() -> Kingdom {
        let color = KingdomColor.from(string: self.color)
        let territory = self.territory.toTerritory()
        
        var kingdom = Kingdom(
            name: self.name,
            rulerName: self.rulerName,
            rulerId: self.rulerId,
            territory: territory,
            color: color
        )
        
        // Restore all cached state
        kingdom.treasuryGold = self.treasuryGold
        kingdom.wallLevel = self.wallLevel
        kingdom.vaultLevel = self.vaultLevel
        kingdom.checkedInPlayers = self.checkedInPlayers
        kingdom.mineLevel = self.mineLevel
        kingdom.marketLevel = self.marketLevel
        kingdom.lastIncomeCollection = self.lastIncomeCollection
        kingdom.weeklyUniqueCheckIns = self.weeklyUniqueCheckIns
        kingdom.totalIncomeCollected = self.totalIncomeCollected
        kingdom.incomeHistory = self.incomeHistory.map { $0.toIncomeRecord() }
        kingdom.activeContract = self.activeContract?.toContract()
        
        return kingdom
    }
}

/// Cached contract state
/// TODO: Replace with backend Contract model
struct CachedContract: Codable {
    let id: String
    let kingdomId: String
    let kingdomName: String
    let buildingType: String
    let buildingLevel: Int
    let basePopulation: Int
    let rewardPool: Int
    let baseHoursRequired: Double
    let workers: [String]
    let createdBy: String
    let createdAt: Date
    let workStartedAt: Date?
    let completedAt: Date?
    let status: String
    
    init(from contract: Contract) {
        self.id = contract.id
        self.kingdomId = contract.kingdomId
        self.kingdomName = contract.kingdomName
        self.buildingType = contract.buildingType
        self.buildingLevel = contract.buildingLevel
        self.basePopulation = contract.basePopulation
        self.rewardPool = contract.rewardPool
        self.baseHoursRequired = contract.baseHoursRequired
        self.workers = Array(contract.workers)
        self.createdBy = contract.createdBy
        self.createdAt = contract.createdAt
        self.workStartedAt = contract.workStartedAt
        self.completedAt = contract.completedAt
        self.status = contract.status.rawValue
    }
    
    func toContract() -> Contract {
        return Contract(
            id: self.id,
            kingdomId: self.kingdomId,
            kingdomName: self.kingdomName,
            buildingType: self.buildingType,
            buildingLevel: self.buildingLevel,
            basePopulation: self.basePopulation,
            baseHoursRequired: self.baseHoursRequired,
            workStartedAt: self.workStartedAt,
            rewardPool: self.rewardPool,
            workers: Set(self.workers),
            createdBy: self.createdBy,
            createdAt: self.createdAt,
            completedAt: self.completedAt,
            status: Contract.ContractStatus(rawValue: self.status) ?? .open
        )
    }
}

/// Cached income record
struct CachedIncomeRecord: Codable {
    let id: String
    let amount: Int
    let timestamp: Date
    let hourlyRate: Int
    let dailyRate: Int
    
    init(from record: IncomeRecord) {
        self.id = record.id.uuidString
        self.amount = record.amount
        self.timestamp = record.timestamp
        self.hourlyRate = record.hourlyRate
        self.dailyRate = record.dailyRate
    }
    
    func toIncomeRecord() -> IncomeRecord {
        return IncomeRecord(
            amount: self.amount,
            hourlyRate: self.hourlyRate,
            dailyRate: self.dailyRate
        )
    }
}

