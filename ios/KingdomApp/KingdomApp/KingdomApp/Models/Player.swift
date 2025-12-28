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
    
    // Player History & Home
    @Published var homeKingdomId: String?   // Where they spend most time
    @Published var originKingdomId: String? // Where they started (first 300+ rep)
    @Published var checkInHistory: [String: Int] = [:]  // kingdomId -> total check-ins
    
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
    
    // Progression & Reputation
    @Published var reputation: Int = 0          // Global reputation
    @Published var level: Int = 1               // Character level
    @Published var experience: Int = 0          // XP towards next level
    @Published var skillPoints: Int = 0         // Unspent skill points
    
    // Combat Stats (improve via training/leveling)
    @Published var attackPower: Int = 1         // Coup offensive power
    @Published var defensePower: Int = 1        // Defend against coups
    @Published var leadership: Int = 1          // Vote weight multiplier
    @Published var buildingSkill: Int = 1       // Building efficiency & cost reduction
    
    // Kingdom-specific reputation
    @Published var kingdomReputation: [String: Int] = [:]  // kingdomId -> rep
    
    // Reward distribution tracking
    @Published var totalRewardsReceived: Int = 0  // Lifetime subject rewards
    @Published var lastRewardReceived: Date?
    @Published var lastRewardAmount: Int = 0
    
    // Cooldowns
    @Published var lastCoupAttempt: Date?
    @Published var lastDailyCheckIn: Date?      // For daily bonuses
    
    // Temporary debuffs (from failed battles)
    @Published var attackDebuff: Int = 0        // Temporary attack reduction
    @Published var debuffExpires: Date?         // When the debuff ends
    
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
    
    // MARK: - Reputation System
    
    /// Reputation tiers (like Eve Online standings)
    enum ReputationTier: String {
        case stranger = "Stranger"           // 0-49
        case resident = "Resident"           // 50-149
        case citizen = "Citizen"             // 150-299: Can vote on coups
        case notable = "Notable"             // 300-499: Can propose coups
        case champion = "Champion"           // 500-999: Vote counts 2x
        case legendary = "Legendary"         // 1000+: Vote counts 3x
        
        static func tier(for rep: Int) -> ReputationTier {
            if rep >= 1000 { return .legendary }
            if rep >= 500 { return .champion }
            if rep >= 300 { return .notable }
            if rep >= 150 { return .citizen }
            if rep >= 50 { return .resident }
            return .stranger
        }
        
        var voteWeight: Int {
            switch self {
            case .legendary: return 3
            case .champion: return 2
            default: return 1
            }
        }
    }
    
    /// Get reputation tier
    func getReputationTier() -> ReputationTier {
        return ReputationTier.tier(for: reputation)
    }
    
    /// Get kingdom-specific reputation
    func getKingdomReputation(_ kingdomId: String) -> Int {
        return kingdomReputation[kingdomId] ?? 0
    }
    
    /// Get kingdom reputation tier
    func getKingdomTier(_ kingdomId: String) -> ReputationTier {
        let rep = getKingdomReputation(kingdomId)
        return ReputationTier.tier(for: rep)
    }
    
    /// Add reputation (PERMANENT - like Eve standings)
    func addReputation(_ amount: Int, inKingdom kingdomId: String? = nil) {
        // Global reputation
        reputation += amount
        
        // Kingdom-specific reputation
        if let kingdomId = kingdomId {
            let current = kingdomReputation[kingdomId] ?? 0
            let newRep = current + amount
            kingdomReputation[kingdomId] = newRep
            
            // Track origin kingdom (first time hitting 300+ rep)
            if originKingdomId == nil && newRep >= 300 {
                originKingdomId = kingdomId
            }
        }
        
        saveToUserDefaults()
    }
    
    /// Check if can vote on coups (150+ rep in kingdom)
    func canVoteOnCoup(inKingdom kingdomId: String) -> Bool {
        return getKingdomReputation(kingdomId) >= 150 && isCheckedIn()
    }
    
    /// Check if can propose coup (300+ rep in kingdom)
    func canProposeCoup(inKingdom kingdomId: String) -> Bool {
        return getKingdomReputation(kingdomId) >= 300 && isCheckedIn()
    }
    
    /// Get vote weight (reputation tier + leadership stat)
    func getVoteWeight(inKingdom kingdomId: String) -> Int {
        let tier = getKingdomTier(kingdomId)
        return tier.voteWeight + leadership
    }
    
    // MARK: - Merit Score & Reward Distribution
    
    /// Calculate merit score for reward distribution
    /// Formula: (reputation × 1.0) + (skillTotal × 0.5)
    /// Reputation weighted 2× more than skills
    func calculateMeritScore(inKingdom kingdomId: String) -> Int {
        let rep = getKingdomReputation(kingdomId)
        let skillTotal = attackPower + defensePower + leadership + buildingSkill
        
        // Reputation counts 1.0×, skills count 0.5×
        let reputationPoints = Double(rep) * 1.0
        let skillPoints = Double(skillTotal) * 0.5
        
        return Int(reputationPoints + skillPoints)
    }
    
    /// Check if player is eligible for reward distribution
    func isEligibleForRewards(inKingdom kingdomId: String, rulerId: String?) -> Bool {
        // Must not be the ruler
        guard playerId != rulerId else { return false }
        
        // Must have checked in within last 7 days
        guard let lastCheckIn = lastCheckIn else { return false }
        let daysSinceCheckIn = Date().timeIntervalSince(lastCheckIn) / 86400
        guard daysSinceCheckIn < 7 else { return false }
        
        // Must have at least 50 reputation (Resident tier)
        let rep = getKingdomReputation(kingdomId)
        guard rep >= 50 else { return false }
        
        return true
    }
    
    /// Receive reward distribution
    func receiveReward(_ amount: Int) {
        addGold(amount)
        totalRewardsReceived += amount
        lastRewardReceived = Date()
        lastRewardAmount = amount
        
        print("💎 Received reward: \(amount)g")
    }
    
    // MARK: - Experience & Leveling
    
    /// Get XP needed for next level
    func getXPForNextLevel() -> Int {
        return 100 * Int(pow(2.0, Double(level - 1)))
    }
    
    /// Get XP progress (0.0 to 1.0)
    func getXPProgress() -> Double {
        let needed = getXPForNextLevel()
        return Double(experience) / Double(needed)
    }
    
    /// Add experience points
    func addExperience(_ amount: Int) {
        experience += amount
        
        // Check for level up
        while experience >= getXPForNextLevel() {
            levelUp()
        }
        
        saveToUserDefaults()
    }
    
    /// Level up!
    private func levelUp() {
        let xpNeeded = getXPForNextLevel()
        experience -= xpNeeded
        level += 1
        skillPoints += 3  // 3 points per level
        
        // Bonus rewards
        gold += 50  // Bonus gold per level
        
        print("🎉 Level up! Now level \(level)")
        saveToUserDefaults()
    }
    
    // MARK: - Training (Spend Gold on Stats)
    
    /// Train attack power
    func trainAttack() -> Bool {
        let cost = getTrainingCost(for: attackPower)
        guard spendGold(cost) else { return false }
        
        attackPower += 1
        saveToUserDefaults()
        return true
    }
    
    /// Train defense power
    func trainDefense() -> Bool {
        let cost = getTrainingCost(for: defensePower)
        guard spendGold(cost) else { return false }
        
        defensePower += 1
        saveToUserDefaults()
        return true
    }
    
    /// Train leadership
    func trainLeadership() -> Bool {
        let cost = getTrainingCost(for: leadership)
        guard spendGold(cost) else { return false }
        
        leadership += 1
        saveToUserDefaults()
        return true
    }
    
    /// Train building skill
    func trainBuilding() -> Bool {
        let cost = getTrainingCost(for: buildingSkill)
        guard spendGold(cost) else { return false }
        
        buildingSkill += 1
        saveToUserDefaults()
        return true
    }
    
    /// Use skill point to increase stat
    func useSkillPoint(on stat: SkillStat) -> Bool {
        guard skillPoints > 0 else { return false }
        
        skillPoints -= 1
        
        switch stat {
        case .attack:
            attackPower += 1
        case .defense:
            defensePower += 1
        case .leadership:
            leadership += 1
        case .building:
            buildingSkill += 1
        }
        
        saveToUserDefaults()
        return true
    }
    
    enum SkillStat {
        case attack, defense, leadership, building
    }
    
    /// Get training cost (increases with stat level)
    private func getTrainingCost(for statLevel: Int) -> Int {
        // Cost formula: 100 * (level^1.5)
        // Level 1→2: 100g
        // Level 5→6: 559g
        // Level 10→11: 1581g
        return Int(100.0 * pow(Double(statLevel), 1.5))
    }
    
    /// Get training cost for display
    func getAttackTrainingCost() -> Int {
        return getTrainingCost(for: attackPower)
    }
    
    func getDefenseTrainingCost() -> Int {
        return getTrainingCost(for: defensePower)
    }
    
    func getLeadershipTrainingCost() -> Int {
        return getTrainingCost(for: leadership)
    }
    
    func getBuildingTrainingCost() -> Int {
        return getTrainingCost(for: buildingSkill)
    }
    
    /// Get building cost discount (percentage)
    /// Each level of building skill reduces costs by 2%
    func getBuildingCostDiscount() -> Double {
        return Double(buildingSkill - 1) * 0.02  // Level 1 = 0%, Level 10 = 18%
    }
    
    /// Calculate discounted building cost
    func getDiscountedBuildingCost(_ baseCost: Int) -> Int {
        let discount = getBuildingCostDiscount()
        return Int(Double(baseCost) * (1.0 - discount))
    }
    
    // MARK: - Rewards System (Gold + Reputation ONLY)
    
    /// Reward for completing contract
    func rewardContractCompletion(goldAmount: Int) {
        addGold(goldAmount)
        addReputation(10, inKingdom: currentKingdom)  // 10 rep in current kingdom
        contractsCompleted += 1
        
        print("💰 Contract reward: \(goldAmount)g, +10 rep")
    }
    
    /// Reward for daily check-in
    func rewardDailyCheckIn() -> Bool {
        // Check if already claimed today
        if let lastDaily = lastDailyCheckIn {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastDaily) {
                return false  // Already claimed today
            }
        }
        
        lastDailyCheckIn = Date()
        addReputation(5, inKingdom: currentKingdom)  // 5 rep
        addGold(50)  // 50g bonus
        
        saveToUserDefaults()
        print("📅 Daily check-in: +50g, +5 rep")
        return true
    }
    
    /// Reward for successful coup
    func rewardCoupSuccess() {
        addGold(1000)  // Big gold reward
        addReputation(50, inKingdom: currentKingdom)  // Big rep boost
        coupsWon += 1
        
        print("👑 Coup success: +1000g, +50 rep!")
    }
    
    /// Reward for defending against coup
    func rewardCoupDefense() {
        addGold(200)
        addReputation(25, inKingdom: currentKingdom)
        
        print("🛡️ Defended coup: +200g, +25 rep")
    }
    
    // MARK: - Purchase XP (Gold Management)
    
    /// Buy experience points with gold
    /// Forces strategic choice: invest in character or save for other things?
    func purchaseXP(amount: Int) -> Bool {
        let cost = getXPCost(for: amount)
        guard spendGold(cost) else { return false }
        
        addExperience(amount)
        print("📚 Purchased \(amount) XP for \(cost)g")
        return true
    }
    
    /// Get cost to buy XP (1 XP = 10 gold)
    func getXPCost(for xpAmount: Int) -> Int {
        return xpAmount * 10  // Simple: 10g per XP
    }
    
    /// Quick purchase options
    func purchaseSmallXPBoost() -> Bool {
        return purchaseXP(amount: 10)  // 100g for 10 XP
    }
    
    func purchaseMediumXPBoost() -> Bool {
        return purchaseXP(amount: 50)  // 500g for 50 XP
    }
    
    func purchaseLargeXPBoost() -> Bool {
        return purchaseXP(amount: 100)  // 1000g for 100 XP
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
        
        // Track check-in history
        let currentCount = checkInHistory[kingdom] ?? 0
        checkInHistory[kingdom] = currentCount + 1
        
        // Update home kingdom (where they check in most)
        updateHomeKingdom()
        
        saveToUserDefaults()
    }
    
    /// Update home kingdom based on check-in frequency
    private func updateHomeKingdom() {
        if let mostFrequent = checkInHistory.max(by: { $0.value < $1.value }) {
            homeKingdomId = mostFrequent.key
        }
    }
    
    /// Get player's "true" kingdom (home)
    func getTrueKingdom() -> String? {
        // 1. If they rule a kingdom, that's their kingdom
        if let ruledKingdom = fiefsRuled.first {
            return ruledKingdom
        }
        
        // 2. Otherwise, their home kingdom (most check-ins)
        return homeKingdomId
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
    
    // MARK: - Combat Debuffs
    
    /// Get effective attack power (including debuffs)
    func getEffectiveAttackPower() -> Int {
        clearExpiredDebuffs()
        return max(1, attackPower - attackDebuff)
    }
    
    /// Apply wound debuff from failed invasion
    func applyWoundDebuff(attackLoss: Int, durationHours: Double) {
        attackDebuff = attackLoss
        debuffExpires = Date().addingTimeInterval(durationHours * 3600)
        saveToUserDefaults()
    }
    
    /// Clear debuffs if they've expired
    func clearExpiredDebuffs() {
        guard let expires = debuffExpires else { return }
        
        if Date() >= expires {
            attackDebuff = 0
            debuffExpires = nil
            saveToUserDefaults()
        }
    }
    
    /// Check if player is currently debuffed
    func isDebuffed() -> Bool {
        clearExpiredDebuffs()
        return attackDebuff > 0
    }
    
    /// Apply harsh penalties from failed coup (EXECUTED)
    func applyCoupFailurePenalty(seizedBy ruler: Player) {
        // 1. Lose ALL gold (executed)
        let goldLost = gold
        gold = 0
        ruler.addGold(goldLost)
        
        // 2. Major reputation loss
        reputation -= 100
        if let kingdom = currentKingdom {
            let currentRep = kingdomReputation[kingdom] ?? 0
            kingdomReputation[kingdom] = currentRep - 100
        }
        
        // 3. Lose ALL combat stats (EXECUTED)
        attackPower = 1
        defensePower = 1
        leadership = 1
        
        // 4. Mark as traitor (badge)
        // TODO: Add badge system
        
        saveToUserDefaults()
    }
    
    /// Apply catastrophic penalty for overthrown ruler who failed to flee
    func applyOverthrownRulerPenalty() {
        // LOSE EVERYTHING
        gold = 0
        
        // Massive reputation hit
        reputation -= 200
        if let kingdom = currentKingdom {
            kingdomReputation[kingdom] = 0  // Reset to 0 in this kingdom
        }
        
        // Severe stat loss
        attackPower = max(1, attackPower - 5)
        defensePower = max(1, defensePower - 5)
        leadership = max(1, leadership - 5)
        
        // Lose ruler status
        fiefsRuled.removeAll()
        isRuler = false
        
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
    // TODO: Replace all UserDefaults persistence with backend API
    // - POST /players (create account)
    // - GET /players/:id (load player data)
    // - PATCH /players/:id (update player data)
    // For now, using local UserDefaults to maintain state between sessions
    
    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(playerId, forKey: "playerId")
        defaults.set(name, forKey: "playerName")
        defaults.set(isAlive, forKey: "isAlive")
        defaults.set(gold, forKey: "gold")
        defaults.set(currentKingdom, forKey: "currentKingdom")
        defaults.set(lastCheckIn, forKey: "lastCheckIn")
        defaults.set(homeKingdomId, forKey: "homeKingdomId")
        defaults.set(originKingdomId, forKey: "originKingdomId")
        
        // Check-in history (stored as JSON)
        if let jsonData = try? JSONEncoder().encode(checkInHistory) {
            defaults.set(jsonData, forKey: "checkInHistory")
        }
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
        defaults.set(lastDailyCheckIn, forKey: "lastDailyCheckIn")
        defaults.set(attackDebuff, forKey: "attackDebuff")
        defaults.set(debuffExpires, forKey: "debuffExpires")
        
        // Progression
        defaults.set(reputation, forKey: "reputation")
        defaults.set(level, forKey: "level")
        defaults.set(experience, forKey: "experience")
        defaults.set(skillPoints, forKey: "skillPoints")
        
        // Combat stats
        defaults.set(attackPower, forKey: "attackPower")
        defaults.set(defensePower, forKey: "defensePower")
        defaults.set(leadership, forKey: "leadership")
        defaults.set(buildingSkill, forKey: "buildingSkill")
        
        // Kingdom reputation (stored as JSON)
        if let jsonData = try? JSONEncoder().encode(kingdomReputation) {
            defaults.set(jsonData, forKey: "kingdomReputation")
        }
        
        // Reward tracking
        defaults.set(totalRewardsReceived, forKey: "totalRewardsReceived")
        defaults.set(lastRewardReceived, forKey: "lastRewardReceived")
        defaults.set(lastRewardAmount, forKey: "lastRewardAmount")
        
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
        homeKingdomId = defaults.string(forKey: "homeKingdomId")
        originKingdomId = defaults.string(forKey: "originKingdomId")
        
        // Check-in history
        if let jsonData = defaults.data(forKey: "checkInHistory"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: jsonData) {
            checkInHistory = decoded
        }
        
        if let lat = defaults.object(forKey: "lastCheckInLat") as? Double,
           let lon = defaults.object(forKey: "lastCheckInLon") as? Double {
            lastCheckInLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        if let fiefs = defaults.array(forKey: "fiefsRuled") as? [String] {
            fiefsRuled = Set(fiefs)
        }
        
        // Ensure isRuler stays in sync with fiefsRuled
        isRuler = defaults.bool(forKey: "isRuler") || !fiefsRuled.isEmpty
        activeContractId = defaults.string(forKey: "activeContractId")
        contractsCompleted = defaults.integer(forKey: "contractsCompleted")
        totalWorkContributed = defaults.integer(forKey: "totalWorkContributed")
        coupsWon = defaults.integer(forKey: "coupsWon")
        coupsFailed = defaults.integer(forKey: "coupsFailed")
        timesExecuted = defaults.integer(forKey: "timesExecuted")
        executionsOrdered = defaults.integer(forKey: "executionsOrdered")
        lastCoupAttempt = defaults.object(forKey: "lastCoupAttempt") as? Date
        lastDailyCheckIn = defaults.object(forKey: "lastDailyCheckIn") as? Date
        attackDebuff = defaults.integer(forKey: "attackDebuff")
        debuffExpires = defaults.object(forKey: "debuffExpires") as? Date
        
        // Progression
        reputation = defaults.integer(forKey: "reputation")
        level = defaults.integer(forKey: "level")
        if level == 0 { level = 1 }  // Default to level 1
        experience = defaults.integer(forKey: "experience")
        skillPoints = defaults.integer(forKey: "skillPoints")
        
        // Combat stats
        attackPower = defaults.integer(forKey: "attackPower")
        if attackPower == 0 { attackPower = 1 }  // Default to 1
        defensePower = defaults.integer(forKey: "defensePower")
        if defensePower == 0 { defensePower = 1 }
        leadership = defaults.integer(forKey: "leadership")
        if leadership == 0 { leadership = 1 }
        buildingSkill = defaults.integer(forKey: "buildingSkill")
        if buildingSkill == 0 { buildingSkill = 1 }
        
        // Kingdom reputation
        if let jsonData = defaults.data(forKey: "kingdomReputation"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: jsonData) {
            kingdomReputation = decoded
        }
        
        // Reward tracking
        totalRewardsReceived = defaults.integer(forKey: "totalRewardsReceived")
        lastRewardReceived = defaults.object(forKey: "lastRewardReceived") as? Date
        lastRewardAmount = defaults.integer(forKey: "lastRewardAmount")
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

