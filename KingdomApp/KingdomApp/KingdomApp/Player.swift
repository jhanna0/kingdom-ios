import Foundation
import CoreLocation
import Combine

/// Player model - represents the local player
class Player: ObservableObject {
    // Identity
    @Published var playerId: String
    @Published var name: String
    
    // Status
    @Published var isAlive: Bool = true
    @Published var gold: Int = 100  // Starting gold
    
    // Location & Check-in
    @Published var currentKingdom: String?  // Kingdom player is currently in
    @Published var lastCheckIn: Date?
    @Published var lastCheckInLocation: CLLocationCoordinate2D?
    
    // Power & Territory
    @Published var fiefsRuled: Set<String> = []  // Kingdom names this player rules
    @Published var isRuler: Bool = false
    
    // Work & Contracts
    @Published var activeContractId: String?  // Contract player is currently working on
    @Published var contractsCompleted: Int = 0
    @Published var totalWorkContributed: Int = 0
    
    // Stats
    @Published var coupsWon: Int = 0
    @Published var coupsFailed: Int = 0
    @Published var timesExecuted: Int = 0
    @Published var executionsOrdered: Int = 0
    
    // Cooldowns
    @Published var lastCoupAttempt: Date?
    
    // Game configuration
    let checkInValidHours: Double = 4  // Check-ins expire after 4 hours
    let checkInRadiusMeters: Double = 100  // Must be within 100m to check in
    let coupCooldownHours: Double = 24
    
    init(playerId: String = UUID().uuidString, name: String = "Player") {
        self.playerId = playerId
        self.name = name
        
        // Load saved data if exists
        loadFromUserDefaults()
    }
    
    // MARK: - Check-in Logic
    
    /// Check if player has a valid check-in
    func isCheckedIn() -> Bool {
        guard let lastCheckIn = lastCheckIn else { return false }
        let elapsed = Date().timeIntervalSince(lastCheckIn)
        return elapsed < (checkInValidHours * 3600)
    }
    
    /// Check in to a kingdom
    func checkIn(to kingdom: String, at location: CLLocationCoordinate2D) {
        currentKingdom = kingdom
        lastCheckIn = Date()
        lastCheckInLocation = location
        saveToUserDefaults()
    }
    
    /// Check if player can check in to a location (within range)
    func canCheckIn(to location: CLLocationCoordinate2D, from userLocation: CLLocationCoordinate2D) -> Bool {
        let distance = calculateDistance(from: userLocation, to: location)
        return distance <= checkInRadiusMeters
    }
    
    // MARK: - Territory Management
    
    /// Claim a kingdom (become ruler)
    func claimKingdom(_ kingdom: String) {
        fiefsRuled.insert(kingdom)
        isRuler = true
        currentKingdom = kingdom
        saveToUserDefaults()
        print("👑 Claimed \(kingdom)")
    }
    
    /// Lose control of a kingdom
    func loseKingdom(_ kingdom: String) {
        fiefsRuled.remove(kingdom)
        if fiefsRuled.isEmpty {
            isRuler = false
        }
        saveToUserDefaults()
    }
    
    // MARK: - Coup System
    
    /// Check if player can attempt a coup (cooldown expired)
    func canAttemptCoup() -> Bool {
        guard let lastAttempt = lastCoupAttempt else { return true }
        let elapsed = Date().timeIntervalSince(lastAttempt)
        return elapsed >= (coupCooldownHours * 3600)
    }
    
    /// Record a coup attempt
    func recordCoupAttempt(success: Bool) {
        lastCoupAttempt = Date()
        if success {
            coupsWon += 1
        } else {
            coupsFailed += 1
        }
        saveToUserDefaults()
    }
    
    // MARK: - Economy
    
    /// Add gold to player
    func addGold(_ amount: Int) {
        gold += amount
        saveToUserDefaults()
    }
    
    /// Try to spend gold
    func spendGold(_ amount: Int) -> Bool {
        guard gold >= amount else { return false }
        gold -= amount
        saveToUserDefaults()
        return true
    }
    
    // MARK: - Utilities
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)  // Returns meters
    }
    
    // MARK: - Persistence
    
    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(playerId, forKey: "playerId")
        defaults.set(name, forKey: "playerName")
        defaults.set(isAlive, forKey: "isAlive")
        defaults.set(gold, forKey: "gold")
        defaults.set(currentKingdom, forKey: "currentKingdom")
        defaults.set(lastCheckIn, forKey: "lastCheckIn")
        defaults.set(Array(fiefsRuled), forKey: "fiefsRuled")
        defaults.set(isRuler, forKey: "isRuler")
        defaults.set(activeContractId, forKey: "activeContractId")
        defaults.set(contractsCompleted, forKey: "contractsCompleted")
        defaults.set(totalWorkContributed, forKey: "totalWorkContributed")
        defaults.set(coupsWon, forKey: "coupsWon")
        defaults.set(coupsFailed, forKey: "coupsFailed")
        defaults.set(timesExecuted, forKey: "timesExecuted")
        defaults.set(executionsOrdered, forKey: "executionsOrdered")
        defaults.set(lastCoupAttempt, forKey: "lastCoupAttempt")
        
        if let location = lastCheckInLocation {
            defaults.set(location.latitude, forKey: "lastCheckInLat")
            defaults.set(location.longitude, forKey: "lastCheckInLon")
        }
    }
    
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        if let savedId = defaults.string(forKey: "playerId") {
            playerId = savedId
        }
        if let savedName = defaults.string(forKey: "playerName") {
            name = savedName
        }
        
        isAlive = defaults.object(forKey: "isAlive") as? Bool ?? true
        
        // Check if this is first launch
        if !defaults.bool(forKey: "hasLoadedBefore") {
            gold = 100  // Default starting gold for new players
            defaults.set(true, forKey: "hasLoadedBefore")
            saveToUserDefaults()  // Save the initial state
        } else {
            gold = defaults.integer(forKey: "gold")
            
            // Fix for players who got stuck with 0 gold due to earlier bug
            if gold == 0 && fiefsRuled.isEmpty && (coupsWon + coupsFailed + timesExecuted + executionsOrdered) == 0 {
                print("⚠️ Detected new player with 0 gold - giving starting gold")
                gold = 100
                saveToUserDefaults()
            }
        }
        
        currentKingdom = defaults.string(forKey: "currentKingdom")
        lastCheckIn = defaults.object(forKey: "lastCheckIn") as? Date
        
        if let lat = defaults.object(forKey: "lastCheckInLat") as? Double,
           let lon = defaults.object(forKey: "lastCheckInLon") as? Double {
            lastCheckInLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        if let fiefs = defaults.array(forKey: "fiefsRuled") as? [String] {
            fiefsRuled = Set(fiefs)
        }
        
        isRuler = defaults.bool(forKey: "isRuler")
        activeContractId = defaults.string(forKey: "activeContractId")
        contractsCompleted = defaults.integer(forKey: "contractsCompleted")
        totalWorkContributed = defaults.integer(forKey: "totalWorkContributed")
        coupsWon = defaults.integer(forKey: "coupsWon")
        coupsFailed = defaults.integer(forKey: "coupsFailed")
        timesExecuted = defaults.integer(forKey: "timesExecuted")
        executionsOrdered = defaults.integer(forKey: "executionsOrdered")
        lastCoupAttempt = defaults.object(forKey: "lastCoupAttempt") as? Date
    }
    
    /// Reset player data (for testing/debugging)
    func reset() {
        gold = 100
        fiefsRuled.removeAll()
        isRuler = false
        currentKingdom = nil
        lastCheckIn = nil
        lastCheckInLocation = nil
        coupsWon = 0
        coupsFailed = 0
        timesExecuted = 0
        executionsOrdered = 0
        lastCoupAttempt = nil
        saveToUserDefaults()
    }
}

