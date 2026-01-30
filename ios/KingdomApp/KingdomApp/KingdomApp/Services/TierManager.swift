import Foundation

/// UNIVERSAL TIER MANAGER - Fetches ALL tier data from backend
/// Single source of truth for: Properties, Skills, Buildings, Crafting, Training, Reputation
/// NO MORE HARDCODED DESCRIPTIONS!
/// NOT ObservableObject - data is loaded once at startup and cached (no view re-renders)
class TierManager {
    static let shared = TierManager()
    
    // MARK: - Cache Configuration
    private static let cacheKey = "TierManager.cachedTiersData"
    private static let cacheTimestampKey = "TierManager.cacheTimestamp"
    private static let cacheTTLSeconds: TimeInterval = 2 * 60 * 60  // 2 hours
    
    var isLoaded: Bool = false
    var resources: [String: ResourceInfo] = [:]  // Resource configurations from backend
    var properties: PropertyTiersData?
    var equipment: EquipmentTiersData?
    var skillTierNames: [Int: String] = [:]
    var skillBenefits: [String: SkillBenefitsData] = [:]
    var trainingActionsRequired: [Int: Int] = [:]  // current_level -> actions to train to next level
    var trainingGoldPerAction: [Int: Double] = [:]  // target_tier -> gold cost per action
    var buildings: [String: BuildingTypeData] = [:]
    var buildingTypes: [String: BuildingTypeInfo] = [:]  // Full building type info
    var reputation: ReputationTiersData?
    
    private let client = APIClient.shared
    
    private init() {
        // Provide fallback defaults so UI doesn't break before loading
        loadDefaults()
    }
    
    // MARK: - Cache Management
    
    /// Check if cached tier data is still valid
    private func isCacheValid() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: Self.cacheTimestampKey) as? Date else {
            return false
        }
        let age = Date().timeIntervalSince(timestamp)
        return age < Self.cacheTTLSeconds
    }
    
    /// Load tier data from disk cache
    private func loadFromCache() -> AllTiersResponse? {
        guard isCacheValid(),
              let data = UserDefaults.standard.data(forKey: Self.cacheKey) else {
            return nil
        }
        
        do {
            let response = try JSONDecoder().decode(AllTiersResponse.self, from: data)
            print("📦 TierManager: Loaded from cache (valid for \(Int(Self.cacheTTLSeconds - Date().timeIntervalSince(UserDefaults.standard.object(forKey: Self.cacheTimestampKey) as! Date)))s more)")
            return response
        } catch {
            print("⚠️ TierManager: Cache decode failed: \(error)")
            return nil
        }
    }
    
    /// Save tier data to disk cache
    private func saveToCache(_ response: AllTiersResponse) {
        do {
            let data = try JSONEncoder().encode(response)
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
            UserDefaults.standard.set(Date(), forKey: Self.cacheTimestampKey)
            print("💾 TierManager: Saved to cache")
        } catch {
            print("⚠️ TierManager: Cache save failed: \(error)")
        }
    }
    
    /// Clear the tier cache - forces refresh on next load
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
        UserDefaults.standard.removeObject(forKey: Self.cacheTimestampKey)
        isLoaded = false
        print("🗑️ TierManager: Cache cleared")
    }
    
    /// Force refresh from backend (ignores cache)
    func forceRefresh() async throws {
        clearCache()
        try await loadAllTiers()
    }
    
    private func loadDefaults() {
        // Resources loaded from backend ONLY - no defaults!
        resources = [:]
        
        // Property defaults (icons match backend PROPERTY_TIERS)
        properties = PropertyTiersData(maxTier: 5, tiers: [
            1: PropertyTierInfo(name: "Land", icon: "square.dashed", description: "Cleared land", benefits: ["Instant travel", "50% off travel cost"], baseGoldCost: nil, baseActionsRequired: nil, goldPerAction: nil, totalGoldCost: nil, perActionCosts: []),
            2: PropertyTierInfo(name: "House", icon: "house.fill", description: "Basic dwelling", benefits: ["All Land benefits", "Personal residence"], baseGoldCost: nil, baseActionsRequired: nil, goldPerAction: nil, totalGoldCost: nil, perActionCosts: []),
            3: PropertyTierInfo(name: "Workshop", icon: "hammer.fill", description: "Crafting workshop", benefits: ["All House benefits", "Unlock crafting", "15% faster crafting"], baseGoldCost: nil, baseActionsRequired: nil, goldPerAction: nil, totalGoldCost: nil, perActionCosts: []),
            4: PropertyTierInfo(name: "Beautiful Property", icon: "building.columns.fill", description: "Luxurious property", benefits: ["All Workshop benefits", "Tax exemption"], baseGoldCost: nil, baseActionsRequired: nil, goldPerAction: nil, totalGoldCost: nil, perActionCosts: []),
            5: PropertyTierInfo(name: "Estate", icon: "shield.fill", description: "Grand estate", benefits: ["All Beautiful Property benefits", "Conquest protection"], baseGoldCost: nil, baseActionsRequired: nil, goldPerAction: nil, totalGoldCost: nil, perActionCosts: [])
        ])
        
        // Skill tier names
        skillTierNames = [1: "Novice", 2: "Apprentice", 3: "Journeyman", 4: "Adept", 5: "Expert",
                         6: "Master", 7: "Grandmaster", 8: "Legendary", 9: "Mythic", 10: "Divine"]
        
        // Reputation loaded from backend ONLY - no defaults!
        reputation = nil
        
        // Building type defaults
        buildingTypes = [
            "wall": BuildingTypeInfo(displayName: "Walls", icon: "building.2.fill", category: "defense", description: "Defensive walls", maxTier: 5, benefitFormula: "+{level*2} defenders", tiers: [:]),
            "vault": BuildingTypeInfo(displayName: "Vault", icon: "lock.shield.fill", category: "defense", description: "Protects treasury", maxTier: 5, benefitFormula: "{level*20}% protected", tiers: [:]),
            "mine": BuildingTypeInfo(displayName: "Mine", icon: "hammer.fill", category: "economy", description: "Produces resources", maxTier: 5, benefitFormula: "Unlocks resources", tiers: [:]),
            "market": BuildingTypeInfo(displayName: "Market", icon: "cart.fill", category: "economy", description: "Passive income", maxTier: 5, benefitFormula: "+gold/day", tiers: [:]),
            "farm": BuildingTypeInfo(displayName: "Farm", icon: "leaf.fill", category: "economy", description: "Faster contracts", maxTier: 5, benefitFormula: "Contracts faster", tiers: [:]),
            "education": BuildingTypeInfo(displayName: "Education Hall", icon: "graduationcap.fill", category: "civic", description: "Faster training", maxTier: 5, benefitFormula: "Train faster", tiers: [:])
        ]
    }
    
    // MARK: - Load All Tiers
    
    func loadAllTiers() async throws {
        // Check cache first
        if let cachedResponse = loadFromCache() {
            await processResponse(cachedResponse)
            return
        }
        
        // Cache miss or expired - fetch from backend
        print("🎯 TierManager: Fetching ALL tier data from backend /tiers endpoint...")
        
        let request = client.request(endpoint: "/tiers", method: "GET")
        print("🌐 TierManager: Making API call to /tiers...")
        let response: AllTiersResponse = try await client.execute(request)
        print("✅ TierManager: Received response from /tiers")
        
        // Save to cache for next time
        saveToCache(response)
        
        await processResponse(response)
    }
    
    /// Process the tier response (from cache or network)
    private func processResponse(_ response: AllTiersResponse) async {
        
        await MainActor.run {
            // Resources - load from backend
            if let resourceData = response.resources {
                var resourcesDict: [String: ResourceInfo] = [:]
                for (key, value) in resourceData.types {
                    resourcesDict[key] = ResourceInfo(
                        displayName: value.display_name,
                        icon: value.icon,
                        colorName: value.color,
                        description: value.description,
                        category: value.category,
                        displayOrder: value.display_order
                    )
                }
                self.resources = resourcesDict
                print("   - Loaded \(resourcesDict.count) resource types from backend")
            }
            
            // Properties - convert string keys to int
            if let propertyData = response.properties {
                var tiers: [Int: PropertyTierInfo] = [:]
                for (key, value) in propertyData.tiers {
                    if let tier = Int(key) {
                        // Convert per-action costs
                        let perActionCosts = (value.per_action_costs ?? []).map { cost in
                            PropertyPerActionCost(resource: cost.resource, amount: cost.amount)
                        }
                        
                        tiers[tier] = PropertyTierInfo(
                            name: value.name,
                            icon: value.icon ?? "star.fill",
                            description: value.description,
                            benefits: value.benefits,
                            baseGoldCost: value.base_gold_cost,
                            baseActionsRequired: value.base_actions_required,
                            goldPerAction: value.gold_per_action,
                            totalGoldCost: value.total_gold_cost,
                            perActionCosts: perActionCosts
                        )
                    }
                }
                self.properties = PropertyTiersData(maxTier: propertyData.max_tier, tiers: tiers)
                print("   - Loaded \(tiers.count) property tiers with per-action costs")
            }
            
            // Equipment - convert string keys to int
            if let equipmentData = response.equipment {
                var tiers: [Int: EquipmentTierInfo] = [:]
                for (key, value) in equipmentData.tiers {
                    if let tier = Int(key) {
                        tiers[tier] = EquipmentTierInfo(
                            name: value.name,
                            description: value.description,
                            statBonus: value.stat_bonus,
                            goldCost: value.gold_cost,
                            ironCost: value.iron_cost,
                            steelCost: value.steel_cost,
                            actionsRequired: value.actions_required
                        )
                    }
                }
                self.equipment = EquipmentTiersData(maxTier: equipmentData.max_tier, tiers: tiers)
            }
            
            // Skills / Training - convert string keys to int
            if let skillData = response.skills {
                var names: [Int: String] = [:]
                for (key, value) in skillData.tier_names {
                    if let tier = Int(key) {
                        names[tier] = value
                    }
                }
                self.skillTierNames = names
                
                // Load skill benefits from backend (single source of truth!)
                if let benefits = skillData.skill_benefits {
                    self.skillBenefits = benefits
                    print("   - Loaded \(benefits.count) skill benefit definitions from backend")
                }
            }
            
            // Training action requirements from backend
            if let trainingData = response.training, let actionsRequired = trainingData.actions_required {
                var actionsDict: [Int: Int] = [:]
                for (key, value) in actionsRequired {
                    if let level = Int(key) {
                        actionsDict[level] = value
                    }
                }
                self.trainingActionsRequired = actionsDict
                print("   - Loaded training actions: \(actionsDict)")
            }
            
            // Training gold per action from backend
            if let trainingData = response.training {
                if let goldPerAction = trainingData.gold_per_action {
                    var goldDict: [Int: Double] = [:]
                    for (key, value) in goldPerAction {
                        if let tier = Int(key) {
                            goldDict[tier] = value
                        }
                    }
                    self.trainingGoldPerAction = goldDict
                    print("   - Loaded training gold per action: \(goldDict)")
                } else {
                    print("   ⚠️ WARNING: gold_per_action is nil in response!")
                }
            } else {
                print("   ⚠️ WARNING: training data is nil in response!")
            }
            
            // Buildings - parse full building type info
            if let buildingData = response.buildings {
                var buildingTypesDict: [String: BuildingTypeInfo] = [:]
                var legacyBuildings: [String: BuildingTypeData] = [:]
                
                for (buildingType, typeData) in buildingData.types {
                    var tiers: [Int: TMBuildingTierInfo] = [:]
                    for (key, value) in typeData.tiers {
                        if let tier = Int(key) {
                            tiers[tier] = TMBuildingTierInfo(
                                name: value.name,
                                description: value.description,
                                benefit: value.benefit ?? ""
                            )
                        }
                    }
                    
                    // Full building type info
                    buildingTypesDict[buildingType] = BuildingTypeInfo(
                        displayName: typeData.display_name,
                        icon: typeData.icon,
                        category: typeData.category,
                        description: typeData.description,
                        maxTier: typeData.max_tier,
                        benefitFormula: typeData.benefit_formula,
                        tiers: tiers
                    )
                    
                    // Legacy format for backwards compatibility
                    legacyBuildings[buildingType] = BuildingTypeData(tiers: tiers)
                }
                
                self.buildingTypes = buildingTypesDict
                self.buildings = legacyBuildings
            }
            
            // Reputation - convert string keys to int
            if let reputationData = response.reputation {
                var tiers: [Int: ReputationTierInfo] = [:]
                for (key, value) in reputationData.tiers {
                    if let tier = Int(key) {
                        tiers[tier] = ReputationTierInfo(
                            name: value.name,
                            requirement: value.requirement,
                            icon: value.icon,
                            abilities: value.abilities
                        )
                    }
                }
                self.reputation = ReputationTiersData(maxTier: reputationData.max_tier, tiers: tiers)
            }
            
            self.isLoaded = true
            print("✅ TierManager: Loaded all tier data successfully")
            print("   - Resources: \(self.resources.count) types")
            print("   - Properties: \(self.properties?.tiers.count ?? 0) tiers")
            print("   - Equipment: \(self.equipment?.tiers.count ?? 0) tiers")
            print("   - Skills: \(self.skillTierNames.count) tiers")
            print("   - Buildings: \(self.buildingTypes.count) types")
            print("   - Reputation: \(self.reputation?.tiers.count ?? 0) tiers")
        }
    }
    
    // MARK: - Property Accessors
    
    var propertyMaxTier: Int {
        properties?.maxTier ?? 5
    }
    
    func propertyTierName(_ tier: Int) -> String {
        properties?.tiers[tier]?.name ?? "Tier \(tier)"
    }
    
    func propertyTierIcon(_ tier: Int) -> String {
        properties?.tiers[tier]?.icon ?? "star.fill"
    }
    
    func propertyTierDescription(_ tier: Int) -> String {
        properties?.tiers[tier]?.description ?? ""
    }
    
    func propertyTierBenefits(_ tier: Int) -> [String] {
        properties?.tiers[tier]?.benefits ?? []
    }
    
    func propertyTierCost(_ tier: Int) -> Int? {
        properties?.tiers[tier]?.baseGoldCost
    }
    
    func propertyTierActions(_ tier: Int) -> Int? {
        properties?.tiers[tier]?.baseActionsRequired
    }
    
    func propertyGoldPerAction(_ tier: Int) -> Double? {
        properties?.tiers[tier]?.goldPerAction
    }
    
    func propertyTotalGoldCost(_ tier: Int) -> Int? {
        properties?.tiers[tier]?.totalGoldCost
    }
    
    func propertyPerActionCosts(_ tier: Int) -> [PropertyPerActionCost] {
        properties?.tiers[tier]?.perActionCosts ?? []
    }
    
    // MARK: - Equipment Accessors
    
    func equipmentTierName(_ tier: Int) -> String {
        equipment?.tiers[tier]?.name ?? "Tier \(tier)"
    }
    
    func equipmentTierStatBonus(_ tier: Int) -> Int {
        equipment?.tiers[tier]?.statBonus ?? tier
    }
    
    func equipmentTierCost(_ tier: Int) -> (gold: Int, iron: Int, steel: Int, actions: Int) {
        guard let info = equipment?.tiers[tier] else {
            return (100 * tier, 10 * tier, 0, tier)
        }
        return (info.goldCost, info.ironCost, info.steelCost, info.actionsRequired)
    }
    
    // MARK: - Skill Accessors
    
    func skillTierName(_ tier: Int) -> String {
        skillTierNames[tier] ?? "Tier \(tier)"
    }
    
    func skillBenefitsFor(_ skill: String, tier: Int) -> [String] {
        // Use backend data as single source of truth - ONLY tier_bonuses matter!
        guard let skillData = skillBenefits[skill] else {
            return []
        }
        
        // Return ONLY the tier-specific bonuses - nothing else!
        return skillData.tierBonuses[tier] ?? []
    }
    
    /// Get actions required to train from current level to next level
    /// currentLevel 0 = training to tier 1, currentLevel 4 = training to tier 5
    func trainingActionsFor(currentLevel: Int) -> Int {
        return trainingActionsRequired[currentLevel] ?? 100  // Default fallback
    }
    
    /// Get gold cost per action to train to a target tier
    /// targetTier 1 = training from 0 to 1, targetTier 5 = training from 4 to 5
    func trainingGoldFor(targetTier: Int) -> Double {
        return trainingGoldPerAction[targetTier] ?? 100.0  // Default fallback
    }
    
    // MARK: - Reputation Accessors
    
    func reputationTierName(_ tier: Int) -> String {
        reputation?.tiers[tier]?.name ?? "Tier \(tier)"
    }
    
    func reputationTierRequirement(_ tier: Int) -> Int {
        reputation?.tiers[tier]?.requirement ?? (tier * 100)
    }
    
    func reputationTierIcon(_ tier: Int) -> String {
        reputation?.tiers[tier]?.icon ?? "person.fill"
    }
    
    func reputationTierAbilities(_ tier: Int) -> [String] {
        reputation?.tiers[tier]?.abilities ?? []
    }
    
    func reputationTierFor(reputation: Int) -> Int {
        // Find the highest tier that the reputation qualifies for
        for tier in stride(from: 6, through: 1, by: -1) {
            if reputation >= reputationTierRequirement(tier) {
                return tier
            }
        }
        return 1
    }
    
    // MARK: - Building Accessors
    
    /// Get all available building types (for dynamic UI)
    func getAllBuildingTypes() -> [String] {
        return Array(buildingTypes.keys).sorted()
    }
    
    /// Get building type info (display name, icon, category)
    func buildingTypeInfo(_ buildingType: String) -> BuildingTypeInfo? {
        return buildingTypes[buildingType]
    }
    
    /// Get building types by category (sorted for stable ordering)
    func buildingTypesByCategory(_ category: String) -> [String] {
        return buildingTypes
            .filter { $0.value.category == category }
            .map { $0.key }
            .sorted()  // Stable alphabetical order
    }
    
    func buildingDisplayName(_ buildingType: String) -> String {
        buildingTypes[buildingType]?.displayName ?? buildingType.capitalized
    }
    
    func buildingIcon(_ buildingType: String) -> String {
        buildingTypes[buildingType]?.icon ?? "building.fill"
    }
    
    func buildingTierName(_ buildingType: String, tier: Int) -> String {
        buildingTypes[buildingType]?.tiers[tier]?.name ?? "Level \(tier)"
    }
    
    func buildingTierBenefit(_ buildingType: String, tier: Int) -> String {
        buildingTypes[buildingType]?.tiers[tier]?.benefit ?? ""
    }
    
    func buildingTierDescription(_ buildingType: String, tier: Int) -> String {
        buildingTypes[buildingType]?.tiers[tier]?.description ?? ""
    }
    
    // MARK: - Resource Accessors
    
    /// Get all resource types sorted by display order
    func getAllResources() -> [(key: String, info: ResourceInfo)] {
        return resources.sorted { $0.value.displayOrder < $1.value.displayOrder }
            .map { (key: $0.key, info: $0.value) }
    }
    
    func resourceInfo(_ resourceId: String) -> ResourceInfo? {
        return resources[resourceId]
    }
    
    // MARK: - Constants
    
    func workshopRequiredForCrafting() -> Int {
        return 3  // Workshop is tier 3
    }
}

// MARK: - Response Models

struct AllTiersResponse: Codable {
    let resources: ResourcesResponseData?
    let properties: PropertyTiersResponseData?
    let equipment: EquipmentTiersResponseData?
    let skills: SkillTiersResponseData?
    let training: TrainingTiersResponseData?
    let buildings: BuildingTiersResponseData?
    let reputation: ReputationTiersResponseData?
}

struct ResourcesResponseData: Codable {
    let types: [String: ResourceInfoResponse]
}

struct ResourceInfoResponse: Codable {
    let display_name: String
    let icon: String
    let color: String  // Color name (theme color or standard SwiftUI color)
    let description: String
    let category: String
    let display_order: Int
}

struct TrainingTiersResponseData: Codable {
    let max_tier: Int
    let tier_names: [String: String]?
    let actions_required: [String: Int]?
    let gold_per_action: [String: Double]?
}

struct PropertyTiersResponseData: Codable {
    let max_tier: Int
    let tiers: [String: PropertyTierInfoResponse]  // String keys because JSON
}

/// Per-action resource cost (e.g., wood, iron per action)
struct PropertyPerActionCostResponse: Codable {
    let resource: String
    let amount: Int
}

struct PropertyTierInfoResponse: Codable {
    let name: String
    let icon: String?
    let description: String
    let benefits: [String]
    let base_gold_cost: Int?
    let base_actions_required: Int?
    // New fields from backend
    let gold_per_action: Double?
    let total_gold_cost: Int?
    let per_action_costs: [PropertyPerActionCostResponse]?
}

struct EquipmentTiersResponseData: Codable {
    let max_tier: Int
    let tiers: [String: EquipmentTierInfoResponse]  // String keys because JSON
}

struct EquipmentTierInfoResponse: Codable {
    let name: String
    let description: String
    let stat_bonus: Int
    let gold_cost: Int
    let iron_cost: Int
    let steel_cost: Int
    let actions_required: Int
}

struct SkillTiersResponseData: Codable {
    let max_tier: Int
    let tier_names: [String: String]  // String keys because JSON
    let skill_benefits: [String: SkillBenefitsData]?
}

struct BuildingTiersResponseData: Codable {
    let max_tier: Int
    let types: [String: BuildingTypeResponseData]  // Full building type info
}

struct BuildingTypeResponseData: Codable {
    let display_name: String
    let icon: String
    let category: String
    let description: String
    let max_tier: Int
    let benefit_formula: String
    let tiers: [String: BuildingTierInfoResponse]
}

struct ReputationTiersResponseData: Codable {
    let max_tier: Int
    let tiers: [String: ReputationTierInfoResponse]  // String keys because JSON
}

struct ReputationTierInfoResponse: Codable {
    let name: String
    let requirement: Int
    let icon: String
    let abilities: [String]
}

struct BuildingTierInfoResponse: Codable {
    let name: String
    let description: String
    let benefit: String?
}


// MARK: - Cached Data Models

struct PropertyTiersData {
    let maxTier: Int
    let tiers: [Int: PropertyTierInfo]
}

/// Per-action resource cost (wood, iron, etc.)
struct PropertyPerActionCost {
    let resource: String
    let amount: Int
}

struct PropertyTierInfo {
    let name: String
    let icon: String
    let description: String
    let benefits: [String]
    let baseGoldCost: Int?
    let baseActionsRequired: Int?
    // New fields for proper cost display
    let goldPerAction: Double?
    let totalGoldCost: Int?
    let perActionCosts: [PropertyPerActionCost]
}

struct EquipmentTiersData {
    let maxTier: Int
    let tiers: [Int: EquipmentTierInfo]
}

struct EquipmentTierInfo {
    let name: String
    let description: String
    let statBonus: Int
    let goldCost: Int
    let ironCost: Int
    let steelCost: Int
    let actionsRequired: Int
}

struct BuildingTypeData {
    let tiers: [Int: TMBuildingTierInfo]
}

// TierManager's internal building tier info (prefixed to avoid conflict with Kingdom.BuildingTierInfo)
struct TMBuildingTierInfo {
    let name: String
    let description: String
    let benefit: String
    
    init(name: String, description: String, benefit: String = "") {
        self.name = name
        self.description = description
        self.benefit = benefit
    }
}

/// Full building type info from backend
struct BuildingTypeInfo {
    let displayName: String
    let icon: String
    let category: String  // "economy", "defense", "civic"
    let description: String
    let maxTier: Int
    let benefitFormula: String
    let tiers: [Int: TMBuildingTierInfo]
}

struct ReputationTiersData {
    let maxTier: Int
    let tiers: [Int: ReputationTierInfo]
}

struct ReputationTierInfo {
    let name: String
    let requirement: Int
    let icon: String
    let abilities: [String]
}

struct SkillBenefitsData: Codable {
    let tierBonuses: [Int: [String]]
    
    enum CodingKeys: String, CodingKey {
        case tierBonuses = "tier_bonuses"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode tier_bonuses with string keys and convert to Int keys
        let tierBonusesStringKeys = try container.decodeIfPresent([String: [String]].self, forKey: .tierBonuses) ?? [:]
        var intKeyDict: [Int: [String]] = [:]
        for (key, value) in tierBonusesStringKeys {
            if let intKey = Int(key) {
                intKeyDict[intKey] = value
            }
        }
        tierBonuses = intKeyDict
    }
}

/// Resource info from backend - NO HARDCODING!
struct ResourceInfo {
    let displayName: String
    let icon: String
    let colorName: String  // Theme color name (e.g., "goldLight", "gray", "blue")
    let description: String
    let category: String
    let displayOrder: Int
}