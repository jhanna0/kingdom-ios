import Foundation
import CoreLocation

// Building upgrade cost information
struct BuildingUpgradeCost: Codable, Hashable {
    let actionsRequired: Int
    let constructionCost: Int
    let canAfford: Bool
    
    enum CodingKeys: String, CodingKey {
        case actionsRequired = "actions_required"
        case constructionCost = "construction_cost"
        case canAfford = "can_afford"
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


struct Kingdom: Identifiable, Equatable, Hashable {
    let id: String  // OSM ID - matches city_boundary_osm_id in backend
    let name: String
    var rulerName: String
    var rulerId: Int?  // Player ID of ruler (nil if unclaimed) - PostgreSQL auto-generated
    var territory: Territory  // var so we can update boundary after lazy load
    let color: KingdomColor
    var canClaim: Bool  // Backend determines if current user can claim
    
    // Loading state
    var isCurrentCity: Bool  // True if user is currently inside this city (from API)
    var hasBoundaryCached: Bool  // True if full boundary polygon is loaded
    
    // Game stats
    var treasuryGold: Int
    var wallLevel: Int
    var vaultLevel: Int
    var checkedInPlayers: Int
    
    // Economic buildings (generate passive income)
    var mineLevel: Int
    var marketLevel: Int
    var farmLevel: Int  // Speeds up contract completion
    var educationLevel: Int  // Reduces training actions required
    
    // Building upgrade costs (calculated by backend)
    var wallUpgradeCost: BuildingUpgradeCost?
    var vaultUpgradeCost: BuildingUpgradeCost?
    var mineUpgradeCost: BuildingUpgradeCost?
    var marketUpgradeCost: BuildingUpgradeCost?
    var farmUpgradeCost: BuildingUpgradeCost?
    var educationUpgradeCost: BuildingUpgradeCost?
    
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
    var weeklyUniqueCheckIns: Int  // Track unique players who checked in this week
    var totalIncomeCollected: Int  // Lifetime income collected
    var incomeHistory: [IncomeRecord]  // Recent income collections
    
    static func == (lhs: Kingdom, rhs: Kingdom) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init?(name: String, rulerName: String = "Unclaimed", rulerId: Int? = nil, territory: Territory, color: KingdomColor, canClaim: Bool = false) {
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
        self.isCurrentCity = false  // Set by CityAPI after fetch
        self.hasBoundaryCached = true  // Assume true, CityAPI sets false if needed
        self.treasuryGold = Int.random(in: 100...500)
        self.wallLevel = Int.random(in: 0...3)
        self.vaultLevel = Int.random(in: 0...2)
        self.checkedInPlayers = Int.random(in: 0...5)
        self.mineLevel = Int.random(in: 0...2)
        self.marketLevel = Int.random(in: 0...2)
        self.farmLevel = 0  // Start at 0
        self.educationLevel = 0  // Start at 0
        self.taxRate = Int.random(in: 5...20)  // Random starting tax rate
        self.travelFee = 10  // Default travel fee
        self.lastIncomeCollection = Date().addingTimeInterval(-86400) // Start 1 day ago
        self.weeklyUniqueCheckIns = Int.random(in: 0...10)
        self.totalIncomeCollected = 0
        self.incomeHistory = []
        self.activeContract = nil
        self.activeQuests = []
        self.allies = []
        self.enemies = []
        
        // Upgrade costs will be populated by API
        self.wallUpgradeCost = nil
        self.vaultUpgradeCost = nil
        self.mineUpgradeCost = nil
        self.marketUpgradeCost = nil
        self.farmUpgradeCost = nil
        self.educationUpgradeCost = nil
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
    
    // MARK: - Economy & Income
    
    /// Calculate daily income based on city activity and buildings
    var dailyIncome: Int {
        // Base income - every city generates something
        let baseIncome = 30
        
        // Population bonus - active cities are more valuable
        // Each unique player who checked in this week adds 5 gold/day
        let populationBonus = weeklyUniqueCheckIns * 5
        
        // Market generates passive income
        let marketBonus: Int = {
            switch marketLevel {
            case 1: return 15
            case 2: return 35
            case 3: return 65
            case 4: return 100
            case 5: return 150
            default: return 0
            }
        }()
        
        return baseIncome + populationBonus + marketBonus
    }
    
    // MARK: - Material Availability
    
    /// Get available materials based on mine level
    func getAvailableMaterials() -> [String] {
        switch mineLevel {
        case 0: return []
        case 1: return ["stone"]
        case 2: return ["stone", "iron"]
        case 3: return ["stone", "iron", "steel"]
        case 4: return ["stone", "iron", "steel", "titanium"]
        case 5: return ["stone", "iron", "steel", "titanium"]
        default: return []
        }
    }
    
    /// Get material cost in gold
    func getMaterialCost(material: String) -> Int {
        switch material.lowercased() {
        case "stone": return 10
        case "iron": return 25
        case "steel": return 50
        case "titanium": return 100
        default: return 0
        }
    }
    
    /// Get purchase quantity multiplier based on market level
    func getPurchaseQuantityMultiplier() -> Double {
        switch marketLevel {
        case 0: return 0.0  // No market = can't buy
        case 1, 2: return 1.0
        case 3, 4: return 1.5
        case 5: return 2.0
        default: return 1.0
        }
    }
    
    /// Check if materials can be purchased (requires market T1+)
    var canPurchaseMaterials: Bool {
        return marketLevel >= 1
    }
    
    /// Calculate hourly income (for real-time display)
    var hourlyIncome: Int {
        return dailyIncome / 24
    }
    
    /// Collect income since last collection
    mutating func collectIncome() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastIncomeCollection)
        let hoursElapsed = elapsed / 3600.0
        
        // Calculate income earned
        let incomeEarned = Int(Double(hourlyIncome) * hoursElapsed)
        
        // Add to treasury
        treasuryGold += incomeEarned
        
        // Track total income
        totalIncomeCollected += incomeEarned
        
        // Record in history (keep last 20 records)
        let record = IncomeRecord(
            amount: incomeEarned,
            hourlyRate: hourlyIncome,
            dailyRate: dailyIncome
        )
        incomeHistory.insert(record, at: 0)
        if incomeHistory.count > 20 {
            incomeHistory = Array(incomeHistory.prefix(20))
        }
        
        // Update last collection time
        lastIncomeCollection = now
    }
    
    /// Check if income is available to collect
    var hasIncomeToCollect: Bool {
        let elapsed = Date().timeIntervalSince(lastIncomeCollection)
        return elapsed >= 3600 // At least 1 hour has passed
    }
    
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
    var pendingIncome: Int {
        let elapsed = Date().timeIntervalSince(lastIncomeCollection)
        let hoursElapsed = elapsed / 3600.0
        return Int(Double(hourlyIncome) * hoursElapsed)
    }
    
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

