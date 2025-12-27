import Foundation
import CoreLocation
import MapKit

/// REAL data loading only - NO FAKE FALLBACKS
class SampleData {
    
    // Default location for initial map display (will be replaced by user location)
    static let defaultCenter = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
    
    /// Main entry point - Load REAL towns with REAL boundaries
    /// Returns empty array if no real data can be found - NO FAKE DATA
    static func loadRealTowns(around center: CLLocationCoordinate2D) async -> [Kingdom] {
        print("🏙️ Loading REAL towns around user location...")
        print("📍 Center: \(center.latitude), \(center.longitude)")
        
        // Use OSMLoader to get real boundaries
        let kingdoms = await OSMLoader.loadRealTownBoundaries(around: center, radiusKm: 30)
        
        if kingdoms.isEmpty {
            print("❌ NO REAL TOWN DATA FOUND")
            print("   - Check network connection")
            print("   - OpenStreetMap APIs may be temporarily unavailable")
        } else {
            print("✅ Loaded \(kingdoms.count) REAL towns with REAL boundaries")
            
            // Log what we found
            for kingdom in kingdoms {
                print("   📍 \(kingdom.name) - \(kingdom.territory.boundary.count) boundary points")
            }
        }
        
        return kingdoms
    }
    
    /// Alternative: Use Apple's MapKit to search for cities (less boundary data but more reliable)
    static func loadCitiesViaMapKit(around center: CLLocationCoordinate2D) async -> [Kingdom] {
        print("🗺️ Searching for cities via MapKit...")
        
        var kingdoms: [Kingdom] = []
        let colors = KingdomColor.allCases
        
        // Search for different place types
        let searchTerms = ["city", "town", "municipality"]
        var seenPlaces = Set<String>()
        
        for term in searchTerms {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = term
            request.region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            request.resultTypes = [.address, .pointOfInterest]
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                for item in response.mapItems {
                    // Try to get a useful name
                    let placeName: String
                    if let name = item.name, !name.isEmpty {
                        placeName = name
                    } else if let locality = item.placemark.locality {
                        placeName = locality
                    } else {
                        continue
                    }
                    
                    // Skip duplicates
                    if seenPlaces.contains(placeName) { continue }
                    seenPlaces.insert(placeName)
                    
                    let coord = item.placemark.coordinate
                    let distance = distanceBetween(center, coord)
                    
                    if distance > 50_000 { continue }
                    
                    // For MapKit results, we need to fetch the boundary separately
                    // or estimate based on the result type
                    if let boundary = await fetchBoundaryForPlace(name: placeName, coordinate: coord) {
                        let territoryCenter = calculateCenter(boundary)
                        let radius = calculateRadius(center: territoryCenter, boundary: boundary)
                        
                        let territory = Territory(center: territoryCenter, radiusMeters: radius, boundary: boundary)
                        let color = colors[kingdoms.count % colors.count]
                        
                        let kingdom = Kingdom(
                            name: placeName,
                            rulerName: generateRandomRulerName(),
                            territory: territory,
                            color: color
                        )
                        
                        kingdoms.append(kingdom)
                        print("🏰 \(placeName) - \(boundary.count) boundary points")
                        
                        if kingdoms.count >= 15 { break }
                    }
                }
                
            } catch {
                print("⚠️ MapKit search error: \(error)")
            }
            
            if kingdoms.count >= 15 { break }
        }
        
        return kingdoms
    }
    
    /// Fetch boundary for a specific place using Nominatim
    private static func fetchBoundaryForPlace(name: String, coordinate: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encodedName)&format=json&polygon_geojson=1&limit=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("KingdomApp/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            
            guard let places = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let place = places.first,
                  let geojson = place["geojson"] as? [String: Any],
                  let geoType = geojson["type"] as? String else { return nil }
            
            var boundary: [CLLocationCoordinate2D] = []
            
            if geoType == "Polygon",
               let coords = geojson["coordinates"] as? [[[Double]]] {
                if let ring = coords.first {
                    boundary = ring.compactMap { coord in
                        guard coord.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                    }
                }
            } else if geoType == "MultiPolygon",
                      let polygons = geojson["coordinates"] as? [[[[Double]]]] {
                var largestRing: [[Double]] = []
                for polygon in polygons {
                    if let ring = polygon.first, ring.count > largestRing.count {
                        largestRing = ring
                    }
                }
                boundary = largestRing.compactMap { coord in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
            }
            
            // Rate limit for Nominatim
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            
            return boundary.count >= 4 ? simplifyPolygon(boundary) : nil
            
        } catch {
            return nil
        }
    }
    
    // MARK: - Helper Functions
    
    static func generateRandomRulerName() -> String {
        let names = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace", "Henry",
                     "Iris", "Jack", "Kate", "Leo", "Maya", "Noah", "Olivia", "Peter",
                     "Quinn", "Rose", "Sam", "Tara", "Uma", "Victor", "Wendy", "Xavier"]
        return names.randomElement() ?? "Unknown"
    }
    
    static func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return loc1.distance(from: loc2)
    }
    
    private static func calculateCenter(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let sum = coords.reduce((lat: 0.0, lon: 0.0)) { result, coord in
            (result.lat + coord.latitude, result.lon + coord.longitude)
        }
        return CLLocationCoordinate2D(
            latitude: sum.lat / Double(coords.count),
            longitude: sum.lon / Double(coords.count)
        )
    }
    
    private static func calculateRadius(center: CLLocationCoordinate2D, boundary: [CLLocationCoordinate2D]) -> Double {
        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let avgDistance = boundary.map { coord in
            CLLocation(latitude: coord.latitude, longitude: coord.longitude).distance(from: centerLoc)
        }.reduce(0, +) / Double(boundary.count)
        return avgDistance
    }
    
    private static func simplifyPolygon(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count > 50 else { return points }
        
        // Simple decimation for now - take every Nth point
        let step = max(1, points.count / 50)
        var simplified: [CLLocationCoordinate2D] = []
        
        for i in stride(from: 0, to: points.count, by: step) {
            simplified.append(points[i])
        }
        
        // Ensure the polygon is closed
        if let first = simplified.first, let last = simplified.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                simplified.append(first)
            }
        }
        
        return simplified
    }
}
