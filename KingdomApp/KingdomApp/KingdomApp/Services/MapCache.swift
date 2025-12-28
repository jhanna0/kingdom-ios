import Foundation
import CoreLocation

/// Specialized cache for map data (kingdoms, GeoJSON)
class MapCache {
    static let shared = MapCache()
    
    // Cache configuration
    private let cacheExpiration: TimeInterval = 24 * 3600  // 24 hours
    private let cacheManager = CacheManager.shared
    
    // MARK: - Kingdom Cache
    
    /// Save kingdoms to cache for a specific location
    func saveKingdoms(_ kingdoms: [Kingdom], forLocation location: CLLocationCoordinate2D, radius: Double) {
        let cacheKey = kingdomsCacheKey(location: location, radius: radius)
        let cacheData = KingdomsCacheData(
            kingdoms: kingdoms.map { CachedKingdom(from: $0) },
            location: CachedCoordinate(from: location),
            radius: radius,
            timestamp: Date()
        )
        
        cacheManager.save(cacheData, forKey: cacheKey)
        print("💾 Cached \(kingdoms.count) kingdoms for location")
    }
    
    /// Load kingdoms from cache for a specific location
    func loadKingdoms(forLocation location: CLLocationCoordinate2D, radius: Double) -> [Kingdom]? {
        let cacheKey = kingdomsCacheKey(location: location, radius: radius)
        
        // Check if cache exists and is not expired
        if cacheManager.isExpired(forKey: cacheKey, maxAge: cacheExpiration) {
            print("⏰ Kingdom cache expired")
            return nil
        }
        
        guard let cacheData = cacheManager.load(KingdomsCacheData.self, forKey: cacheKey) else {
            return nil
        }
        
        // Verify cache is for similar location (within 1 mile)
        let distance = calculateDistance(from: location, to: cacheData.location.toCoordinate())
        let distanceMiles = distance / 1609.34
        
        if distanceMiles > 1.0 || abs(radius - cacheData.radius) > 1.0 {
            print("📍 Cache location mismatch (distance: \(String(format: "%.2f", distanceMiles)) miles)")
            return nil
        }
        
        print("✅ Loaded \(cacheData.kingdoms.count) kingdoms from cache")
        return cacheData.kingdoms.map { $0.toKingdom() }
    }
    
    /// Clear kingdom cache
    func clearKingdomsCache() {
        // Remove all kingdom cache files
        let cacheKey = "kingdoms_"
        // This is a simple implementation - could be improved with better key tracking
        cacheManager.remove(forKey: cacheKey)
    }
    
    // MARK: - GeoJSON Cache
    
    /// Save raw GeoJSON data to cache
    func saveGeoJSON(_ data: Data, forURL urlString: String) {
        let cacheKey = geoJSONCacheKey(url: urlString)
        let cacheData = GeoJSONCacheData(data: data, url: urlString, timestamp: Date())
        
        cacheManager.save(cacheData, forKey: cacheKey)
        print("💾 Cached GeoJSON data (\(data.count) bytes)")
    }
    
    /// Load raw GeoJSON data from cache
    func loadGeoJSON(forURL urlString: String) -> Data? {
        let cacheKey = geoJSONCacheKey(url: urlString)
        
        // Check if cache exists and is not expired (GeoJSON rarely changes, use longer expiration)
        let geoJSONExpiration = 7 * 24 * 3600.0  // 7 days
        if cacheManager.isExpired(forKey: cacheKey, maxAge: geoJSONExpiration) {
            print("⏰ GeoJSON cache expired")
            return nil
        }
        
        guard let cacheData = cacheManager.load(GeoJSONCacheData.self, forKey: cacheKey) else {
            return nil
        }
        
        print("✅ Loaded GeoJSON from cache (\(cacheData.data.count) bytes)")
        return cacheData.data
    }
    
    // MARK: - Helper Methods
    
    private func kingdomsCacheKey(location: CLLocationCoordinate2D, radius: Double) -> String {
        // Round coordinates to reduce cache key variations
        let lat = String(format: "%.3f", location.latitude)
        let lon = String(format: "%.3f", location.longitude)
        let rad = String(format: "%.1f", radius)
        return "kingdoms_\(lat)_\(lon)_\(rad)"
    }
    
    private func geoJSONCacheKey(url: String) -> String {
        // Use hash of URL to create cache key
        let hash = url.hashValue
        return "geojson_\(abs(hash))"
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)  // Returns meters
    }
}

// MARK: - Cache Data Structures

/// Cache wrapper for kingdoms data
struct KingdomsCacheData: Codable {
    let kingdoms: [CachedKingdom]
    let location: CachedCoordinate
    let radius: Double
    let timestamp: Date
}

/// Cached version of Kingdom (Codable)
struct CachedKingdom: Codable {
    let id: String
    let name: String
    let rulerName: String
    let rulerId: String?
    let territory: CachedTerritory
    let color: String
    let treasuryGold: Int
    let wallLevel: Int
    let vaultLevel: Int
    let checkedInPlayers: Int
    let mineLevel: Int
    let marketLevel: Int
    let lastIncomeCollection: Date
    let weeklyUniqueCheckIns: Int
    let totalIncomeCollected: Int
    
    init(from kingdom: Kingdom) {
        self.id = kingdom.id.uuidString
        self.name = kingdom.name
        self.rulerName = kingdom.rulerName
        self.rulerId = kingdom.rulerId
        self.territory = CachedTerritory(from: kingdom.territory)
        self.color = String(describing: kingdom.color)
        self.treasuryGold = kingdom.treasuryGold
        self.wallLevel = kingdom.wallLevel
        self.vaultLevel = kingdom.vaultLevel
        self.checkedInPlayers = kingdom.checkedInPlayers
        self.mineLevel = kingdom.mineLevel
        self.marketLevel = kingdom.marketLevel
        self.lastIncomeCollection = kingdom.lastIncomeCollection
        self.weeklyUniqueCheckIns = kingdom.weeklyUniqueCheckIns
        self.totalIncomeCollected = kingdom.totalIncomeCollected
    }
    
    func toKingdom() -> Kingdom {
        let color = KingdomColor.from(string: self.color)
        let territory = self.territory.toTerritory()
        
        var kingdom = Kingdom(
            name: self.name,
            rulerName: self.rulerName,
            rulerId: self.rulerId,
            territory: territory,
            color: color
        )
        
        // Restore cached values
        kingdom.treasuryGold = self.treasuryGold
        kingdom.wallLevel = self.wallLevel
        kingdom.vaultLevel = self.vaultLevel
        kingdom.checkedInPlayers = self.checkedInPlayers
        kingdom.mineLevel = self.mineLevel
        kingdom.marketLevel = self.marketLevel
        kingdom.lastIncomeCollection = self.lastIncomeCollection
        kingdom.weeklyUniqueCheckIns = self.weeklyUniqueCheckIns
        kingdom.totalIncomeCollected = self.totalIncomeCollected
        
        return kingdom
    }
}

/// Cached version of Territory
struct CachedTerritory: Codable {
    let center: CachedCoordinate
    let radiusMeters: Double
    let boundary: [CachedCoordinate]
    
    init(from territory: Territory) {
        self.center = CachedCoordinate(from: territory.center)
        self.radiusMeters = territory.radiusMeters
        self.boundary = territory.boundary.map { CachedCoordinate(from: $0) }
    }
    
    func toTerritory() -> Territory {
        return Territory(
            center: center.toCoordinate(),
            radiusMeters: radiusMeters,
            boundary: boundary.map { $0.toCoordinate() }
        )
    }
}

/// Codable version of CLLocationCoordinate2D
struct CachedCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    func toCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Cache wrapper for GeoJSON data
struct GeoJSONCacheData: Codable {
    let data: Data
    let url: String
    let timestamp: Date
}

// MARK: - KingdomColor Extension

extension KingdomColor {
    /// Convert string to KingdomColor
    static func from(string: String) -> KingdomColor {
        switch string {
        case "burntSienna": return .burntSienna
        case "darkBrown": return .darkBrown
        case "tan": return .tan
        case "russet": return .russet
        case "sepia": return .sepia
        case "umber": return .umber
        case "ochre": return .ochre
        case "bronze": return .bronze
        default: return .burntSienna
        }
    }
}

