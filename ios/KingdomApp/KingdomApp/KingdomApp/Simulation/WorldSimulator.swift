import Foundation
import Combine

// MARK: - World Simulator
// Makes the game playable during development by simulating NPC activity
// NPCs actually work on contracts, pay taxes, and affect YOUR gameplay

@MainActor
class WorldSimulator: ObservableObject {
    static let shared = WorldSimulator()
    
    // NPCs in each kingdom (by kingdom name)
    @Published var citizens: [String: [Citizen]] = [:]
    
    // Activity log (what NPCs are doing)
    @Published var recentActivity: [ActivityLog] = []
    
    private var simulationTimer: Timer?
    private let maxActivityLog = 20
    
    init() {}
    
    // MARK: - Setup
    
    /// Call this when kingdoms are loaded - spawns citizens for each
    func populateKingdoms(_ kingdoms: [Kingdom]) {
        for kingdom in kingdoms {
            if citizens[kingdom.name] == nil {
                // Spawn 5-15 NPCs per kingdom
                let count = Int.random(in: 5...15)
                citizens[kingdom.name] = (0..<count).map { _ in
                    Citizen.random(in: kingdom.name)
                }
            }
        }
        
        // Start simulation if not running
        startSimulation()
    }
    
    // MARK: - Main Simulation Loop
    
    func startSimulation() {
        guard simulationTimer == nil else { return }
        
        // Tick every 5 seconds
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        
        // Run first tick immediately
        tick()
    }
    
    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    private func tick() {
        // NPCs do random activities - but this is just cosmetic logging
        // The REAL work happens in simulateContractWork()
    }
    
    // MARK: - Contract Work (THE IMPORTANT PART)
    
    /// Call this to have NPCs work on a kingdom's active contract
    /// Returns the number of workers who joined
    func simulateContractWork(for kingdom: inout Kingdom) -> Int {
        guard var contract = kingdom.activeContract else { return 0 }
        guard contract.status == .open || contract.status == .inProgress else { return 0 }
        
        let kingdomCitizens = citizens[kingdom.name] ?? []
        var workersJoined = 0
        
        // Each citizen has a chance to join the contract
        for citizen in kingdomCitizens {
            // Skip if already working
            if contract.workers.contains(citizen.id) { continue }
            
            // 30% chance each tick to join an open contract
            if Double.random(in: 0...1) < 0.3 {
                contract.addWorker(citizen.id)
                workersJoined += 1
                
                logActivity(
                    "\(citizen.name) started working on \(contract.buildingType) upgrade",
                    in: kingdom.name,
                    icon: "🔨"
                )
                
                // Max 3 NPC workers per contract (player can also join)
                if contract.workers.count >= 3 { break }
            }
        }
        
        kingdom.activeContract = contract
        return workersJoined
    }
    
    // MARK: - Tax Income (NPCs mining and paying taxes)
    
    /// Simulate NPCs mining and paying taxes to kingdom treasury
    /// Call this periodically (e.g., every hour or when player checks in)
    func simulateTaxIncome(for kingdom: inout Kingdom) -> Int {
        let kingdomCitizens = citizens[kingdom.name] ?? []
        guard !kingdomCitizens.isEmpty else { return 0 }
        
        // Each citizen "mines" and pays tax
        let ironPerMine = kingdom.getIronPerMiningAction()
        let steelPerMine = kingdom.getSteelPerMiningAction()
        let resourceValue = ironPerMine + (steelPerMine * 2)
        
        // Simulate ~30% of citizens mining today
        let minersToday = max(1, kingdomCitizens.count * 30 / 100)
        let totalMined = resourceValue * minersToday
        let taxCollected = kingdom.calculateTax(on: totalMined)
        
        if taxCollected > 0 {
            kingdom.treasuryGold += taxCollected
            logActivity(
                "\(minersToday) citizens paid \(taxCollected)g in mining taxes",
                in: kingdom.name,
                icon: "💰"
            )
        }
        
        return taxCollected
    }
    
    // MARK: - Population Queries
    
    func getCitizens(in kingdomName: String) -> [Citizen] {
        return citizens[kingdomName] ?? []
    }
    
    func getCitizenCount(in kingdomName: String) -> Int {
        return citizens[kingdomName]?.count ?? 0
    }
    
    func getOnlineCitizens(in kingdomName: String) -> [Citizen] {
        return getCitizens(in: kingdomName).filter { $0.isOnline }
    }
    
    // MARK: - Activity Logging
    
    /// Add an activity log entry (public API for game events)
    func addActivity(_ message: String, in kingdom: String, icon: String = "📜") {
        let log = ActivityLog(
            message: message,
            kingdomName: kingdom,
            icon: icon,
            timestamp: Date()
        )
        
        recentActivity.insert(log, at: 0)
        if recentActivity.count > maxActivityLog {
            recentActivity = Array(recentActivity.prefix(maxActivityLog))
        }
    }
    
    /// Private wrapper for internal use
    private func logActivity(_ message: String, in kingdom: String, icon: String = "📜") {
        addActivity(message, in: kingdom, icon: icon)
    }
    
    func getActivityFor(kingdom: String) -> [ActivityLog] {
        return recentActivity.filter { $0.kingdomName == kingdom }
    }
}

// MARK: - Citizen (NPC)

struct Citizen: Identifiable, Codable, Hashable {
    let id: Int  // NPC citizen ID (integer)
    let name: String
    let homeKingdom: String
    var reputation: Int
    var attackPower: Int
    var defensePower: Int
    var isOnline: Bool
    var lastSeen: Date
    
    // What they're currently doing
    var currentActivity: CitizenActivity
    
    enum CitizenActivity: String, Codable {
        case idle = "Idle"
        case mining = "Mining"
        case crafting = "Crafting"
        case working = "Working on Contract"
        case training = "Training"
    }
    
    static func random(in kingdom: String) -> Citizen {
        let firstNames = [
            "Aldric", "Beatrix", "Cedric", "Dahlia", "Edmund", "Freya", "Gareth", "Helena",
            "Isolde", "Jareth", "Kaelin", "Lyra", "Magnus", "Nadia", "Osric", "Petra",
            "Quentin", "Rowena", "Silas", "Thalia", "Ulric", "Vera", "Wilhelm", "Zara",
            "Alden", "Brynn", "Corwin", "Daria", "Eirik", "Fiona", "Gideon", "Hilda"
        ]
        
        let titles = ["", "", "", " the Bold", " the Wise", " Ironhand", " Swiftfoot"]
        
        let name = (firstNames.randomElement() ?? "Unknown") + (titles.randomElement() ?? "")
        
        return Citizen(
            id: Int.random(in: 10000...99999),  // Random NPC ID (won't conflict with real user IDs starting at 1)
            name: name,
            homeKingdom: kingdom,
            reputation: Int.random(in: 50...300),
            attackPower: Int.random(in: 1...8),
            defensePower: Int.random(in: 1...8),
            isOnline: Bool.random(),
            lastSeen: Date().addingTimeInterval(-Double.random(in: 0...3600)),
            currentActivity: .idle
        )
    }
}

// MARK: - Activity Log

struct ActivityLog: Identifiable {
    let id = UUID()
    let message: String
    let kingdomName: String
    let icon: String
    let timestamp: Date
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}
