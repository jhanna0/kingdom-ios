import Foundation
import CoreLocation
import Combine

/// Player model - represents the local player
class Player: ObservableObject {
    // Identity
    @Published var playerId: Int  // Backend PostgreSQL auto-generated ID
    @Published var name: String
    
    // Status
    @Published var isAlive: Bool = true
    @Published var gold: Int = 100  // Starting gold
    
    // Location & Check-in
    @Published var currentKingdom: String?  // Kingdom player is currently in (ID)
    @Published var currentKingdomName: String?  // Kingdom player is currently in (name)
    @Published var lastCheckIn: Date?
    @Published var lastCheckInLocation: CLLocationCoordinate2D?
    
    // Player History & Home
    @Published var hometownKingdomId: String?  // Their hometown (set on first check-in) - used for royal blue territory color
    @Published var checkInHistory: [String: Int] = [:]  // kingdomId -> total check-ins
    
    // Power & Territory - ALL VALUES FROM BACKEND ONLY
    @Published var ruledKingdomIds: Set<String> = []  // Kingdom IDs this player rules (from backend)
    @Published var ruledKingdomNames: Set<String> = []  // Kingdom names this player rules (from backend)
    @Published var isRuler: Bool = false  // Whether player rules ANY kingdom (from backend is_ruler)
    
    // Work & Contracts
    @Published var contractsCompleted: Int = 0
    @Published var totalWorkContributed: Int = 0
    @Published var totalTrainingPurchases: Int = 0  // Global training counter for cost scaling
    
    // Training contracts (active training)
    @Published var trainingContracts: [TrainingContractData] = []
    
    // Training cost (from backend) - UNIFIED cost for ALL skills based on total skill points
    @Published var trainingCost: Int = 100
    
    // Active perks (from backend)
    @Published var activePerks: PlayerPerks?
    
    // DYNAMIC SKILLS DATA from backend - renders skills without hardcoding!
    @Published var skillsData: [SkillData] = []
    
    /// Skill data from backend for dynamic rendering
    struct SkillData: Identifiable {
        let skillType: String
        let displayName: String
        let icon: String
        let category: String
        let description: String
        let currentTier: Int
        let maxTier: Int
        let trainingCost: Int
        let currentBenefits: [String]
        let displayOrder: Int
        
        var id: String { skillType }
    }
    
    // Resources (legacy individual properties - kept for backwards compatibility)
    @Published var iron: Int = 0
    @Published var steel: Int = 0
    @Published var wood: Int = 0
    
    // DYNAMIC RESOURCES DATA from backend - renders inventory without hardcoding!
    // This is the source of truth - use this for dynamic inventory rendering
    @Published var resourcesData: [ResourceData] = []
    
    /// Dynamic resource data from backend for rendering
    struct ResourceData: Identifiable {
        let key: String           // Resource key (gold, iron, steel, wood, etc.)
        let amount: Int           // Current amount player has
        let displayName: String   // "Gold", "Iron", etc.
        let icon: String          // SF Symbol name
        let colorName: String     // Theme color name
        let category: String      // "currency", "material", etc.
        let displayOrder: Int     // Sort order
        let description: String   // Description for tooltip/toast
        
        var id: String { key }
    }
    
    // Crafting contracts (active crafting)
    @Published var craftingQueue: [CraftingContractData] = []
    
    // Equipment
    @Published var equippedWeapon: EquipmentData?
    @Published var equippedArmor: EquipmentData?
    @Published var inventory: [EquipmentData] = []
    
    // Pets - companion creatures collected from activities
    @Published var pets: [PlayerPet] = []
    @Published var petsEmptyState: PetsEmptyState = PetsEmptyState()
    
    /// Pet data from backend
    struct PlayerPet: Identifiable {
        let id: String        // e.g., "pet_fish"
        let quantity: Int
        let displayName: String
        let icon: String
        let colorName: String
        let description: String
        let source: String?
    }
    
    /// Empty state config from backend - NO HARDCODING!
    struct PetsEmptyState {
        var title: String = "No pets yet"
        var message: String = "Complete activities to find companions!"
        var icon: String = "pawprint.circle"
    }
    
    // Properties (land ownership)
    @Published var ownedProperties: [PlayerProperty] = []
    
    /// Check if player has a Workshop (property tier 3+) anywhere
    var hasWorkshop: Bool {
        return ownedProperties.contains { $0.tier >= 3 }
    }
    
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
    @Published var intelligence: Int = 1        // Sabotage/patrol efficiency
    @Published var science: Int = 1             // Better weapons/armor crafting
    @Published var faith: Int = 1               // Divine interventions and battle buffs
    
    // Kingdom-specific reputation
    @Published var kingdomReputation: [String: Int] = [:]  // kingdomId -> rep
    
    // Cooldowns
    @Published var lastCoupAttempt: Date?
    @Published var lastDailyCheckIn: Date?      // For daily bonuses
    
    // Action System Cooldowns
    @Published var lastWorkAction: Date?
    @Published var lastPatrolAction: Date?
    @Published var lastSabotageAction: Date?
    @Published var lastMiningAction: Date?
    @Published var lastScoutAction: Date?
    @Published var patrolExpiresAt: Date?       // When current patrol ends (10 min)
    
    // Temporary debuffs (from failed battles)
    @Published var attackDebuff: Int = 0        // Temporary attack reduction
    @Published var debuffExpires: Date?         // When the debuff ends
    
    // Game configuration
    let checkInValidHours: Double = 4  // Check-ins expire after 4 hours
    let checkInRadiusMeters: Double = 100  // Must be within 100m to check in
    let coupCooldownHours: Double = 24
    
    init(playerId: Int = 0, name: String = "Player") {
        self.playerId = playerId
        self.name = name
        
        // NO LOCAL CACHING - Backend is source of truth!
        // All state will be loaded from API on app init
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
        }
        
        // Backend is source of truth - no local caching
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
        
        // Backend is source of truth - no local caching
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
        // Backend is source of truth - no local caching
    }
    
    // MARK: - Training
    // Training is now handled via backend API calls (see CharacterSheetView)
    // Costs are calculated on the backend and included in player state
    
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
        
        // Backend is source of truth - no local caching
        return true
    }
    
    enum SkillStat {
        case attack, defense, leadership, building
    }
    
    struct TrainingContractData: Codable, Identifiable {
        let id: String
        let type: String
        let actionsRequired: Int
        let actionsCompleted: Int
        let costPaid: Int
        let createdAt: String
        let status: String
        
        enum CodingKeys: String, CodingKey {
            case id, type, status
            case actionsRequired = "actions_required"
            case actionsCompleted = "actions_completed"
            case costPaid = "cost_paid"
            case createdAt = "created_at"
        }
    }
    
    struct PlayerPerks {
        var combatPerks: [PerkItem] = []
        var trainingPerks: [PerkItem] = []
        var buildingPerks: [PerkItem] = []
        var espionagePerks: [PerkItem] = []
        var politicalPerks: [PerkItem] = []
        var travelPerks: [PerkItem] = []
        var totalPower: Int = 0
    }
    
    struct PerkItem: Identifiable {
        let id = UUID()
        let stat: String?
        let bonus: Int?
        let description: String?
        let source: String
        let sourceType: String
        let expiresAt: Date?
    }
    
    struct CraftingContractData: Codable, Identifiable {
        let id: String
        let equipmentType: String
        let tier: Int
        let actionsRequired: Int
        let actionsCompleted: Int
        let goldPaid: Int
        let ironPaid: Int
        let steelPaid: Int
        let createdAt: String
        let status: String
        
        enum CodingKeys: String, CodingKey {
            case id, tier, status
            case equipmentType = "equipment_type"
            case actionsRequired = "actions_required"
            case actionsCompleted = "actions_completed"
            case goldPaid = "gold_paid"
            case ironPaid = "iron_paid"
            case steelPaid = "steel_paid"
            case createdAt = "created_at"
        }
        
        var progress: Double {
            return Double(actionsCompleted) / Double(actionsRequired)
        }
    }
    
    struct EquipmentData: Codable, Identifiable {
        let id: String
        let type: String
        let tier: Int
        let attackBonus: Int
        let defenseBonus: Int
        let craftedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, type, tier
            case attackBonus = "attack_bonus"
            case defenseBonus = "defense_bonus"
            case craftedAt = "crafted_at"
        }
    }
    
    /// Check if there's an active training contract
    func hasActiveTrainingContract() -> Bool {
        return trainingContracts.contains { $0.status != "completed" }
    }
    
    /// Get the active training contract if any
    func getActiveTrainingContract() -> TrainingContractData? {
        return trainingContracts.first { $0.status != "completed" }
    }
    
    /// Check if there's an active crafting contract
    func hasActiveCraftingContract() -> Bool {
        return craftingQueue.contains { $0.status != "completed" }
    }
    
    /// Get the active crafting contract if any
    func getActiveCraftingContract() -> CraftingContractData? {
        return craftingQueue.first { $0.status != "completed" }
    }
    
    /// Get total attack power including equipment
    func getTotalAttackPower() -> Int {
        return attackPower + (equippedWeapon?.attackBonus ?? 0)
    }
    
    /// Get total defense power including equipment
    func getTotalDefensePower() -> Int {
        return defensePower + (equippedArmor?.defenseBonus ?? 0)
    }
    
    // Training costs are now provided by the backend in player state
    // No local calculation needed!
    
    // NOTE: Building cost discounts calculated by backend
    // Backend accounts for building_skill when returning costs
    
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
        
        // Backend is source of truth - no local caching
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
    
    // NOTE: XP purchase removed (dead content)
    
    // MARK: - Check-in Logic
    
    /// Check if player has a valid check-in
    func isCheckedIn() -> Bool {
        guard let lastCheckIn = lastCheckIn else { return false }
        let elapsed = Date().timeIntervalSince(lastCheckIn)
        return elapsed < (checkInValidHours * 3600)
    }
    
    // NOTE: Check-in logic handled by backend
    // Backend validates location, updates check-in history, and determines home kingdom
    // These local methods are legacy and should use backend data instead
    
    // MARK: - Territory Management
    // NOTE: All ruler status is determined by backend only!
    // Use updateRuledKingdoms() to sync from backend data
    
    /// Update ruled kingdoms from backend data (e.g., from /notifications/updates)
    func updateRuledKingdoms(kingdoms: [(id: String, name: String)]) {
        ruledKingdomIds = Set(kingdoms.map { $0.id })
        ruledKingdomNames = Set(kingdoms.map { $0.name })
        // Note: isRuler is set separately from /player/state's is_ruler field
        print("👑 Ruled kingdoms synced from backend: \(ruledKingdomNames)")
    }
    
    /// Check if player rules a specific kingdom by ID
    func rulesKingdom(id: String) -> Bool {
        return ruledKingdomIds.contains(id)
    }
    
    /// Check if player rules a specific kingdom by name
    func rulesKingdom(name: String) -> Bool {
        return ruledKingdomNames.contains(name)
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
        // Backend is source of truth - no local caching
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
        // Backend is source of truth - no local caching
    }
    
    /// Clear debuffs if they've expired
    func clearExpiredDebuffs() {
        guard let expires = debuffExpires else { return }
        
        if Date() >= expires {
            attackDebuff = 0
            debuffExpires = nil
            // Backend is source of truth - no local caching
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
        
        // Backend is source of truth - no local caching
    }
    
    /// Apply catastrophic penalty for overthrown ruler who failed to flee
    /// NOTE: This is a local preview - actual state comes from backend after sync
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
        
        // NOTE: Do NOT set isRuler locally - backend is source of truth
        // Ruler status will be updated when we sync from /player/state
    }
    
    // MARK: - Economy
    
    /// Add gold to player
    func addGold(_ amount: Int) {
        gold += amount
        // Backend is source of truth - no local caching
    }
    
    /// Try to spend gold
    func spendGold(_ amount: Int) -> Bool {
        guard gold >= amount else { return false }
        gold -= amount
        // Backend is source of truth - no local caching
        return true
    }
    
    // MARK: - Utilities
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)  // Returns meters
    }
    
    // MARK: - API Sync
    
    /// Convert player state to dictionary for API sync
    func toAPIState() -> [String: Any] {
        var state: [String: Any] = [:]
        
        // Core Stats
        state["gold"] = gold
        state["level"] = level
        state["experience"] = experience
        state["skill_points"] = skillPoints
        
        // Combat Stats
        state["attack_power"] = attackPower
        state["defense_power"] = defensePower
        state["leadership"] = leadership
        state["building_skill"] = buildingSkill
        state["intelligence"] = intelligence
        
        // Debuffs
        state["attack_debuff"] = attackDebuff
        if let expires = debuffExpires {
            state["debuff_expires_at"] = ISO8601DateFormatter().string(from: expires)
        }
        
        // Reputation
        state["reputation"] = reputation
        // Note: kingdom_reputation is now in user_kingdoms table (backend)
        
        // Territory
        state["current_kingdom_id"] = currentKingdom
        state["hometown_kingdom_id"] = hometownKingdomId
        // Note: fiefs_ruled and is_ruler are computed by backend
        
        // Check-in data is now in user_kingdoms and action_cooldowns tables
        // These fields no longer accepted by backend API
        
        // Activity
        state["coups_won"] = coupsWon
        state["coups_failed"] = coupsFailed
        state["times_executed"] = timesExecuted
        state["executions_ordered"] = executionsOrdered
        // Note: last_coup_attempt is now in action_cooldowns table (backend)
        
        // Contract & Work
        state["contracts_completed"] = contractsCompleted
        state["total_work_contributed"] = totalWorkContributed
        state["total_training_purchases"] = totalTrainingPurchases
        
        // Status
        state["is_alive"] = isAlive
        
        return state
    }
    
    /// Update player from API state
    func updateFromAPIState(_ apiState: APIPlayerState) {
        // Core Stats
        gold = apiState.gold
        level = apiState.level
        experience = apiState.experience
        skillPoints = apiState.skill_points
        
        // Combat Stats
        attackPower = apiState.attack_power
        defensePower = apiState.defense_power
        leadership = apiState.leadership
        buildingSkill = apiState.building_skill
        intelligence = apiState.intelligence
        science = apiState.science
        faith = apiState.faith
        
        // Debuffs
        attackDebuff = apiState.attack_debuff
        if let expiresStr = apiState.debuff_expires_at {
            debuffExpires = ISO8601DateFormatter().date(from: expiresStr)
        }
        
        // Reputation
        reputation = apiState.reputation
        // Note: kingdom_reputation has been moved to user_kingdoms table in backend
        // TODO: Fetch from separate endpoint if needed
        
        // Territory
        currentKingdom = apiState.current_kingdom_id
        currentKingdomName = apiState.current_kingdom_name
        hometownKingdomId = apiState.hometown_kingdom_id
        // Note: fiefs_ruled is now computed in backend from kingdoms table
        isRuler = apiState.is_ruler
        
        print("🌍 Player territory synced from API:")
        print("   - Current Kingdom: \(currentKingdom ?? "nil")")
        print("   - Hometown Kingdom: \(hometownKingdomId ?? "nil") [ROYAL BLUE]")
        print("   - Is Ruler: \(isRuler)")
        
        // Check-in data moved to user_kingdoms table and action_cooldowns
        // Note: These fields were removed from backend in cleanup_player_state.sql
        // TODO: Fetch check_in_history from user_kingdoms endpoint if needed
        // TODO: Fetch last_check_in and last_daily_check_in from action_cooldowns if needed
        
        // Activity
        coupsWon = apiState.coups_won
        coupsFailed = apiState.coups_failed
        timesExecuted = apiState.times_executed
        executionsOrdered = apiState.executions_ordered
        // Note: last_coup_attempt moved to action_cooldowns table
        // TODO: Fetch from action_cooldowns endpoint if needed
        
        // Contract & Work
        contractsCompleted = apiState.contracts_completed
        totalWorkContributed = apiState.total_work_contributed
        totalTrainingPurchases = apiState.total_training_purchases
        
        // Training cost from backend - ALL skills have the SAME cost based on total skill points
        if let costs = apiState.training_costs {
            // All costs should be identical - just use attack as the unified value
            trainingCost = costs.attack
            print("💰 Updated unified training cost: \(costs.attack)g for ALL skills")
            print("   (Backend sent: attack=\(costs.attack), defense=\(costs.defense), leadership=\(costs.leadership), building=\(costs.building))")
        } else {
            print("⚠️ No training costs in API response")
        }
        
        // Training contracts from backend (Note: this comes from action status, not player state)
        // The trainingContracts will be updated when action status is fetched
        
        // Resources (legacy individual properties)
        iron = apiState.iron
        steel = apiState.steel
        wood = apiState.wood
        
        // DYNAMIC RESOURCES DATA from backend - no more hardcoding!
        if let apiResourcesData = apiState.resources_data {
            resourcesData = apiResourcesData
                .sorted { $0.display_order < $1.display_order }
                .map { apiResource in
                    ResourceData(
                        key: apiResource.key,
                        amount: apiResource.amount,
                        displayName: apiResource.display_name,
                        icon: apiResource.icon,
                        colorName: apiResource.color,
                        category: apiResource.category,
                        displayOrder: apiResource.display_order,
                        description: apiResource.description ?? ""
                    )
                }
            print("📦 Loaded \(resourcesData.count) resources from backend dynamically!")
        }
        
        // PETS - companion creatures from backend
        if let apiPets = apiState.pets {
            pets = apiPets.map { pet in
                PlayerPet(
                    id: pet.id,
                    quantity: pet.quantity,
                    displayName: pet.display_name,
                    icon: pet.icon,
                    colorName: pet.color,
                    description: pet.description,
                    source: pet.source
                )
            }
            if !pets.isEmpty {
                print("🐟 Loaded \(pets.count) pet type(s) from backend!")
            }
        }
        
        // Pets config (empty state text from backend)
        if let config = apiState.pets_config {
            petsEmptyState = PetsEmptyState(
                title: config.empty_state.title,
                message: config.empty_state.message,
                icon: config.empty_state.icon
            )
        }
        
        // Equipment
        if let weaponData = apiState.equipped_weapon {
            equippedWeapon = try? JSONDecoder().decode(EquipmentData.self, from: JSONEncoder().encode(weaponData))
        } else {
            equippedWeapon = nil
        }
        
        if let armorData = apiState.equipped_armor {
            equippedArmor = try? JSONDecoder().decode(EquipmentData.self, from: JSONEncoder().encode(armorData))
        } else {
            equippedArmor = nil
        }
        
        if let inventoryData = apiState.inventory {
            inventory = inventoryData.compactMap { item in
                try? JSONDecoder().decode(EquipmentData.self, from: JSONEncoder().encode(item))
            }
        }
        
        // Properties
        if let propertiesData = apiState.properties {
            ownedProperties = propertiesData.map { item in
                PlayerProperty(id: item.id, kingdomId: item.kingdom_id, tier: item.tier)
            }
            print("🏠 Loaded \(ownedProperties.count) properties, hasWorkshop: \(hasWorkshop)")
        }
        
        // Status
        isAlive = apiState.is_alive
        
        // Active perks from backend
        if let perksData = apiState.active_perks {
            var perks = PlayerPerks()
            perks.totalPower = perksData.total_power
            
            // Parse combat perks
            perks.combatPerks = perksData.combat.map { parsePerkEntry($0) }
            
            // Parse training perks
            perks.trainingPerks = perksData.training.map { parsePerkEntry($0) }
            
            // Parse building perks
            perks.buildingPerks = perksData.building.map { parsePerkEntry($0) }
            
            // Parse espionage perks
            perks.espionagePerks = perksData.espionage.map { parsePerkEntry($0) }
            
            // Parse political perks
            perks.politicalPerks = perksData.political.map { parsePerkEntry($0) }
            
            // Parse travel perks
            perks.travelPerks = perksData.travel.map { parsePerkEntry($0) }
            
            activePerks = perks
            print("✨ Updated \(perks.totalPower) total power with perks")
        }
        
        // DYNAMIC SKILLS DATA from backend - no more hardcoding skill lists!
        if let apiSkillsData = apiState.skills_data {
            skillsData = apiSkillsData
                .sorted { $0.display_order < $1.display_order }
                .map { apiSkill in
                    SkillData(
                        skillType: apiSkill.skill_type,
                        displayName: apiSkill.display_name,
                        icon: apiSkill.icon,
                        category: apiSkill.category,
                        description: apiSkill.description,
                        currentTier: apiSkill.current_tier,
                        maxTier: apiSkill.max_tier,
                        trainingCost: apiSkill.training_cost,
                        currentBenefits: apiSkill.current_benefits,
                        displayOrder: apiSkill.display_order
                    )
                }
            print("🎯 Loaded \(skillsData.count) skills from backend dynamically!")
        }
        
        // Backend is source of truth - no local caching
        
        print("✅ Player state updated from API")
    }
    
    private func parsePerkEntry(_ entry: APIPlayerState.PerkEntry) -> PerkItem {
        let expiresAt: Date? = {
            if let expiresStr = entry.expires_at {
                return ISO8601DateFormatter().date(from: expiresStr)
            }
            return nil
        }()
        
        return PerkItem(
            stat: entry.stat,
            bonus: entry.bonus,
            description: entry.description,
            source: entry.source,
            sourceType: entry.source_type,
            expiresAt: expiresAt
        )
    }
    
    /// Sync player state with API
    func syncWithAPI() async {
        let api = KingdomAPIService.shared
        guard api.isAuthenticated else {
            print("⚠️ Cannot sync - not authenticated")
            return
        }
        
        do {
            let response = try await api.player.syncState(toAPIState())
            
            await MainActor.run {
                self.updateFromAPIState(response.player_state)
            }
            
            print("✅ Player synced with server")
        } catch {
            print("❌ Failed to sync player: \(error)")
        }
    }
    
    /// Load player state from API
    func loadFromAPI() async {
        let api = KingdomAPIService.shared
        guard api.isAuthenticated else {
            print("⚠️ Cannot load from API - not authenticated")
            return
        }
        
        do {
            let apiState = try await api.player.loadState()
            
            await MainActor.run {
                self.updateFromAPIState(apiState)
            }
            
            print("✅ Player loaded from API")
        } catch {
            print("❌ Failed to load player from API: \(error)")
            // Backend is source of truth - no fallback to local cache
        }
    }
    
    /// Save player state to API
    func saveToAPI() async {
        let api = KingdomAPIService.shared
        guard api.isAuthenticated else {
            print("⚠️ Cannot save to API - not authenticated")
            // Backend is source of truth - cannot save without authentication
            return
        }
        
        do {
            let updatedState = try await api.player.saveState(toAPIState())
            
            await MainActor.run {
                self.updateFromAPIState(updatedState)
            }
            
            print("✅ Player saved to API")
        } catch {
            print("❌ Failed to save player to API: \(error)")
            // Backend is source of truth - no fallback to local storage
        }
    }
    
    // MARK: - NO LOCAL CACHING
    // Backend is the single source of truth for all player state!
    // All data is loaded via loadFromAPI() and saved via saveToAPI()
    
    /// Reset player data (for testing/debugging)
    func reset() {
        gold = 100
        ruledKingdomIds.removeAll()
        ruledKingdomNames.removeAll()
        isRuler = false  // Will be set from backend on next sync
        currentKingdom = nil
        lastCheckIn = nil
        lastCheckInLocation = nil
        coupsWon = 0
        coupsFailed = 0
        timesExecuted = 0
        executionsOrdered = 0
        lastCoupAttempt = nil
        ownedProperties = []
        // Backend is source of truth - no local caching
    }
}

/// Simple property data for player ownership check
struct PlayerProperty: Identifiable {
    let id: String
    let kingdomId: String
    let tier: Int
}

