import Foundation
import CoreLocation

// MARK: - Coup System

/// Represents an active coup event with 2-hour voting period
struct CoupEvent: Identifiable, Codable {
    let id: UUID
    let initiatorId: Int  // PostgreSQL auto-generated integer
    let initiatorName: String
    let targetKingdomId: String
    let targetKingdomName: String
    let startTime: Date
    let votingEndTime: Date  // 2 hours after start
    
    var attackers: [Int] = []  // Player IDs who joined attackers (integers)
    var defenders: [Int] = []  // Player IDs who joined defenders (integers)
    
    var isVotingOpen: Bool {
        return Date() < votingEndTime
    }
    
    var isResolved: Bool = false
    var attackerVictory: Bool?  // nil = not resolved yet
    
    init(initiatorId: Int, initiatorName: String, targetKingdomId: String, targetKingdomName: String) {
        self.id = UUID()
        self.initiatorId = initiatorId
        self.initiatorName = initiatorName
        self.targetKingdomId = targetKingdomId
        self.targetKingdomName = targetKingdomName
        self.startTime = Date()
        self.votingEndTime = Date().addingTimeInterval(2 * 3600)  // 2 hours
        self.attackers = [initiatorId]  // Initiator automatically joins attackers
    }
    
    /// Get time remaining in voting period
    func getTimeRemaining() -> TimeInterval {
        let remaining = votingEndTime.timeIntervalSince(Date())
        return max(0, remaining)
    }
    
    /// Check if battle should resolve
    func shouldResolve() -> Bool {
        return !isVotingOpen && !isResolved
    }
}

// MARK: - Invasion System

/// Represents an invasion campaign (recruitment + battle)
struct InvasionEvent: Identifiable, Codable {
    let id: UUID
    let attackingKingdomId: String
    let attackingKingdomName: String
    let attackingRulerId: Int  // PostgreSQL auto-generated integer
    let attackingRulerName: String
    let targetKingdomId: String
    let targetKingdomName: String
    
    // Phase 1: Recruitment (players must be checked in to TARGET kingdom)
    let recruitmentStartTime: Date
    var signups: [Int] = []  // Players who signed up (paid 100g, CHECKED IN to target) - integers
    var isLaunched: Bool = false
    
    // Phase 2: Battle (after launch)
    var launchTime: Date?
    var rallyEndTime: Date?  // 2 hours after launch
    var defenders: [Int] = []  // Defenders who joined (integers)
    
    var isResolved: Bool = false
    var attackerVictory: Bool?
    
    let goldCostPerAttacker: Int = 100
    let minimumAttackers: Int = 10
    
    init(attackingKingdomId: String, 
         attackingKingdomName: String,
         attackingRulerId: Int,
         attackingRulerName: String,
         targetKingdomId: String,
         targetKingdomName: String) {
        self.id = UUID()
        self.attackingKingdomId = attackingKingdomId
        self.attackingKingdomName = attackingKingdomName
        self.attackingRulerId = attackingRulerId
        self.attackingRulerName = attackingRulerName
        self.targetKingdomId = targetKingdomId
        self.targetKingdomName = targetKingdomName
        self.recruitmentStartTime = Date()
    }
    
    /// Check if can launch (enough signups)
    func canLaunch() -> Bool {
        return signups.count >= minimumAttackers && !isLaunched
    }
    
    /// Launch the invasion (start 2-hour warning)
    mutating func launch() {
        guard canLaunch() else { return }
        isLaunched = true
        launchTime = Date()
        rallyEndTime = Date().addingTimeInterval(2 * 3600)  // 2 hours
    }
    
    var isRallyOpen: Bool {
        guard let rallyEnd = rallyEndTime else { return false }
        return Date() < rallyEnd
    }
    
    /// Get time remaining in rally period
    func getTimeRemaining() -> TimeInterval {
        guard let rallyEnd = rallyEndTime else { return 0 }
        let remaining = rallyEnd.timeIntervalSince(Date())
        return max(0, remaining)
    }
    
    /// Check if battle should resolve
    func shouldResolve() -> Bool {
        return !isRallyOpen && !isResolved
    }
    
    /// Get total gold cost for this invasion
    func getTotalCost() -> Int {
        return signups.count * goldCostPerAttacker
    }
}

// MARK: - Combat Resolution

class CombatResolver {
    
    /// Resolve a coup battle
    static func resolveCoup(
        coup: CoupEvent,
        players: [Int: Player],  // All players by ID (integers)
        kingdom: Kingdom
    ) -> CoupResult {
        
        // Calculate attacker strength
        let attackerStrength = coup.attackers.reduce(0) { sum, playerId in
            guard let player = players[playerId] else { return sum }
            return sum + player.attackPower
        }
        
        // Calculate defender strength
        let defenderStrength = coup.defenders.reduce(0) { sum, playerId in
            guard let player = players[playerId] else { return sum }
            return sum + player.defensePower
        }
        
        // NO WALLS FOR COUPS - internal rebellion, already inside city
        let totalDefense = defenderStrength
        
        // Attackers need 25% advantage
        let requiredAttackStrength = Int(Double(totalDefense) * 1.25)
        let attackerVictory = attackerStrength > requiredAttackStrength
        
        return CoupResult(
            coupId: coup.id,
            attackerVictory: attackerVictory,
            attackerStrength: attackerStrength,
            defenderStrength: totalDefense,
            attackers: coup.attackers,
            defenders: coup.defenders,
            newRulerId: attackerVictory ? coup.initiatorId : nil,
            newRulerName: attackerVictory ? coup.initiatorName : nil,
            oldRulerId: kingdom.rulerId
        )
    }
    
    /// Resolve an invasion battle
    static func resolveInvasion(
        invasion: InvasionEvent,
        players: [Int: Player],  // All players by ID (integers)
        targetKingdom: Kingdom
    ) -> InvasionResult {
        
        // Calculate attacker strength (from signups)
        let attackerStrength = invasion.signups.reduce(0) { sum, playerId in
            guard let player = players[playerId] else { return sum }
            return sum + player.attackPower
        }
        
        // Calculate defender strength
        let defenderStrength = invasion.defenders.reduce(0) { sum, playerId in
            guard let player = players[playerId] else { return sum }
            return sum + player.defensePower
        }
        
        // Add wall defense
        let wallDefense = targetKingdom.buildingLevel("wall") * 5
        let totalDefense = defenderStrength + wallDefense
        
        // Attackers need 25% advantage
        let requiredAttackStrength = Int(Double(totalDefense) * 1.25)
        let attackerVictory = attackerStrength > requiredAttackStrength
        
        // Calculate loot
        let vaultProtection = Double(targetKingdom.buildingLevel("vault")) * 0.20
        let lootable = Int(Double(targetKingdom.treasuryGold) * (1.0 - vaultProtection))
        let lootPerAttacker = attackerVictory ? lootable / invasion.signups.count : 0
        
        return InvasionResult(
            invasionId: invasion.id,
            attackerVictory: attackerVictory,
            attackerStrength: attackerStrength,
            defenderStrength: totalDefense,
            attackers: invasion.signups,  // All who signed up
            defenders: invasion.defenders,
            newRulerId: attackerVictory ? invasion.attackingRulerId : nil,
            lootPerAttacker: lootPerAttacker,
            wallDamage: attackerVictory ? 2 : 0,
            productionDamage: attackerVictory,  // Damage mine/forge if win
            attackDebuffHours: attackerVictory ? 0 : 24
        )
    }
}

// MARK: - Battle Results

struct CoupResult {
    let coupId: UUID
    let attackerVictory: Bool
    let attackerStrength: Int
    let defenderStrength: Int
    let attackers: [Int]  // All will be punished if they lose (integers)
    let defenders: [Int]  // All will be rewarded if they win (integers)
    let newRulerId: Int?  // Coup initiator if victory (PostgreSQL integer)
    let newRulerName: String?
    let oldRulerId: Int?  // For determining escape chance (PostgreSQL integer)
    
    /// Calculate old ruler's chance to flee (based on defender support)
    func getFleeChance() -> Double {
        guard attackerVictory else { return 0.0 }
        
        let totalPeople = attackers.count + defenders.count
        guard totalPeople > 0 else { return 0.0 }
        
        // % of people who supported the ruler
        return Double(defenders.count) / Double(totalPeople)
    }
    
    /// Determine if old ruler successfully flees
    func didRulerFlee() -> Bool {
        guard attackerVictory else { return false }
        
        let fleeChance = getFleeChance()
        let roll = Double.random(in: 0.0...1.0)
        return roll < fleeChance
    }
    
    /// Get penalties for failed attackers
    func getAttackerPenalties(player: Player) -> AttackerPenalty {
        guard !attackerVictory else { return AttackerPenalty.none }
        
        let goldLost = player.gold / 2
        return AttackerPenalty(
            goldLost: goldLost,
            reputationLost: 100,
            attackLost: 2,
            defenseLost: 2
        )
    }
}

struct AttackerPenalty {
    let goldLost: Int
    let reputationLost: Int
    let attackLost: Int
    let defenseLost: Int
    
    static let none = AttackerPenalty(goldLost: 0, reputationLost: 0, attackLost: 0, defenseLost: 0)
}

struct InvasionResult {
    let invasionId: UUID
    let attackerVictory: Bool
    let attackerStrength: Int
    let defenderStrength: Int
    let attackers: [Int]  // Integers
    let defenders: [Int]  // Integers
    let newRulerId: Int?  // Attacking ruler if victory (PostgreSQL integer)
    let lootPerAttacker: Int
    let wallDamage: Int  // How many wall levels destroyed
    let productionDamage: Bool  // Whether mine/forge were damaged
    let attackDebuffHours: Int  // How long attackers are wounded if they lose
    
    /// Get penalties for failed attackers
    func getAttackerDebuff() -> InvasionDebuff? {
        guard !attackerVictory else { return nil }
        
        return InvasionDebuff(
            attackPowerLoss: 1,
            reputationLost: 50,
            durationHours: 24
        )
    }
}

struct InvasionDebuff {
    let attackPowerLoss: Int  // Temporary attack reduction
    let reputationLost: Int   // Permanent reputation loss
    let durationHours: Int    // How long the debuff lasts
}

// MARK: - Neighboring Check

extension Kingdom {
    
    /// Check if this kingdom is neighboring another (within 10km or shares border)
    func isNeighboring(_ other: Kingdom) -> Bool {
        // Calculate distance between centers
        let centerLoc = CLLocation(
            latitude: self.territory.center.latitude,
            longitude: self.territory.center.longitude
        )
        let otherLoc = CLLocation(
            latitude: other.territory.center.latitude,
            longitude: other.territory.center.longitude
        )
        
        let distance = centerLoc.distance(from: otherLoc)
        
        // Within 10km = neighboring
        return distance <= 10_000  // 10km in meters
    }
}

