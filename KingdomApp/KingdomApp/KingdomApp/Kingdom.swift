import Foundation
import CoreLocation

struct Kingdom: Identifiable, Equatable {
    let id: UUID
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
    
    static func == (lhs: Kingdom, rhs: Kingdom) -> Bool {
        lhs.id == rhs.id
    }
    
    init(name: String, rulerName: String = "Unclaimed", rulerId: String? = nil, territory: Territory, color: KingdomColor) {
        self.id = UUID()
        self.name = name
        self.rulerName = rulerName
        self.rulerId = rulerId
        self.territory = territory
        self.color = color
        self.treasuryGold = Int.random(in: 100...500)
        self.wallLevel = Int.random(in: 0...3)
        self.vaultLevel = Int.random(in: 0...2)
        self.checkedInPlayers = Int.random(in: 0...5)
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

struct Territory {
    let center: CLLocationCoordinate2D
    let radiusMeters: Double
    let boundary: [CLLocationCoordinate2D]
    
    // Helper to create circular territory
    static func circular(center: CLLocationCoordinate2D, radiusMeters: Double, points: Int = 30) -> Territory {
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
        
        return Territory(center: center, radiusMeters: radiusMeters, boundary: boundary)
    }
    
    // Helper to create hexagonal territory (more game-like)
    static func hexagonal(center: CLLocationCoordinate2D, radiusMeters: Double) -> Territory {
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
        
        return Territory(center: center, radiusMeters: radiusMeters, boundary: boundary)
    }
    
    // Helper to create irregular shape (more realistic for towns)
    static func irregularShape(center: CLLocationCoordinate2D, radiusMeters: Double) -> Territory {
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
        
        return Territory(center: center, radiusMeters: radiusMeters, boundary: boundary)
    }
}

enum KingdomColor: CaseIterable {
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

