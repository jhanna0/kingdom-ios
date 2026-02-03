import Foundation
import MapKit

/// Load REAL town/city boundaries from OpenStreetMap
class OSMLoader {
    
    // Multiple Overpass API endpoints for redundancy
    private static let overpassEndpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]
    
    /// Main entry point - get REAL town boundaries near user
    static func loadRealTownBoundaries(around center: CLLocationCoordinate2D, radiusKm: Double = 30) async -> [Kingdom] {
        // Use Overpass API with full geometry (most reliable)
        if let kingdoms = await tryOverpassWithFullGeometry(center: center, radiusKm: radiusKm), !kingdoms.isEmpty {
            return kingdoms
        }
        
        print("❌ Failed to load towns")
        return []
    }
    
    // MARK: - Overpass with full geometry
    
    private static func tryOverpassWithFullGeometry(center: CLLocationCoordinate2D, radiusKm: Double) async -> [Kingdom]? {
        
        let query = """
        [out:json][timeout:30];
        relation["boundary"="administrative"]["admin_level"~"^(7|8|9|10)$"]["name"](around:\(Int(radiusKm * 1000)),\(center.latitude),\(center.longitude));
        out geom;
        """
        
        for endpoint in overpassEndpoints {
            if let kingdoms = await executeOverpassQuery(query: query, endpoint: endpoint, center: center) {
                if !kingdoms.isEmpty {
                    return kingdoms
                }
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        
        return nil
    }
    
    private static func executeOverpassQuery(query: String, endpoint: String, center: CLLocationCoordinate2D) async -> [Kingdom]? {
        guard let url = URL(string: endpoint) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("KingdomApp/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)
        request.timeoutInterval = 35
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 { return nil }
            }
            
            return parseOverpassGeomResponse(data: data, userLocation: center)
            
        } catch {
            return nil
        }
    }
    
    private static func parseOverpassGeomResponse(data: Data, userLocation: CLLocationCoordinate2D) -> [Kingdom] {
        var kingdoms: [Kingdom] = []
        let colors = KingdomColor.allCases
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let elements = json["elements"] as? [[String: Any]] else {
                return []
            }
            
            for element in elements {
                guard let type = element["type"] as? String, type == "relation",
                      let tags = element["tags"] as? [String: String],
                      let name = tags["name"],
                      let members = element["members"] as? [[String: Any]] else {
                    continue
                }
                
                // Extract OSM ID if available
                let osmId: String?
                if let id = element["id"] as? Int64 {
                    osmId = "relation/\(id)"
                } else if let id = element["id"] as? Int {
                    osmId = "relation/\(id)"
                } else {
                    osmId = nil
                }
                
                // Collect ALL coordinate segments from outer ways
                var waySegments: [[CLLocationCoordinate2D]] = []
                var totalRawPoints = 0
                
                for member in members {
                    guard let role = member["role"] as? String,
                          role == "outer",
                          let memberType = member["type"] as? String,
                          memberType == "way",
                          let geometry = member["geometry"] as? [[String: Any]] else {
                        continue
                    }
                    
                    var segment: [CLLocationCoordinate2D] = []
                            for point in geometry {
                                if let lat = point["lat"] as? Double,
                                   let lon = point["lon"] as? Double {
                            segment.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                    }
                    
                    if segment.count >= 2 {
                        waySegments.append(segment)
                        totalRawPoints += segment.count
                    }
                }
                
                
                // Join segments into a complete boundary
                let boundary = buildCompleteBoundary(from: waySegments)
                
                if boundary.count < 10 {
                    continue
                }
                
                let boundaryCenter = calculateCenter(boundary)
                let distance = distanceBetween(userLocation, boundaryCenter)
                
                // Skip if WAY too far (but keep generous radius for continuous coverage)
                if distance > 40_000 {
                    print("    ⏭️ \(name): too far (\(Int(distance/1000))km)")
                    continue
                }
                
                // Simplify to reasonable size for rendering (25-150 points)
                let simplified = simplifyPolygonDP(boundary, targetPoints: 100, minimumPoints: 25)
                
                // Calculate center from the SIMPLIFIED boundary (what's actually drawn)
                let visualCenter = calculatePolygonCentroid(simplified)
                let radius = calculateRadius(center: visualCenter, boundary: simplified)
                
                let territory = Territory(center: visualCenter, radiusMeters: radius, boundary: simplified, osmId: osmId)
                let color = colors[kingdoms.count % colors.count]
                
                if let kingdom = Kingdom(
                    name: name,
                    rulerName: generateRulerName(for: name),
                    territory: territory,
                    color: color
                ) {
                    kingdoms.append(kingdom)
                    print("    🏰 \(name) - \(simplified.count) points, \(Int(distance/1000))km away")
                }
            }
            
        } catch {
            print("    ❌ Parse error: \(error)")
        }
        
        // Sort by distance from user and take closest 35
        let sortedKingdoms = kingdoms.sorted { k1, k2 in
            let dist1 = distanceBetween(userLocation, k1.territory.center)
            let dist2 = distanceBetween(userLocation, k2.territory.center)
            return dist1 < dist2
        }
        
        return Array(sortedKingdoms.prefix(35))
    }
    
    /// Build a complete boundary from disconnected way segments
    /// This handles the OSM case where boundaries are made of multiple ways
    private static func buildCompleteBoundary(from segments: [[CLLocationCoordinate2D]]) -> [CLLocationCoordinate2D] {
        guard !segments.isEmpty else { return [] }
        
        // Count total points across all segments
        _ = segments.reduce(0) { $0 + $1.count }
        
        if segments.count == 1 {
            return ensureClosed(segments[0])
        }
        
        // Try to join segments end-to-end
        var result: [CLLocationCoordinate2D] = []
        let remaining = segments
        var used = Set<Int>()
        
        // Start with the longest segment
        var longestIdx = 0
        var longestCount = 0
        for (idx, seg) in remaining.enumerated() {
            if seg.count > longestCount {
                longestCount = seg.count
                longestIdx = idx
            }
        }
        
        result = remaining[longestIdx]
        used.insert(longestIdx)
        
        // Keep trying to extend the boundary with progressively larger tolerance
        let tolerances = [0.0001, 0.0005, 0.001, 0.005, 0.01]
        
        for tolerance in tolerances {
            var madeProgress = true
            
            while madeProgress && used.count < remaining.count {
                madeProgress = false
                
                guard let currentEnd = result.last, let currentStart = result.first else { break }
                
                var bestMatch: (index: Int, reversed: Bool, atEnd: Bool, distance: Double)?
                
                for (index, segment) in remaining.enumerated() {
                    if used.contains(index) || segment.isEmpty { continue }
                    
                    guard let segStart = segment.first, let segEnd = segment.last else { continue }
                    
                    let distEndToStart = coordDistance(currentEnd, segStart)
                    let distEndToEnd = coordDistance(currentEnd, segEnd)
                    let distStartToEnd = coordDistance(currentStart, segEnd)
                    let distStartToStart = coordDistance(currentStart, segStart)
                    
                    if distEndToStart < tolerance {
                        if bestMatch == nil || distEndToStart < bestMatch!.distance {
                            bestMatch = (index, false, true, distEndToStart)
                        }
                    }
                    if distEndToEnd < tolerance {
                        if bestMatch == nil || distEndToEnd < bestMatch!.distance {
                            bestMatch = (index, true, true, distEndToEnd)
                        }
                    }
                    if distStartToEnd < tolerance {
                        if bestMatch == nil || distStartToEnd < bestMatch!.distance {
                            bestMatch = (index, false, false, distStartToEnd)
                        }
                    }
                    if distStartToStart < tolerance {
                        if bestMatch == nil || distStartToStart < bestMatch!.distance {
                            bestMatch = (index, true, false, distStartToStart)
                        }
                    }
                }
                
                if let match = bestMatch {
                    used.insert(match.index)
                    var segment = remaining[match.index]
                    
                    if match.reversed {
                        segment.reverse()
                    }
                    
                    if match.atEnd {
                        result.append(contentsOf: segment.dropFirst())
                    } else {
                        result = Array(segment.dropLast()) + result
                    }
                    madeProgress = true
                }
            }
        }
        
        // If we have unused segments, we need a different approach
        // Collect all points and sort by angle from center
        if used.count < remaining.count {
            var allPoints: [CLLocationCoordinate2D] = result
            
            for (index, segment) in remaining.enumerated() {
                if !used.contains(index) {
                    allPoints.append(contentsOf: segment)
                }
            }
            
            // Sort points by angle from center to create a coherent polygon
            result = sortPointsByAngle(allPoints)
        }
        
        return ensureClosed(result)
    }
    
    /// Sort points by angle from their centroid to create a coherent polygon
    private static func sortPointsByAngle(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }
        
        let center = calculateCenter(points)
        
        let sorted = points.sorted { a, b in
            let angleA = atan2(a.latitude - center.latitude, a.longitude - center.longitude)
            let angleB = atan2(b.latitude - center.latitude, b.longitude - center.longitude)
            return angleA < angleB
        }
        
        return sorted
    }
    
    /// Ensure the polygon is closed (first point == last point)
    private static func ensureClosed(_ coords: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coords.count >= 3 else { return coords }
        guard let first = coords.first, let last = coords.last else { return coords }
        
        if coordDistance(first, last) > 0.00001 {
            return coords + [first]
        }
        return coords
    }
    
    private static func coordDistance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let latDiff = a.latitude - b.latitude
        let lonDiff = a.longitude - b.longitude
        return sqrt(latDiff * latDiff + lonDiff * lonDiff)
    }
    
    // MARK: - Strategy 2: Nominatim Search
    
    private static func tryNominatimSearch(center: CLLocationCoordinate2D, radiusKm: Double) async -> [Kingdom]? {
        print("📡 Strategy 2: Nominatim search...")
        
        var kingdoms: [Kingdom] = []
        let colors = KingdomColor.allCases
        var seenPlaces = Set<String>()
        
        let delta = radiusKm / 111.0
        let bbox = "\(center.longitude - delta),\(center.latitude - delta),\(center.longitude + delta),\(center.latitude + delta)"
        
        let urlString = "https://nominatim.openstreetmap.org/search?format=json&polygon_geojson=1&limit=20&featuretype=city,town,village&viewbox=\(bbox)&bounded=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("KingdomApp/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            print("    Status: \(httpResponse.statusCode)")
            
            guard let places = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            print("    Found \(places.count) places")
            
            for place in places {
                guard let displayName = place["display_name"] as? String,
                      let latStr = place["lat"] as? String,
                      let lonStr = place["lon"] as? String,
                      let lat = Double(latStr),
                      let lon = Double(lonStr) else { continue }
                
                let name = displayName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? displayName
                if seenPlaces.contains(name) { continue }
                seenPlaces.insert(name)
                
                // Extract OSM ID from Nominatim response
                let osmId: String?
                if let osmType = place["osm_type"] as? String,
                   let osmIdNum = place["osm_id"] as? Int64 {
                    osmId = "\(osmType)/\(osmIdNum)"
                } else if let osmType = place["osm_type"] as? String,
                          let osmIdNum = place["osm_id"] as? Int {
                    osmId = "\(osmType)/\(osmIdNum)"
                } else {
                    osmId = nil
                }
                
                guard let boundary = parseGeoJSON(place["geojson"]), boundary.count >= 10 else { continue }
                
                let placeCenter = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let distance = distanceBetween(center, placeCenter)
                if distance > 50_000 { continue }
                
                let simplified = simplifyPolygonDP(boundary, targetPoints: 100, minimumPoints: 25)
                let visualCenter = calculatePolygonCentroid(simplified)
                let radius = calculateRadius(center: visualCenter, boundary: simplified)
                
                let territory = Territory(center: visualCenter, radiusMeters: radius, boundary: simplified, osmId: osmId)
                let color = colors[kingdoms.count % colors.count]
                
                if let kingdom = Kingdom(name: name, rulerName: generateRulerName(for: name), territory: territory, color: color) {
                    kingdoms.append(kingdom)
                    print("    🏰 \(name) - \(simplified.count) points")
                }
            }
            
        } catch {
            print("    ❌ Error: \(error.localizedDescription)")
        }
        
        // Sort by distance from user and take closest 35
        let sortedKingdoms = kingdoms.sorted { k1, k2 in
            let dist1 = distanceBetween(center, k1.territory.center)
            let dist2 = distanceBetween(center, k2.territory.center)
            return dist1 < dist2
        }
        
        return sortedKingdoms.isEmpty ? nil : Array(sortedKingdoms.prefix(35))
    }
    
    // MARK: - Strategy 3: Nominatim Reverse Grid
    
    private static func tryNominatimReverseGrid(center: CLLocationCoordinate2D, radiusKm: Double) async -> [Kingdom]? {
        print("📡 Strategy 3: Nominatim reverse grid...")
        
        var kingdoms: [Kingdom] = []
        var seenPlaces = Set<String>()
        let colors = KingdomColor.allCases
        
        let gridSize = 5
        let stepDegrees = (radiusKm / 111.0) / Double(gridSize / 2)
        
        for latStep in stride(from: -gridSize/2, through: gridSize/2, by: 1) {
            for lonStep in stride(from: -gridSize/2, through: gridSize/2, by: 1) {
                let searchLat = center.latitude + Double(latStep) * stepDegrees
                let searchLon = center.longitude + Double(lonStep) * stepDegrees
                
                let urlString = "https://nominatim.openstreetmap.org/reverse?format=json&lat=\(searchLat)&lon=\(searchLon)&zoom=10&polygon_geojson=1"
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.setValue("KingdomApp/1.0", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    
                    var placeName: String?
                    if let address = json["address"] as? [String: Any] {
                        placeName = address["city"] as? String ?? address["town"] as? String ?? address["village"] as? String
                    }
                    
                    guard let name = placeName, !seenPlaces.contains(name) else { continue }
                    seenPlaces.insert(name)
                    
                    // Extract OSM ID from Nominatim response
                    let osmId: String?
                    if let osmType = json["osm_type"] as? String,
                       let osmIdNum = json["osm_id"] as? Int64 {
                        osmId = "\(osmType)/\(osmIdNum)"
                    } else if let osmType = json["osm_type"] as? String,
                              let osmIdNum = json["osm_id"] as? Int {
                        osmId = "\(osmType)/\(osmIdNum)"
                    } else {
                        osmId = nil
                    }
                    
                    guard let boundary = parseGeoJSON(json["geojson"]), boundary.count >= 10 else { continue }
                    
                    let placeCenter = calculateCenter(boundary)
                    let distance = distanceBetween(center, placeCenter)
                    if distance > 40_000 { continue }
                    
                    let simplified = simplifyPolygonDP(boundary, targetPoints: 100, minimumPoints: 25)
                    let visualCenter = calculatePolygonCentroid(simplified)
                    let radius = calculateRadius(center: visualCenter, boundary: simplified)
                    
                    let territory = Territory(center: visualCenter, radiusMeters: radius, boundary: simplified, osmId: osmId)
                    let color = colors[kingdoms.count % colors.count]
                    
                    if let kingdom = Kingdom(name: name, rulerName: generateRulerName(for: name), territory: territory, color: color) {
                        kingdoms.append(kingdom)
                        print("    🏰 \(name) - \(simplified.count) points")
                    }
                    
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    
                } catch { continue }
            }
        }
        
        // Sort by distance from user and take closest 35
        let sortedKingdoms = kingdoms.sorted { k1, k2 in
            let dist1 = distanceBetween(center, k1.territory.center)
            let dist2 = distanceBetween(center, k2.territory.center)
            return dist1 < dist2
        }
        
        return sortedKingdoms.isEmpty ? nil : Array(sortedKingdoms.prefix(35))
    }
    
    // MARK: - GeoJSON Parsing
    
    private static func parseGeoJSON(_ geojson: Any?) -> [CLLocationCoordinate2D]? {
        guard let geo = geojson as? [String: Any], let geoType = geo["type"] as? String else { return nil }
        
        var coords: [CLLocationCoordinate2D] = []
        
        switch geoType {
        case "Polygon":
            if let rings = geo["coordinates"] as? [[[Double]]], let ring = rings.first {
                coords = ring.compactMap { coord in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
            }
            
        case "MultiPolygon":
            if let polygons = geo["coordinates"] as? [[[[Double]]]] {
                var largestRing: [[Double]] = []
                for polygon in polygons {
                    if let ring = polygon.first, ring.count > largestRing.count {
                        largestRing = ring
                    }
                }
                coords = largestRing.compactMap { coord in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
            }
            
        default:
            return nil
        }
        
        return coords.count >= 4 ? coords : nil
    }
    
    // MARK: - Helpers
    
    private static func calculateCenter(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let sum = coords.reduce((lat: 0.0, lon: 0.0)) { ($0.lat + $1.latitude, $0.lon + $1.longitude) }
        return CLLocationCoordinate2D(latitude: sum.lat / Double(coords.count), longitude: sum.lon / Double(coords.count))
    }
    
    /// Calculate the true centroid of a polygon (weighted by area, not just average of points)
    /// This places the center in the visual middle of irregular shapes
    private static func calculatePolygonCentroid(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard coords.count >= 3 else {
            return calculateCenter(coords)
        }
        
        var signedArea: Double = 0
        var centroidLat: Double = 0
        var centroidLon: Double = 0
        
        let n = coords.count
        for i in 0..<n {
            let current = coords[i]
            let next = coords[(i + 1) % n]
            
            let a = current.longitude * next.latitude - next.longitude * current.latitude
            signedArea += a
            centroidLat += (current.latitude + next.latitude) * a
            centroidLon += (current.longitude + next.longitude) * a
        }
        
        signedArea *= 0.5
        
        // If area is too small, fall back to simple average
        guard abs(signedArea) > 0.0000001 else {
            return calculateCenter(coords)
        }
        
        centroidLat /= (6.0 * signedArea)
        centroidLon /= (6.0 * signedArea)
        
        return CLLocationCoordinate2D(latitude: centroidLat, longitude: centroidLon)
    }
    
    private static func calculateRadius(center: CLLocationCoordinate2D, boundary: [CLLocationCoordinate2D]) -> Double {
        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let distances = boundary.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: centerLoc) }
        return distances.reduce(0, +) / Double(distances.count)
    }
    
    private static func distanceBetween(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
        let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
        return loc1.distance(from: loc2)
    }
    
    private static func generateRulerName(for townName: String = "") -> String {
        // Special case for Manchester
        if townName == "Manchester" {
            return "k1ng"
        }
        return ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Henry", "Iris", "Jack", "Kate", "Leo", "Maya", "Noah", "Olivia", "Peter"].randomElement() ?? "Unknown"
    }
    
    /// Douglas-Peucker simplification - preserves shape better than uniform sampling
    /// NEVER goes below minimumPoints to prevent degenerate polygons
    private static func simplifyPolygonDP(_ points: [CLLocationCoordinate2D], targetPoints: Int, minimumPoints: Int = 25) -> [CLLocationCoordinate2D] {
        guard points.count > targetPoints else { return points }
        
        // Start with a small tolerance and increase until we hit target
        // BUT stop if we go below minimum
        var tolerance = 0.00001
        var result = points
        var previousResult = points
        
        while result.count > targetPoints && tolerance < 0.01 {
            previousResult = result
            result = douglasPeucker(points, tolerance: tolerance)
            
            // CRITICAL: If we went below minimum, use the previous result
            if result.count < minimumPoints {
                result = previousResult
                break
            }
            
            tolerance *= 1.5 // Slower increase for better control
        }
        
        // Final safety check - if still too few points, use uniform sampling
        if result.count < minimumPoints && points.count >= minimumPoints {
            result = uniformSample(points, targetCount: minimumPoints)
        }
        
        return ensureClosed(result)
    }
    
    /// Uniform sampling fallback - guaranteed to return targetCount points
    private static func uniformSample(_ points: [CLLocationCoordinate2D], targetCount: Int) -> [CLLocationCoordinate2D] {
        guard points.count > targetCount else { return points }
        
        let step = Double(points.count) / Double(targetCount)
        var result: [CLLocationCoordinate2D] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            if index < points.count {
                result.append(points[index])
            }
        }
        
        return result
    }
    
    private static func douglasPeucker(_ points: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard points.count >= 3 else { return points }
        
        var dmax = 0.0
        var index = 0
        let end = points.count - 1
        
        for i in 1..<end {
            let d = perpendicularDistance(point: points[i], lineStart: points[0], lineEnd: points[end])
            if d > dmax {
                index = i
                dmax = d
            }
        }
        
        if dmax > tolerance {
            let left = douglasPeucker(Array(points[0...index]), tolerance: tolerance)
            let right = douglasPeucker(Array(points[index...end]), tolerance: tolerance)
            return Array(left.dropLast()) + right
        } else {
            return [points[0], points[end]]
        }
    }
    
    private static func perpendicularDistance(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        
        let mag = sqrt(dx * dx + dy * dy)
        guard mag > 0 else { return 0 }
        
        let u = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / (mag * mag)
        
        let closestX: Double
        let closestY: Double
        
        if u < 0 {
            closestX = lineStart.longitude
            closestY = lineStart.latitude
        } else if u > 1 {
            closestX = lineEnd.longitude
            closestY = lineEnd.latitude
        } else {
            closestX = lineStart.longitude + u * dx
            closestY = lineStart.latitude + u * dy
        }
        
        let ddx = point.longitude - closestX
        let ddy = point.latitude - closestY
        
        return sqrt(ddx * ddx + ddy * ddy)
    }
}

