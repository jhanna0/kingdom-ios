import Foundation
import CoreLocation

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

// Reward distribution records
struct DistributionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let totalPool: Int
    let recipientCount: Int
    let recipients: [RecipientRecord]
    
    init(totalPool: Int, recipients: [RecipientRecord]) {
        self.id = UUID()
        self.timestamp = Date()
        self.totalPool = totalPool
        self.recipientCount = recipients.count
        self.recipients = recipients
    }
}

struct RecipientRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let playerId: String
    let playerName: String
    let goldReceived: Int
    let meritScore: Int
    let reputation: Int
    let skillTotal: Int
    
    init(playerId: String, playerName: String, goldReceived: Int, meritScore: Int, reputation: Int, skillTotal: Int) {
        self.id = UUID()
        self.playerId = playerId
        self.playerName = playerName
        self.goldReceived = goldReceived
        self.meritScore = meritScore
        self.reputation = reputation
        self.skillTotal = skillTotal
    }
}

struct Kingdom: Identifiable, Equatable, Hashable {
    let id: String  // OSM ID - matches city_boundary_osm_id in backend
    let name: String
    var rulerName: String
    var rulerId: String?  // Player ID of ruler (nil if unclaimed)
    let territory: Territory
    let color: KingdomColor
    
    // Game stats
    var treasuryGold: Int
    var wallLevel: Int
    var vaultLevel: Int
    var checkedInPlayers: Int
    
    // Economic buildings (generate passive income)
    var mineLevel: Int
    var marketLevel: Int
    
    // Tax system (0-100%)
    var taxRate: Int  // Percentage of mined resources going to treasury
    
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
    
    // Subject reward distribution system
    var subjectRewardRate: Int  // Percentage of income to distribute (0-50%)
    var lastRewardDistribution: Date
    var totalRewardsDistributed: Int  // Lifetime rewards given to subjects
    var distributionHistory: [DistributionRecord]  // Recent distributions (keep last 30)
    
    static func == (lhs: Kingdom, rhs: Kingdom) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init?(name: String, rulerName: String = "Unclaimed", rulerId: String? = nil, territory: Territory, color: KingdomColor) {
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
        self.treasuryGold = Int.random(in: 100...500)
        self.wallLevel = Int.random(in: 0...3)
        self.vaultLevel = Int.random(in: 0...2)
        self.checkedInPlayers = Int.random(in: 0...5)
        self.mineLevel = Int.random(in: 0...2)
        self.marketLevel = Int.random(in: 0...2)
        self.taxRate = Int.random(in: 5...20)  // Random starting tax rate
        self.lastIncomeCollection = Date().addingTimeInterval(-86400) // Start 1 day ago
        self.weeklyUniqueCheckIns = Int.random(in: 0...10)
        self.totalIncomeCollected = 0
        self.incomeHistory = []
        self.activeContract = nil
        self.activeQuests = []
        self.allies = []
        self.enemies = []
        
        // Initialize reward distribution
        self.subjectRewardRate = 15  // Default: 15% distribution rate
        self.lastRewardDistribution = Date().addingTimeInterval(-86400) // Start 1 day ago
        self.totalRewardsDistributed = 0
        self.distributionHistory = []
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
    mutating func setRuler(playerId: String, playerName: String) {
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
        
        // Building bonuses
        let mineBonus: Int = {
            switch mineLevel {
            case 1: return 10
            case 2: return 25
            case 3: return 50
            case 4: return 80
            case 5: return 120
            default: return 0
            }
        }()
        
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
        
        return baseIncome + populationBonus + mineBonus + marketBonus
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
    
    /// Set the subject reward distribution rate (ruler only)
    mutating func setSubjectRewardRate(_ rate: Int) {
        subjectRewardRate = max(0, min(50, rate))  // Clamp 0-50%
    }
    
    /// Calculate daily reward pool based on income and distribution rate
    var dailyRewardPool: Int {
        return Int(Double(dailyIncome) * Double(subjectRewardRate) / 100.0)
    }
    
    /// Check if rewards are ready to distribute (24 hours since last)
    var canDistributeRewards: Bool {
        let elapsed = Date().timeIntervalSince(lastRewardDistribution)
        return elapsed >= 82800 // 23 hours (allow slight early trigger)
    }
    
    /// Get pending reward pool (accumulated since last distribution)
    var pendingRewardPool: Int {
        let elapsed = Date().timeIntervalSince(lastRewardDistribution)
        let hoursElapsed = elapsed / 3600.0
        let hourlyPool = dailyRewardPool / 24
        return Int(Double(hourlyPool) * hoursElapsed)
    }
    
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

