import Foundation
import Combine

// MARK: - Equipment System

enum EquipmentType: String, Codable, CaseIterable {
    case sword
    case armor
    case shield
    case bow
    case lance
    
    var name: String {
        return rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .sword: return "🗡️"
        case .armor: return "🛡️"
        case .shield: return "🛡️"
        case .bow: return "🏹"
        case .lance: return "⚔️"
        }
    }
    
    var slot: EquipmentSlot {
        switch self {
        case .sword, .bow, .lance: return .weapon
        case .armor: return .armor
        case .shield: return .shield
        }
    }
}

enum EquipmentSlot: String, Codable {
    case weapon
    case armor
    case shield
}

struct Equipment: Identifiable, Codable, Hashable {
    let id: UUID
    let type: EquipmentType
    let tier: Int  // 1-5
    let craftStartTime: Date
    let craftDuration: TimeInterval  // Real-world seconds
    
    var isComplete: Bool {
        return Date() >= completionTime
    }
    
    var completionTime: Date {
        return craftStartTime.addingTimeInterval(craftDuration)
    }
    
    var timeRemaining: TimeInterval {
        let remaining = completionTime.timeIntervalSince(Date())
        return max(0, remaining)
    }
    
    // Stat bonuses based on tier - use TierManager as source of truth
    var attackBonus: Int {
        guard type.slot == .weapon else { return 0 }
        return TierManager.shared.equipmentTierStatBonus(tier)
    }
    
    var defenseBonus: Int {
        guard type.slot == .armor || type.slot == .shield else { return 0 }
        return TierManager.shared.equipmentTierStatBonus(tier)
    }
    
    // Death risk based on weapon type
    var deathRiskOnLoss: Double {
        switch type {
        case .bow: return 0.75  // 75% death risk
        case .sword, .lance: return 1.0  // 100% death risk
        default: return 0.5  // Default for other weapons
        }
    }
    
    // Crafting time in days (from docs)
    // Tier 1: 1 day, Tier 2: 3 days, Tier 3: 7 days, Tier 4: 14 days, Tier 5: 30 days
    static func getCraftDuration(tier: Int) -> TimeInterval {
        switch tier {
        case 1: return 24 * 3600      // 1 day
        case 2: return 3 * 24 * 3600  // 3 days
        case 3: return 7 * 24 * 3600  // 7 days
        case 4: return 14 * 24 * 3600 // 14 days
        case 5: return 30 * 24 * 3600 // 30 days
        default: return 24 * 3600
        }
    }
    
    // Days of daily work required (from docs)
    static func getDaysRequired(tier: Int) -> Int {
        switch tier {
        case 1: return 1
        case 2: return 3
        case 3: return 7
        case 4: return 14
        case 5: return 30
        default: return 1
        }
    }
    
    // Gold cost to start crafting - use TierManager as source of truth
    static func getCraftCost(tier: Int) -> Int {
        return TierManager.shared.equipmentTierCost(tier).gold
    }
    
    // Resource requirements - use TierManager as source of truth
    static func getIronRequired(tier: Int) -> Int {
        return TierManager.shared.equipmentTierCost(tier).iron
    }
    
    static func getSteelRequired(tier: Int) -> Int {
        return TierManager.shared.equipmentTierCost(tier).steel
    }
    
    init(type: EquipmentType, tier: Int) {
        self.id = UUID()
        self.type = type
        self.tier = tier
        self.craftStartTime = Date()
        self.craftDuration = Equipment.getCraftDuration(tier: tier)
    }
}

// MARK: - Player Resources (to be added to Player class)
// Note: These properties should be added directly to the Player class in Player.swift
// The extension pattern with @Published doesn't work in Swift

/// Tracks a player's resources and equipment (stored in UserDefaults)
class PlayerResources: ObservableObject, Codable {
    @Published var iron: Int = 0
    @Published var steel: Int = 0
    @Published var equippedWeapon: Equipment?
    @Published var equippedArmor: Equipment?
    @Published var equippedShield: Equipment?
    @Published var craftingQueue: [Equipment] = []
    @Published var inventory: [Equipment] = []
    @Published var properties: [Property] = []  // Owned properties
    
    // Daily action tracking (can only do each action ONCE per day)
    @Published var lastMiningAction: Date?
    @Published var lastCraftingAction: Date?
    @Published var lastBuildingAction: Date?
    @Published var lastSpyAction: Date?
    @Published var craftingProgress: [String: Int] = [:]  // equipmentId -> days worked
    
    enum CodingKeys: String, CodingKey {
        case iron, steel, equippedWeapon, equippedArmor, equippedShield
        case craftingQueue, inventory, properties
        case lastMiningAction, lastCraftingAction, lastBuildingAction, lastSpyAction
        case craftingProgress
    }
    
    init() {}
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iron = try container.decodeIfPresent(Int.self, forKey: .iron) ?? 0
        steel = try container.decodeIfPresent(Int.self, forKey: .steel) ?? 0
        equippedWeapon = try container.decodeIfPresent(Equipment.self, forKey: .equippedWeapon)
        equippedArmor = try container.decodeIfPresent(Equipment.self, forKey: .equippedArmor)
        equippedShield = try container.decodeIfPresent(Equipment.self, forKey: .equippedShield)
        craftingQueue = try container.decodeIfPresent([Equipment].self, forKey: .craftingQueue) ?? []
        inventory = try container.decodeIfPresent([Equipment].self, forKey: .inventory) ?? []
        properties = try container.decodeIfPresent([Property].self, forKey: .properties) ?? []
        lastMiningAction = try container.decodeIfPresent(Date.self, forKey: .lastMiningAction)
        lastCraftingAction = try container.decodeIfPresent(Date.self, forKey: .lastCraftingAction)
        lastBuildingAction = try container.decodeIfPresent(Date.self, forKey: .lastBuildingAction)
        lastSpyAction = try container.decodeIfPresent(Date.self, forKey: .lastSpyAction)
        craftingProgress = try container.decodeIfPresent([String: Int].self, forKey: .craftingProgress) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(iron, forKey: .iron)
        try container.encode(steel, forKey: .steel)
        try container.encodeIfPresent(equippedWeapon, forKey: .equippedWeapon)
        try container.encodeIfPresent(equippedArmor, forKey: .equippedArmor)
        try container.encodeIfPresent(equippedShield, forKey: .equippedShield)
        try container.encode(craftingQueue, forKey: .craftingQueue)
        try container.encode(inventory, forKey: .inventory)
        try container.encode(properties, forKey: .properties)
        try container.encodeIfPresent(lastMiningAction, forKey: .lastMiningAction)
        try container.encodeIfPresent(lastCraftingAction, forKey: .lastCraftingAction)
        try container.encodeIfPresent(lastBuildingAction, forKey: .lastBuildingAction)
        try container.encodeIfPresent(lastSpyAction, forKey: .lastSpyAction)
        try container.encode(craftingProgress, forKey: .craftingProgress)
    }
    
    // MARK: - Daily Action Checks
    
    func canMineToday() -> Bool {
        guard let lastAction = lastMiningAction else { return true }
        return !Calendar.current.isDateInToday(lastAction)
    }
    
    func canCraftToday() -> Bool {
        guard let lastAction = lastCraftingAction else { return true }
        return !Calendar.current.isDateInToday(lastAction)
    }
    
    func canBuildToday() -> Bool {
        guard let lastAction = lastBuildingAction else { return true }
        return !Calendar.current.isDateInToday(lastAction)
    }
    
    func canSpyToday() -> Bool {
        guard let lastAction = lastSpyAction else { return true }
        return !Calendar.current.isDateInToday(lastAction)
    }
    
    // MARK: - Mining
    
    /// Mine resources from kingdom (once per day, applies tax)
    func mineResources(from kingdom: Kingdom) -> (iron: Int, steel: Int, taxPaid: Int)? {
        guard canMineToday() else { return nil }
        
        lastMiningAction = Date()
        
        // Get resources based on mine level (from docs)
        let ironMined = kingdom.getIronPerMiningAction()
        let steelMined = kingdom.getSteelPerMiningAction()
        
        // Calculate tax
        let totalValue = ironMined + (steelMined * 2)  // Steel is worth more
        let taxAmount = kingdom.calculateTax(on: totalValue)
        
        // After tax, player keeps the resources
        iron += ironMined
        steel += steelMined
        
        // Backend is source of truth - no local caching
        
        return (ironMined, steelMined, taxAmount)
    }
    
    // MARK: - Crafting (Daily Work System)
    
    /// Start crafting a new item (requires resources + gold)
    func startCrafting(type: EquipmentType, tier: Int, playerGold: inout Int) -> Equipment? {
        let goldCost = Equipment.getCraftCost(tier: tier)
        let ironRequired = Equipment.getIronRequired(tier: tier)
        let steelRequired = Equipment.getSteelRequired(tier: tier)
        
        guard playerGold >= goldCost else { return nil }
        guard iron >= ironRequired else { return nil }
        guard steel >= steelRequired else { return nil }
        
        playerGold -= goldCost
        iron -= ironRequired
        steel -= steelRequired
        
        let equipment = Equipment(type: type, tier: tier)
        craftingQueue.append(equipment)
        craftingProgress[equipment.id.uuidString] = 0
        
        // Backend is source of truth - no local caching
        return equipment
    }
    
    /// Work on crafting (once per day) - adds 1 day of progress
    func workOnCrafting(equipmentId: String) -> Bool {
        guard canCraftToday() else { return false }
        guard craftingQueue.contains(where: { $0.id.uuidString == equipmentId }) else { return false }
        
        lastCraftingAction = Date()
        craftingProgress[equipmentId, default: 0] += 1
        
        // Check if complete
        if let index = craftingQueue.firstIndex(where: { $0.id.uuidString == equipmentId }) {
            let equipment = craftingQueue[index]
            let daysRequired = Equipment.getDaysRequired(tier: equipment.tier)
            let daysWorked = craftingProgress[equipmentId] ?? 0
            
            if daysWorked >= daysRequired {
                // Move to inventory
                craftingQueue.remove(at: index)
                inventory.append(equipment)
                craftingProgress.removeValue(forKey: equipmentId)
            }
        }
        
        // Backend is source of truth - no local caching
        return true
    }
    
    /// Get days remaining for an item being crafted
    func getCraftingDaysRemaining(equipmentId: String) -> Int? {
        guard let equipment = craftingQueue.first(where: { $0.id.uuidString == equipmentId }) else { return nil }
        let daysRequired = Equipment.getDaysRequired(tier: equipment.tier)
        let daysWorked = craftingProgress[equipmentId] ?? 0
        return max(0, daysRequired - daysWorked)
    }
    
    // MARK: - Equipment Management
    
    func equip(_ equipment: Equipment) -> Bool {
        guard inventory.contains(where: { $0.id == equipment.id }) else { return false }
        
        switch equipment.type.slot {
        case .weapon:
            if let existing = equippedWeapon { inventory.append(existing) }
            equippedWeapon = equipment
        case .armor:
            if let existing = equippedArmor { inventory.append(existing) }
            equippedArmor = equipment
        case .shield:
            if let existing = equippedShield { inventory.append(existing) }
            equippedShield = equipment
        }
        
        inventory.removeAll { $0.id == equipment.id }
        // Backend is source of truth - no local caching
        return true
    }
    
    func unequip(slot: EquipmentSlot) {
        switch slot {
        case .weapon:
            if let equipment = equippedWeapon {
                inventory.append(equipment)
                equippedWeapon = nil
            }
        case .armor:
            if let equipment = equippedArmor {
                inventory.append(equipment)
                equippedArmor = nil
            }
        case .shield:
            if let equipment = equippedShield {
                inventory.append(equipment)
                equippedShield = nil
            }
        }
        // Backend is source of truth - no local caching
    }
    
    /// Total attack bonus from equipment
    var equipmentAttackBonus: Int {
        return (equippedWeapon?.attackBonus ?? 0)
    }
    
    /// Total defense bonus from equipment
    var equipmentDefenseBonus: Int {
        return (equippedArmor?.defenseBonus ?? 0) + (equippedShield?.defenseBonus ?? 0)
    }
    
    /// Lose weapon (from failed battle)
    func loseWeapon() {
        equippedWeapon = nil
        // Backend is source of truth - no local caching
    }
    
    /// Lose all equipment (from failed coup)
    func loseAllEquipment() {
        equippedWeapon = nil
        equippedArmor = nil
        equippedShield = nil
        // Backend is source of truth - no local caching
    }
    
    // MARK: - Properties
    
    func getPropertiesIn(kingdom: String) -> [Property] {
        return properties.filter { $0.kingdomName == kingdom }
    }
    
    func hasPropertyIn(kingdom: String) -> Bool {
        return properties.contains { $0.kingdomName == kingdom }
    }
    
    func addProperty(_ property: Property) {
        properties.append(property)
        // Backend is source of truth - no local caching
    }
    
    // MARK: - NO LOCAL CACHING
    // Backend is the single source of truth for all player resources!
    // All data is loaded from and saved to the API
}

// MARK: - Kingdom Resource Production
// From docs: ONE building (Mine) - steel comes from higher mine levels

extension Kingdom {
    /// Iron production per mining action (from docs)
    /// Mine Level 1: 10 Iron, Level 2: 20 Iron
    /// Level 3-4: No iron (steel only), Level 5: 10 Iron + Steel
    func getIronPerMiningAction() -> Int {
        switch buildingLevel("mine") {
        case 0: return 0
        case 1: return 10
        case 2: return 20
        case 3: return 0   // Steel only
        case 4: return 0   // Steel only
        case 5: return 10  // Both!
        default: return 0
        }
    }
    
    /// Steel production per mining action (from docs)
    /// Mine Level 3: 10 Steel, Level 4: 20 Steel, Level 5: 10 Steel + Iron
    func getSteelPerMiningAction() -> Int {
        switch buildingLevel("mine") {
        case 0: return 0
        case 1: return 0
        case 2: return 0
        case 3: return 10
        case 4: return 20
        case 5: return 10  // Both!
        default: return 0
        }
    }
    
    /// Damage production buildings (from invasion) - mine -2 levels
    mutating func damageProduction() {
        let currentLevel = buildingLevel("mine")
        buildingLevels["mine"] = max(0, currentLevel - 2)
    }
    
    /// Damage walls (from invasion)
    mutating func damageWalls() {
        let currentLevel = buildingLevel("wall")
        buildingLevels["wall"] = max(0, currentLevel - 2)
    }
}

// MARK: - Intel System

struct PlayerIntel: Identifiable, Codable {
    let id: String  // Player ID
    let name: String
    let originKingdom: String?
    let homeKingdom: String?
    let attackPower: Int
    let defensePower: Int
    let equippedWeapon: Equipment?
    let equippedArmor: Equipment?
    let equippedShield: Equipment?
    let checkInTime: Date
    
    var effectiveAttack: Int {
        return attackPower + (equippedWeapon?.attackBonus ?? 0)
    }
    
    var effectiveDefense: Int {
        return defensePower + (equippedArmor?.defenseBonus ?? 0) + (equippedShield?.defenseBonus ?? 0)
    }
    
    var isEnemy: Bool {
        // Check if from different kingdom (implement based on current kingdom context)
        return false  // TODO: Implement
    }
}

struct KingdomIntel: Codable {
    let kingdomId: String
    let kingdomName: String
    let checkedInPlayers: [PlayerIntel]
    let wallLevel: Int
    let vaultLevel: Int
    let lastUpdated: Date
    
    var totalDefenders: Int {
        return checkedInPlayers.count
    }
    
    var averageAttack: Double {
        guard !checkedInPlayers.isEmpty else { return 0 }
        let total = checkedInPlayers.reduce(0) { $0 + $1.effectiveAttack }
        return Double(total) / Double(checkedInPlayers.count)
    }
    
    var averageDefense: Double {
        guard !checkedInPlayers.isEmpty else { return 0 }
        let total = checkedInPlayers.reduce(0) { $0 + $1.effectiveDefense }
        return Double(total) / Double(checkedInPlayers.count)
    }
    
    var estimatedDefenseStrength: Int {
        let playerDefense = checkedInPlayers.reduce(0) { $0 + $1.effectiveDefense }
        let wallDefense = wallLevel * 5
        return playerDefense + wallDefense
    }
}

