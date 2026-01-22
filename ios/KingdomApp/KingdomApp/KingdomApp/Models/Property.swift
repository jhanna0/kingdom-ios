import Foundation

// MARK: - Property System
// ONE property per kingdom - progressive tier upgrade system
// Players buy land (T1) in a kingdom, then upgrade it to unlock more benefits
// Tier names, descriptions, and max tier are fetched from backend via TierManager
// See api/routers/tiers.py PROPERTY_TIERS for the source of truth

struct Property: Identifiable, Codable, Hashable {
    let id: String
    let kingdomId: String
    let kingdomName: String
    let ownerId: String
    let ownerName: String
    
    var tier: Int  // Each tier unlocks new features (max tier from backend)
    var location: String?  // "north", "south", "east", "west"
    let purchasedAt: Date
    var lastUpgraded: Date?
    
    // MARK: - Fortification (gear sink system)
    var fortificationUnlocked: Bool = false  // Unlocked at T2+
    var fortificationPercent: Int = 0  // 0-100%
    var fortificationBasePercent: Int = 0  // T5 has 50% base
    
    // MARK: - Computed Properties
    
    var name: String {
        tierName
    }
    
    var tierName: String {
        TierManager.shared.propertyTierName(tier)
    }
    
    /// Effective fortification (max of current and base)
    var effectiveFortification: Int {
        max(fortificationPercent, fortificationBasePercent)
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
    
    // MARK: - T2: Workshop Benefits
    // Workshop access is controlled by backend via /workshop/status
    // No hardcoded tier checks here!
    
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
    
    // MARK: - Note on Pricing
    // All costs are calculated by backend and returned in API responses
    // See PropertyAPI.getPropertyUpgradeStatus() for upgrade costs
    
    // MARK: - Mutations
    
    mutating func upgrade() -> Bool {
        guard tier < TierManager.shared.propertyMaxTier else { return false }
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

// MARK: - Tier Info (Fetched from Backend)
// NO MORE HARDCODED DESCRIPTIONS!
// Use TierManager.shared to get tier names, descriptions, and benefits

extension Property {
    var tierDescription: String {
        TierManager.shared.propertyTierDescription(tier)
    }
    
    var currentBenefits: [String] {
        TierManager.shared.propertyTierBenefits(tier)
    }
}


