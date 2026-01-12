import Foundation
import CoreLocation

// Building upgrade cost information - constructed manually from API data
struct BuildingUpgradeCost: Hashable {
    let actionsRequired: Int
    let constructionCost: Int
    let canAfford: Bool
}

/// Info for a single building tier - FULLY DYNAMIC from backend
struct BuildingTierInfo: Hashable {
    let tier: Int
    let name: String  // e.g. "Wooden Palisade", "Stone Wall"
    let benefit: String  // e.g. "+2 defenders", "20% protected"
    let tierDescription: String  // e.g. "Basic wooden wall"
}

// Click action for a building - DYNAMIC from backend
struct BuildingClickAction: Hashable, Identifiable {
    let type: String  // e.g. "gathering", "market", "townhall"
    let resource: String?  // For gathering: "wood", "iron"
    
    // Identifiable for SwiftUI sheet binding
    var id: String { "\(type)_\(resource ?? "")" }
}

// DYNAMIC Building metadata from backend - includes upgrade costs and tier info
// Constructed manually from API response - not decoded directly
struct BuildingMetadata: Hashable {
    let type: String  // e.g. "wall", "vault", "mine"
    let displayName: String  // e.g. "Walls", "Vault"
    let icon: String  // SF Symbol name
    let colorHex: String  // Hex color code
    let category: String  // "economy", "defense", "civic"
    let description: String
    let level: Int
    let maxLevel: Int
    let upgradeCost: BuildingUpgradeCost?  // Cost to upgrade (nil if at max)
    
    // Click action - what happens when building is tapped (nil = not clickable)
    let clickAction: BuildingClickAction?
    
    // Current tier info
    let tierName: String  // Name of current tier (e.g. "Stone Wall")
    let tierBenefit: String  // Benefit of current tier (e.g. "+4 defenders")
    
    // All tiers info - for detail view to show all levels
    let allTiers: [BuildingTierInfo]
    
    // Computed: is this building clickable?
    var isClickable: Bool {
        clickAction != nil && level > 0
    }
}

// Income record for tracking city revenue
struct IncomeRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let amount: Int
    let timestamp: Date
    let hourlyRate: Int
    let dailyRate: Int
    
    init(amount: Int, hourlyRate: Int, dailyRate: Int) {
        self.id = UUID()
        self.amount = amount
        self.timestamp = Date()
        self.hourlyRate = hourlyRate
        self.dailyRate = dailyRate
    }
}

// Alliance info when kingdoms are allied
struct KingdomAllianceInfo: Hashable {
    let id: Int
    let daysRemaining: Int
    let expiresAt: Date?
}


struct Kingdom: Identifiable, Equatable, Hashable {
    let id: String  // OSM ID - matches city_boundary_osm_id in backend
    let name: String
    var rulerName: String
    var rulerId: Int?  // Player ID of ruler (nil if unclaimed) - PostgreSQL auto-generated
    var territory: Territory  // var so we can update boundary after lazy load
    let color: KingdomColor
    var canClaim: Bool  // Backend determines if current user can claim
    var canDeclareWar: Bool  // Backend determines if current user can declare war
    var canFormAlliance: Bool  // Backend determines if current user can form alliance
    
    // Relationship to player (from backend)
    var isAllied: Bool  // True if allied with any of player's kingdoms
    var isEnemy: Bool  // True if at war with any of player's kingdoms
    var allianceInfo: KingdomAllianceInfo?  // Details about alliance if isAllied is true
    
    // Coup eligibility (from backend)
    var canStageCoup: Bool  // True if current user can initiate a coup
    var coupIneligibilityReason: String?  // Why user can't stage coup (e.g., "Need T3 leadership")
    
    // War state - Backend is source of truth!
    var isAtWar: Bool  // True if there's an active battle (coup or invasion)
    var activeCoup: ActiveCoupData?  // Active battle in this kingdom (if any)

    // Loading state
    var isCurrentCity: Bool  // True if user is currently inside this city (from API)
    var hasBoundaryCached: Bool  // True if full boundary polygon is loaded
    
    // Game stats
    var treasuryGold: Int
    var checkedInPlayers: Int
    var activeCitizens: Int  // Active citizens (hometown residents)
    
    // DYNAMIC BUILDINGS - use these dictionaries for all building data!
    // Populated from backend buildings array - NO HARDCODING required
    var buildingLevels: [String: Int] = [:]  // building_type -> level
    var buildingUpgradeCosts: [String: BuildingUpgradeCost?] = [:]  // building_type -> cost (nil if max level)
    var buildingMetadata: [String: BuildingMetadata] = [:]  // building_type -> full metadata from backend
    
    // Convenience computed property for Town Hall level (frequently checked)
    var townhallLevel: Int {
        buildingLevels["townhall"] ?? 0
    }
    
    // Helper to get building level by type
    func buildingLevel(_ type: String) -> Int {
        buildingLevels[type] ?? 0
    }
    
    // Helper to get upgrade cost by type
    func upgradeCost(_ type: String) -> BuildingUpgradeCost? {
        buildingUpgradeCosts[type] ?? nil
    }
    
    // Helper to get building metadata by type
    func getBuildingMetadata(_ type: String) -> BuildingMetadata? {
        buildingMetadata[type]
    }
    
    // Get all building types - FULLY DYNAMIC from backend metadata
    func allBuildingTypes() -> [String] {
        return Array(buildingMetadata.keys).sorted()
    }
    
    // Get sorted buildings for display (built buildings first, then alphabetical)
    func sortedBuildings() -> [BuildingMetadata] {
        return buildingMetadata.values.sorted { a, b in
            if a.level > 0 && b.level <= 0 { return true }
            if a.level <= 0 && b.level > 0 { return false }
            return a.displayName < b.displayName
        }
    }
    
    // Tax system (0-100%)
    var taxRate: Int  // Percentage of mined resources going to treasury
    var travelFee: Int  // Gold charged when entering kingdom (rulers exempt)
    
    // Active contract
    var activeContract: Contract?
    
    // Daily quests (ruler-issued objectives)
    var activeQuests: [DailyQuest]
    
    // Alliances
    var allies: Set<String>  // Kingdom IDs of allied kingdoms
    var enemies: Set<String>  // Kingdom IDs of kingdoms at war
    
    // Income tracking
    var lastIncomeCollection: Date
    var totalIncomeCollected: Int  // Lifetime income collected
    var incomeHistory: [IncomeRecord]  // Recent income collections
    
    static func == (lhs: Kingdom, rhs: Kingdom) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init?(name: String, rulerName: String = "Unclaimed", rulerId: Int? = nil, territory: Territory, color: KingdomColor, canClaim: Bool = false, canDeclareWar: Bool = false, canFormAlliance: Bool = false, isAllied: Bool = false, isEnemy: Bool = false, canStageCoup: Bool = false, coupIneligibilityReason: String? = nil, isAtWar: Bool = false) {
        // Use OSM ID as Kingdom ID to match backend
        guard let osmId = territory.osmId else {
            print("⚠️ Skipping kingdom '\(name)' - no OSM ID")
            return nil
        }
        self.id = osmId
        self.name = name
        self.rulerName = rulerName
        self.rulerId = rulerId
        self.territory = territory
        self.color = color
        self.canClaim = canClaim
        self.canDeclareWar = canDeclareWar
        self.canFormAlliance = canFormAlliance
        self.isAllied = isAllied
        self.isEnemy = isEnemy
        self.canStageCoup = canStageCoup
        self.coupIneligibilityReason = coupIneligibilityReason
        self.isAtWar = isAtWar  // Backend is source of truth!
        self.isCurrentCity = false  // Set by CityAPI after fetch
        self.hasBoundaryCached = true  // Assume true, CityAPI sets false if needed
        
        // BACKEND ONLY - These will be set from API data immediately after init
        // Setting defaults here to satisfy Swift's requirement for initialization
        self.treasuryGold = 0
        self.checkedInPlayers = 0
        self.activeCitizens = 0
        self.buildingLevels = [:]  // Will be populated from API
        self.buildingUpgradeCosts = [:]  // Will be populated from API
        self.taxRate = 10
        self.travelFee = 10
        
        // Battle data (populated from API)
        self.activeCoup = nil
        
        // Local-only defaults (not game-critical)
        self.lastIncomeCollection = Date().addingTimeInterval(-86400)
        self.totalIncomeCollected = 0
        self.incomeHistory = []
        self.activeContract = nil
        self.activeQuests = []
        self.allies = []
        self.enemies = []
        
        // Note: buildingUpgradeCosts dict already initialized above
    }
    
    /// Update boundary after lazy loading from API
    mutating func updateBoundary(_ newBoundary: [CLLocationCoordinate2D], radiusMeters: Double) {
        self.territory = Territory(
            center: territory.center,
            radiusMeters: radiusMeters,
            boundary: newBoundary,
            osmId: territory.osmId
        )
        self.hasBoundaryCached = true
    }
    
    /// Check if a point is inside this kingdom's territory
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Try polygon check first
        let polygonResult = isPointInPolygon(coordinate, polygon: territory.boundary)
        
        // If polygon check fails but we're close to center, use radius fallback
        // This helps with boundary accuracy issues from OSM
        if !polygonResult {
            let centerLoc = CLLocation(latitude: territory.center.latitude, longitude: territory.center.longitude)
            let pointLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = centerLoc.distance(from: pointLoc)
            
            if distance <= territory.radiusMeters {
                return true
            }
        }
        
        return polygonResult
    }
    
    /// Check if this kingdom is unclaimed
    var isUnclaimed: Bool {
        return rulerId == nil
    }
    
    /// Set a new ruler
    mutating func setRuler(playerId: Int, playerName: String) {
        self.rulerId = playerId
        self.rulerName = playerName
    }
    
    /// Remove the ruler
    mutating func removeRuler() {
        self.rulerId = nil
        self.rulerName = "Unclaimed"
    }
    
    // MARK: - Note on Economy & Income
    // All economic calculations (income, material costs, etc.) are done by backend
    // Backend provides this data in kingdom state responses
    
    /// Check if income is available to collect
    // NOTE: Income collection removed - backend handles automatically
    
    // MARK: - Tax System
    
    /// Calculate tax amount for mined resources
    func calculateTax(on amount: Int) -> Int {
        return Int(Double(amount) * Double(taxRate) / 100.0)
    }
    
    /// Set tax rate (ruler only)
    mutating func setTaxRate(_ rate: Int) {
        taxRate = max(0, min(100, rate))  // Clamp 0-100
    }
    
    // MARK: - Quest Management
    
    /// Add a new quest
    mutating func addQuest(_ quest: DailyQuest) {
        activeQuests.append(quest)
    }
    
    /// Remove completed or expired quests
    mutating func cleanupQuests() {
        activeQuests.removeAll { $0.isComplete || $0.isExpired }
    }
    
    // MARK: - Alliance System
    
    /// Form an alliance with another kingdom
    mutating func formAlliance(with kingdomId: String) {
        allies.insert(kingdomId)
        enemies.remove(kingdomId)
    }
    
    /// Break an alliance
    mutating func breakAlliance(with kingdomId: String) {
        allies.remove(kingdomId)
    }
    
    /// Declare war
    mutating func declareWar(on kingdomId: String) {
        enemies.insert(kingdomId)
        allies.remove(kingdomId)
    }
    
    /// Make peace
    mutating func makePeace(with kingdomId: String) {
        enemies.remove(kingdomId)
    }
    
    /// Get income ready to collect (without actually collecting)
    // NOTE: Pending income calculation removed - backend handles automatically
    
    // MARK: - Reward Distribution System
    
    // Ray casting algorithm for point-in-polygon test
    private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            let intersect = ((yi > point.latitude) != (yj > point.latitude))
                && (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)
            
            if intersect {
                inside.toggle()
            }
            j = i
        }
        
        return inside
    }
}

struct Territory: Hashable {
    let center: CLLocationCoordinate2D
    let radiusMeters: Double
    let boundary: [CLLocationCoordinate2D]
    let osmId: String?  // OpenStreetMap relation ID
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(center.latitude)
        hasher.combine(center.longitude)
        hasher.combine(radiusMeters)
    }
    
    static func == (lhs: Territory, rhs: Territory) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.radiusMeters == rhs.radiusMeters
    }
    
    // Helper to create circular territory
    static func circular(center: CLLocationCoordinate2D, radiusMeters: Double, points: Int = 30, osmId: String? = nil) -> Territory {
        let boundary = (0..<points).map { i -> CLLocationCoordinate2D in
            let angle = Double(i) * 2 * .pi / Double(points)
            
            // Convert radius to degrees (approximate)
            let latDelta = (radiusMeters / 111_000) * cos(angle)
            let lonDelta = (radiusMeters / (111_000 * cos(center.latitude * .pi / 180))) * sin(angle)
            
            return CLLocationCoordinate2D(
                latitude: center.latitude + latDelta,
                longitude: center.longitude + lonDelta
            )
        }
        
        return Territory(center: center, radiusMeters: radiusMeters, boundary: boundary, osmId: osmId)
    }
    
    // Helper to create hexagonal territory (more game-like)
    static func hexagonal(center: CLLocationCoordinate2D, radiusMeters: Double, osmId: String? = nil) -> Territory {
        let points = 6
        let boundary = (0..<points).map { i -> CLLocationCoordinate2D in
            let angle = Double(i) * .pi / 3.0 // 60 degrees per side
            
            let latDelta = (radiusMeters / 111_000) * cos(angle)
            let lonDelta = (radiusMeters / (111_000 * cos(center.latitude * .pi / 180))) * sin(angle)
            
            return CLLocationCoordinate2D(
                latitude: center.latitude + latDelta,
                longitude: center.longitude + lonDelta
            )
        }
        
        return Territory(center: center, radiusMeters: radiusMeters, boundary: boundary, osmId: osmId)
    }
    
    // Helper to create irregular shape (more realistic for towns)
    static func irregularShape(center: CLLocationCoordinate2D, radiusMeters: Double, osmId: String? = nil) -> Territory {
        let points = 12
        let boundary = (0..<points).map { i -> CLLocationCoordinate2D in
            let angle = Double(i) * 2 * .pi / Double(points)
            
            // Add randomness to radius (0.7 to 1.3 of base radius)
            let radiusVariation = Double.random(in: 0.75...1.25)
            let adjustedRadius = radiusMeters * radiusVariation
            
            let latDelta = (adjustedRadius / 111_000) * cos(angle)
            let lonDelta = (adjustedRadius / (111_000 * cos(center.latitude * .pi / 180))) * sin(angle)
            
            return CLLocationCoordinate2D(
                latitude: center.latitude + latDelta,
                longitude: center.longitude + lonDelta
            )
        }
        
        return Territory(center: center, radiusMeters: radiusMeters, boundary: boundary, osmId: osmId)
    }
}

enum KingdomColor: CaseIterable, Hashable {
    // Medieval parchment/war map colors - browns, tans, sepias
    case burntSienna, darkBrown, tan, russet, sepia, umber, ochre, bronze
    
    var rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        switch self {
        case .burntSienna: return (0.55, 0.27, 0.07, 0.25)  // Burnt Sienna - warm reddish brown
        case .darkBrown:   return (0.40, 0.26, 0.13, 0.25)  // Dark Brown - deep earth tone
        case .tan:         return (0.82, 0.71, 0.55, 0.25)  // Tan - light parchment
        case .russet:      return (0.50, 0.27, 0.11, 0.25)  // Russet - reddish brown
        case .sepia:       return (0.44, 0.26, 0.08, 0.25)  // Sepia - classic old photo brown
        case .umber:       return (0.39, 0.32, 0.28, 0.25)  // Raw Umber - grayish brown
        case .ochre:       return (0.80, 0.47, 0.13, 0.25)  // Yellow Ochre - golden brown
        case .bronze:      return (0.51, 0.36, 0.21, 0.25)  // Bronze - metallic brown
        }
    }
    
    var strokeRGBA: (red: Double, green: Double, blue: Double, alpha: Double) {
        let fill = rgba
        // Darker, more opaque strokes for hand-drawn map feel
        return (fill.red * 0.6, fill.green * 0.6, fill.blue * 0.6, 0.9)
    }
}

