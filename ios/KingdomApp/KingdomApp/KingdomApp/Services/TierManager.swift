import Foundation

/// UNIVERSAL TIER MANAGER - Fetches ALL tier data from backend
/// Single source of truth for: Properties, Skills, Buildings, Crafting, Training, Reputation
/// NO MORE HARDCODED DESCRIPTIONS!
/// NOT ObservableObject - data is loaded once at startup and cached (no view re-renders)
class TierManager {
    static let shared = TierManager()
    
    var isLoaded: Bool = false
    var properties: PropertyTiersData?
    var equipment: EquipmentTiersData?
    var skillTierNames: [Int: String] = [:]
    var skillBenefits: [String: SkillBenefitsData] = [:]
    var buildings: [String: BuildingTypeData] = [:]
    var buildingTypes: [String: BuildingTypeInfo] = [:]  // Full building type info
    var reputation: ReputationTiersData?
    
    private let client = APIClient.shared
    
    private init() {
        // Provide fallback defaults so UI doesn't break before loading
        loadDefaults()
    }
    
    private func loadDefaults() {
        // Property defaults
        properties = PropertyTiersData(maxTier: 5, tiers: [
            1: PropertyTierInfo(name: "Land", description: "Cleared land", benefits: ["Instant travel", "50% off travel cost"]),
            2: PropertyTierInfo(name: "House", description: "Basic dwelling", benefits: ["All Land benefits", "Personal residence"]),
            3: PropertyTierInfo(name: "Workshop", description: "Crafting workshop", benefits: ["All House benefits", "Unlock crafting", "15% faster crafting"]),
            4: PropertyTierInfo(name: "Beautiful Property", description: "Luxurious property", benefits: ["All Workshop benefits", "Tax exemption"]),
            5: PropertyTierInfo(name: "Estate", description: "Grand estate", benefits: ["All Beautiful Property benefits", "Conquest protection"])
        ])
        
        // Skill tier names
        skillTierNames = [1: "Novice", 2: "Apprentice", 3: "Journeyman", 4: "Adept", 5: "Expert",
                         6: "Master", 7: "Grandmaster", 8: "Legendary", 9: "Mythic", 10: "Divine"]
        
        // Reputation defaults
        reputation = ReputationTiersData(maxTier: 6, tiers: [
            1: ReputationTierInfo(name: "Stranger", requirement: 0, icon: "person.fill", abilities: ["Basic game access"]),
            2: ReputationTierInfo(name: "Resident", requirement: 50, icon: "house.fill", abilities: ["Buy property"]),
            3: ReputationTierInfo(name: "Citizen", requirement: 150, icon: "person.2.fill", abilities: ["Vote on coups"]),
            4: ReputationTierInfo(name: "Notable", requirement: 300, icon: "star.fill", abilities: ["Propose coups"]),
            5: ReputationTierInfo(name: "Champion", requirement: 500, icon: "crown.fill", abilities: ["2x vote weight"]),
            6: ReputationTierInfo(name: "Legendary", requirement: 1000, icon: "sparkles", abilities: ["3x vote weight"])
        ])
        
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
        print("🎯 TierManager: Fetching ALL tier data from backend /tiers endpoint...")
        
        let request = client.request(endpoint: "/tiers", method: "GET")
        print("🌐 TierManager: Making API call to /tiers...")
        let response: AllTiersResponse = try await client.execute(request)
        print("✅ TierManager: Received response from /tiers")
        
        await MainActor.run {
            // Properties - convert string keys to int
            if let propertyData = response.properties {
                var tiers: [Int: PropertyTierInfo] = [:]
                for (key, value) in propertyData.tiers {
                    if let tier = Int(key) {
                        tiers[tier] = PropertyTierInfo(
                            name: value.name,
                            description: value.description,
                            benefits: value.benefits
                        )
                    }
                }
                self.properties = PropertyTiersData(maxTier: propertyData.max_tier, tiers: tiers)
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
            }
            
            // Buildings - parse full building type info
            if let buildingData = response.buildings {
                var buildingTypesDict: [String: BuildingTypeInfo] = [:]
                var legacyBuildings: [String: BuildingTypeData] = [:]
                
                for (buildingType, typeData) in buildingData.types {
                    var tiers: [Int: BuildingTierInfo] = [:]
                    for (key, value) in typeData.tiers {
                        if let tier = Int(key) {
                            tiers[tier] = BuildingTierInfo(
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
            print("   - Properties: \(self.properties?.tiers.count ?? 0) tiers")
            print("   - Equipment: \(self.equipment?.tiers.count ?? 0) tiers")
            print("   - Skills: \(self.skillTierNames.count) tiers")
            print("   - Buildings: \(self.buildingTypes.count) types")
            print("   - Reputation: \(self.reputation?.tiers.count ?? 0) tiers")
        }
    }
    
    // MARK: - Property Accessors
    
    func propertyTierName(_ tier: Int) -> String {
        properties?.tiers[tier]?.name ?? "Tier \(tier)"
    }
    
    func propertyTierDescription(_ tier: Int) -> String {
        properties?.tiers[tier]?.description ?? ""
    }
    
    func propertyTierBenefits(_ tier: Int) -> [String] {
        properties?.tiers[tier]?.benefits ?? []
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
        // Dynamic skill benefits based on skill type
        switch skill {
        case "attack":
            return ["+\(tier) Attack Power in coups", "Increases coup success chance", "Stacks with equipment bonuses"]
        case "defense":
            return ["+\(tier) Defense Power in coups", "Reduces coup damage taken", "Helps defend your kingdom"]
        case "leadership":
            return getLeadershipBenefits(tier: tier)
        case "building":
            return getBuildingBenefits(tier: tier)
        case "intelligence":
            return getIntelligenceBenefits(tier: tier)
        default:
            return []
        }
    }
    
    private func getLeadershipBenefits(tier: Int) -> [String] {
        var benefits: [String] = []
        let voteWeight = 1.0 + (Double(tier - 1) * 0.2)
        benefits.append("Vote weight: +\(String(format: "%.1f", voteWeight))")
        
        switch tier {
        case 1: benefits.append("Can vote on coups (with rep)")
        case 2: benefits.append("+50% rewards from ruler distributions")
        case 3: benefits.append("Can propose coups (300+ rep)")
        case 4: benefits.append("+100% rewards from ruler")
        case 5: benefits.append("-50% coup cost (500g instead of 1000g)")
        default: break
        }
        return benefits
    }
    
    private func getBuildingBenefits(tier: Int) -> [String] {
        var benefits: [String] = []
        benefits.append("-\(tier * 5)% property upgrade costs")
        
        switch tier {
        case 1: benefits.append("Work on contracts & properties")
        case 2: benefits.append("+10% gold from building contracts")
        case 3: benefits.append(contentsOf: ["+20% gold from contracts", "+1 daily Assist action"])
        case 4: benefits.append(contentsOf: ["+30% gold from contracts", "10% chance to refund action cooldown"])
        case 5: benefits.append(contentsOf: ["+40% gold from contracts", "25% chance to double contract progress"])
        default: break
        }
        return benefits
    }
    
    private func getIntelligenceBenefits(tier: Int) -> [String] {
        var benefits: [String] = []
        let bonus = tier * 2
        benefits.append("-\(bonus)% detection when sabotaging")
        benefits.append("+\(bonus)% catch chance when patrolling")
        if tier >= 5 {
            benefits.append("Vault Heist: Steal 10% of enemy vault (1000g cost)")
        }
        return benefits
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
    
    // MARK: - Constants
    
    func workshopRequiredForCrafting() -> Int {
        return 3  // Workshop is tier 3
    }
}

// MARK: - Response Models

struct AllTiersResponse: Codable {
    let properties: PropertyTiersResponseData?
    let equipment: EquipmentTiersResponseData?
    let skills: SkillTiersResponseData?
    let buildings: BuildingTiersResponseData?
    let reputation: ReputationTiersResponseData?
}

struct PropertyTiersResponseData: Codable {
    let max_tier: Int
    let tiers: [String: PropertyTierInfoResponse]  // String keys because JSON
}

struct PropertyTierInfoResponse: Codable {
    let name: String
    let description: String
    let benefits: [String]
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

struct PropertyTierInfo {
    let name: String
    let description: String
    let benefits: [String]
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
    let tiers: [Int: BuildingTierInfo]
}

struct BuildingTierInfo {
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
    let tiers: [Int: BuildingTierInfo]
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

struct SkillBenefitsData {
    let perTier: String
    let benefits: [String]
    let tierBonuses: [Int: [String]]
}

