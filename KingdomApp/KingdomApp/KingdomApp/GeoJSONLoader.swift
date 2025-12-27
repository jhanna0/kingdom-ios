import Foundation
import MapKit

class GeoJSONLoader {
    
    /// Load municipalities/towns from GeoJSON URL (ADM2 level from geoBoundaries)
    static func loadMunicipalitiesFromURL(urlString: String) async -> [Kingdom] {
        print("🌐 Fetching GeoJSON from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }
            
            print("📦 Downloaded \(data.count) bytes")
            
            let decoder = MKGeoJSONDecoder()
            let geoJSONObjects = try decoder.decode(data)
            
            print("✅ Decoded \(geoJSONObjects.count) GeoJSON objects")
            
            return parseGeoJSON(geoJSONObjects)
        } catch {
            print("❌ Error loading GeoJSON: \(error)")
            return []
        }
    }
    
    /// Load municipalities/towns from GeoJSON file (if bundled in app)
    static func loadMunicipalitiesFromBundle(filename: String) async -> [Kingdom] {
        print("📂 Loading GeoJSON from bundle: \(filename)")
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: "geojson") else {
            print("❌ GeoJSON file not found in bundle: \(filename).geojson")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = MKGeoJSONDecoder()
            let geoJSONObjects = try decoder.decode(data)
            
            print("✅ Decoded \(geoJSONObjects.count) GeoJSON objects")
            
            return parseGeoJSON(geoJSONObjects)
        } catch {
            print("❌ Error loading GeoJSON: \(error)")
            return []
        }
    }
    
    private static func parseGeoJSON(_ objects: [MKGeoJSONObject]) -> [Kingdom] {
        var kingdoms: [Kingdom] = []
        let colors = KingdomColor.allCases
        
        for object in objects {
            if let feature = object as? MKGeoJSONFeature {
                for geometry in feature.geometry {
                    // Handle different geometry types
                    if let polygon = geometry as? MKPolygon {
                        if let kingdom = createKingdom(from: polygon, feature: feature, color: colors[kingdoms.count % colors.count]) {
                            kingdoms.append(kingdom)
                            print("🏰 Created kingdom: \(kingdom.name)")
                        }
                    } else if let multiPolygon = geometry as? MKMultiPolygon {
                        // Use the largest polygon from multipolygon
                        if let largestPolygon = findLargestPolygon(in: multiPolygon),
                           let kingdom = createKingdom(from: largestPolygon, feature: feature, color: colors[kingdoms.count % colors.count]) {
                            kingdoms.append(kingdom)
                            print("🏰 Created kingdom: \(kingdom.name)")
                        }
                    }
                }
            }
        }
        
        print("📊 Total kingdoms created: \(kingdoms.count)")
        return kingdoms
    }
    
    private static func createKingdom(from polygon: MKPolygon, feature: MKGeoJSONFeature, color: KingdomColor) -> Kingdom? {
        // Extract town/city name from GeoJSON properties
        let name = extractName(from: feature.properties) ?? "Unknown"
        
        // Convert MKPolygon to our Territory format
        let coordinates = extractCoordinates(from: polygon)
        guard !coordinates.isEmpty else { return nil }
        
        // Calculate center point
        let center = calculateCenter(of: coordinates)
        
        // Calculate approximate radius
        let radius = calculateRadius(center: center, boundary: coordinates)
        
        let territory = Territory(center: center, radiusMeters: radius, boundary: coordinates)
        
        return Kingdom(
            name: name,
            rulerName: SampleData.generateRandomRulerName(),
            territory: territory,
            color: color
        )
    }
    
    private static func extractName(from properties: Data?) -> String? {
        guard let properties = properties else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: properties) as? [String: Any] {
                // Try common property names for municipality/city names
                // geoBoundaries uses "shapeName" for ADM2 (municipalities)
                return json["shapeName"] as? String
                    ?? json["name"] as? String
                    ?? json["NAME"] as? String
                    ?? json["city"] as? String
            }
        } catch {
            print("⚠️ Error parsing properties: \(error)")
        }
        
        return nil
    }
    
    private static func extractCoordinates(from polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let points = polygon.points()
        
        for i in 0..<polygon.pointCount {
            let point = points[i]
            coordinates.append(point.coordinate)
        }
        
        return coordinates
    }
    
    private static func calculateCenter(of coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        let sum = coordinates.reduce((lat: 0.0, lon: 0.0)) { result, coord in
            (result.lat + coord.latitude, result.lon + coord.longitude)
        }
        
        return CLLocationCoordinate2D(
            latitude: sum.lat / Double(coordinates.count),
            longitude: sum.lon / Double(coordinates.count)
        )
    }
    
    private static func calculateRadius(center: CLLocationCoordinate2D, boundary: [CLLocationCoordinate2D]) -> Double {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        let maxDistance = boundary.map { coord in
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return centerLocation.distance(from: location)
        }.max() ?? 5000
        
        return maxDistance
    }
    
    private static func findLargestPolygon(in multiPolygon: MKMultiPolygon) -> MKPolygon? {
        var largestPolygon: MKPolygon?
        var largestArea = 0.0
        
        for polygon in multiPolygon.polygons {
            let area = polygon.boundingMapRect.size.width * polygon.boundingMapRect.size.height
            if area > largestArea {
                largestArea = area
                largestPolygon = polygon
            }
        }
        
        return largestPolygon
    }
}

