import Foundation

// MARK: - Property System
// ONE property per kingdom - progressive 5-tier upgrade system
// Players buy land (T1) in a kingdom, then upgrade it to unlock more benefits
// T1: Land (travel benefits)
// T2: House (residence)
// T3: Workshop (crafting)
// T4: Beautiful Property (tax exemption)
// T5: Estate (conquest protection)

struct Property: Identifiable, Codable, Hashable {
    let id: String
    let kingdomId: String
    let kingdomName: String
    let ownerId: String
    let ownerName: String
    
    var tier: Int  // 1-5, each tier unlocks new features
    var location: String?  // "north", "south", "east", "west"
    let purchasedAt: Date
    var lastUpgraded: Date?
    
    // MARK: - Computed Properties
    
    var name: String {
        tierName
    }
    
    var tierName: String {
        switch tier {
        case 1: return "Land"
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"  // TBD
        default: return "Property"
        }
    }
    
    // MARK: - T1: Land Benefits
    
    var travelCostReduction: Double {
        // T1+: 50% off travel to this kingdom
        return tier >= 1 ? 0.50 : 0
    }
    
    var instantTravel: Bool {
        // T1+: Can instantly travel to this kingdom
        return tier >= 1
    }
    
    // MARK: - T2: House Benefits
    
    var hasHouse: Bool {
        return tier >= 2
    }
    
    // TODO: Define T2 house benefit
    
    // MARK: - T3: Workshop Benefits
    
    var canCraft: Bool {
        // T3+: Can craft weapons and armor
        return tier >= 3
    }
    
    var craftingSpeedBonus: Double {
        // T3+: Faster crafting
        return tier >= 3 ? 0.15 : 0  // 15% faster crafting
    }
    
    // MARK: - T4: Beautiful Property Benefits
    
    var taxExemption: Bool {
        // T4+: No more taxes in this kingdom
        return tier >= 4
    }
    
    // MARK: - T5: Estate Benefits (TBD)
    
    var conquestSurvivalChance: Double {
        // T5: 50% chance to survive conquest
        return tier >= 5 ? 0.50 : 0
    }
    
    // MARK: - Pricing
    
    static let baseLandPrice = 500
    
    var currentValue: Int {
        // Value increases with tier
        let tierMultiplier = Double(tier) * 1.5
        return Int(Double(Property.baseLandPrice) * tierMultiplier)
    }
    
    var upgradeCost: Int {
        guard tier < 5 else { return 0 }
        let nextTier = tier + 1
        // Each tier upgrade costs exponentially more
        // T1->T2: 500, T2->T3: 1000, T3->T4: 2000, T4->T5: 4000
        return Property.baseLandPrice * Int(pow(2.0, Double(nextTier - 2)))
    }
    
    static func purchasePrice(kingdomPopulation: Int) -> Int {
        // T1 land price scales with kingdom size
        let populationMultiplier = 1.0 + (Double(kingdomPopulation) / 50.0)
        return Int(Double(baseLandPrice) * populationMultiplier)
    }
    
    // MARK: - Mutations
    
    mutating func upgrade() -> Bool {
        guard tier < 5 else { return false }
        tier += 1
        lastUpgraded = Date()
        return true
    }
    
    mutating func damage(levels: Int = 2) {
        // Properties can be damaged during conquest (-2 levels)
        tier = max(1, tier - levels)
    }
    
    // MARK: - Factory
    
    static func purchase(
        kingdomId: String,
        kingdomName: String,
        ownerId: String,
        ownerName: String,
        location: String
    ) -> Property {
        return Property(
            id: UUID().uuidString,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            ownerId: ownerId,
            ownerName: ownerName,
            tier: 1,  // Always start at T1 (Land)
            location: location,
            purchasedAt: Date(),
            lastUpgraded: nil
        )
    }
}

// MARK: - Tier Descriptions

extension Property {
    var tierDescription: String {
        switch tier {
        case 1:
            return "Cleared land"
        case 2:
            return "Basic dwelling"
        case 3:
            return "Workshop for crafting"
        case 4:
            return "Luxurious estate"
        case 5:
            return "Fortified estate"
        default:
            return "Property"
        }
    }
    
    var currentBenefits: [String] {
        var benefits: [String] = []
        
        if tier >= 1 {
            benefits.append("Instant travel")
        }
        if tier >= 2 {
            benefits.append("Residence")
        }
        if tier >= 3 {
            benefits.append("Crafting")
        }
        if tier >= 4 {
            benefits.append("No taxes")
        }
        if tier >= 5 {
            benefits.append("Conquest protection")
        }
        
        return benefits
    }
}


