import Foundation

// MARK: - Property System
// Land ownership for players (houses, shops, personal mines)

enum PropertyType: String, Codable, CaseIterable {
    case house = "House"
    case shop = "Shop"
    case personalMine = "Personal Mine"
    
    var icon: String {
        switch self {
        case .house: return "🏠"
        case .shop: return "🏪"
        case .personalMine: return "⛏️"
        }
    }
    
    var basePrice: Int {
        switch self {
        case .house: return 500
        case .shop: return 1000
        case .personalMine: return 2000
        }
    }
}

struct Property: Identifiable, Codable, Hashable {
    let id: String
    let type: PropertyType
    let kingdomId: String
    let kingdomName: String
    let ownerId: String
    let ownerName: String
    
    var tier: Int  // 1-5, affects bonuses
    let purchasedAt: Date
    var lastUpgraded: Date?
    var lastIncomeCollection: Date
    
    // MARK: - Computed Properties
    
    var name: String {
        "\(type.rawValue) (Tier \(tier))"
    }
    
    var icon: String {
        type.icon
    }
    
    // MARK: - House Benefits (by tier)
    
    var travelCostReduction: Double {
        guard type == .house else { return 0 }
        switch tier {
        case 1: return 0.50  // 50% off travel
        case 2: return 0.50
        case 3: return 0.50
        case 4: return 0.50
        case 5: return 0.50
        default: return 0
        }
    }
    
    var instantTravel: Bool {
        // All house tiers give instant travel to that kingdom
        return type == .house && tier >= 1
    }
    
    var actionSpeedBonus: Double {
        guard type == .house else { return 0 }
        switch tier {
        case 3, 4, 5: return 0.10  // 10% faster actions
        default: return 0
        }
    }
    
    var taxReduction: Double {
        guard type == .house else { return 0 }
        switch tier {
        case 4, 5: return 0.50  // 50% tax reduction
        default: return 0
        }
    }
    
    var conquestSurvivalChance: Double {
        guard type == .house else { return 0 }
        switch tier {
        case 5: return 0.50  // 50% chance to survive conquest
        default: return 0
        }
    }
    
    // MARK: - Shop Benefits
    
    var dailyGoldIncome: Int {
        guard type == .shop else { return 0 }
        switch tier {
        case 1: return 10
        case 2: return 25
        case 3: return 50
        case 4: return 100
        case 5: return 200
        default: return 0
        }
    }
    
    // MARK: - Personal Mine Benefits
    
    var dailyIronYield: Int {
        guard type == .personalMine else { return 0 }
        switch tier {
        case 1: return 5
        case 2: return 10
        case 3: return 15
        case 4: return 20
        case 5: return 25
        default: return 0
        }
    }
    
    var dailySteelYield: Int {
        guard type == .personalMine else { return 0 }
        switch tier {
        case 1: return 0
        case 2: return 2
        case 3: return 5
        case 4: return 10
        case 5: return 15
        default: return 0
        }
    }
    
    var noTaxOnMining: Bool {
        // Personal mines have no tax!
        return type == .personalMine
    }
    
    // MARK: - Pricing
    
    var currentValue: Int {
        // Value increases with tier
        let baseValue = type.basePrice
        let tierMultiplier = Double(tier) * 1.5
        return Int(Double(baseValue) * tierMultiplier)
    }
    
    var upgradeCost: Int {
        guard tier < 5 else { return 0 }
        let nextTier = tier + 1
        let baseValue = type.basePrice
        // Each tier upgrade costs more
        return Int(Double(baseValue) * pow(2.0, Double(nextTier - 1)))
    }
    
    static func purchasePrice(type: PropertyType, tier: Int = 1, kingdomPopulation: Int) -> Int {
        // Price scales with kingdom size
        let basePrice = type.basePrice
        let populationMultiplier = 1.0 + (Double(kingdomPopulation) / 50.0)
        return Int(Double(basePrice) * populationMultiplier)
    }
    
    // MARK: - Pending Income
    
    var pendingGoldIncome: Int {
        guard type == .shop else { return 0 }
        let hoursSinceCollection = Date().timeIntervalSince(lastIncomeCollection) / 3600.0
        return Int(Double(dailyGoldIncome) * (hoursSinceCollection / 24.0))
    }
    
    var pendingIronIncome: Int {
        guard type == .personalMine else { return 0 }
        let hoursSinceCollection = Date().timeIntervalSince(lastIncomeCollection) / 3600.0
        return Int(Double(dailyIronYield) * (hoursSinceCollection / 24.0))
    }
    
    var pendingSteelIncome: Int {
        guard type == .personalMine else { return 0 }
        let hoursSinceCollection = Date().timeIntervalSince(lastIncomeCollection) / 3600.0
        return Int(Double(dailySteelYield) * (hoursSinceCollection / 24.0))
    }
    
    // MARK: - Mutations
    
    mutating func collectIncome() -> (gold: Int, iron: Int, steel: Int) {
        let gold = pendingGoldIncome
        let iron = pendingIronIncome
        let steel = pendingSteelIncome
        lastIncomeCollection = Date()
        return (gold, iron, steel)
    }
    
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
        type: PropertyType,
        kingdomId: String,
        kingdomName: String,
        ownerId: String,
        ownerName: String
    ) -> Property {
        return Property(
            id: UUID().uuidString,
            type: type,
            kingdomId: kingdomId,
            kingdomName: kingdomName,
            ownerId: ownerId,
            ownerName: ownerName,
            tier: 1,
            purchasedAt: Date(),
            lastUpgraded: nil,
            lastIncomeCollection: Date()
        )
    }
}

// MARK: - House Tier Descriptions

extension Property {
    var tierBenefitDescription: String {
        guard type == .house else { return "" }
        
        var benefits: [String] = []
        
        // Always have these
        benefits.append("50% travel cost reduction")
        benefits.append("Instant travel to \(kingdomName)")
        
        if tier >= 3 {
            benefits.append("10% faster actions")
        }
        if tier >= 4 {
            benefits.append("50% tax reduction")
        }
        if tier >= 5 {
            benefits.append("50% chance to survive conquest")
        }
        
        return benefits.joined(separator: "\n")
    }
}

// MARK: - Sample Properties

extension Property {
    static let samples: [Property] = [
        Property(
            id: UUID().uuidString,
            type: .house,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            ownerId: "player1",
            ownerName: "Sir Aldric",
            tier: 3,
            purchasedAt: Date().addingTimeInterval(-30 * 24 * 3600),
            lastUpgraded: Date().addingTimeInterval(-7 * 24 * 3600),
            lastIncomeCollection: Date().addingTimeInterval(-2 * 3600)
        ),
        Property(
            id: UUID().uuidString,
            type: .shop,
            kingdomId: "kingdom1",
            kingdomName: "Ashford",
            ownerId: "player1",
            ownerName: "Sir Aldric",
            tier: 2,
            purchasedAt: Date().addingTimeInterval(-20 * 24 * 3600),
            lastUpgraded: nil,
            lastIncomeCollection: Date().addingTimeInterval(-12 * 3600)
        ),
        Property(
            id: UUID().uuidString,
            type: .personalMine,
            kingdomId: "kingdom2",
            kingdomName: "Riverwatch",
            ownerId: "player2",
            ownerName: "Lady Beatrix",
            tier: 4,
            purchasedAt: Date().addingTimeInterval(-60 * 24 * 3600),
            lastUpgraded: Date().addingTimeInterval(-3 * 24 * 3600),
            lastIncomeCollection: Date().addingTimeInterval(-6 * 3600)
        )
    ]
}

