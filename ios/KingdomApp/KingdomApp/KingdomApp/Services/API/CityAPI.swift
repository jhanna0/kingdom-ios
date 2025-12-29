import Foundation
import CoreLocation

/// City boundary API endpoints
class CityAPI {
    private let client = APIClient.shared
    
    /// Fetch city boundaries from backend
    /// Backend handles OSM queries and caching
    func fetchCities(
        lat: Double,
        lon: Double,
        radiusKm: Double = 30.0
    ) async throws -> [CityBoundaryResponse] {
        print("🌐 Fetching cities from API: lat=\(lat), lon=\(lon), radius=\(radiusKm)km")
        
        let request = client.request(
            endpoint: "/cities?lat=\(lat)&lon=\(lon)&radius=\(radiusKm)"
        )
        
        let cities: [CityBoundaryResponse] = try await client.execute(request)
        
        print("✅ Received \(cities.count) cities from API (\(cities.filter { $0.cached }.count) cached)")
        
        return cities
    }
    
    /// Convert city responses to Kingdom objects
    func fetchCitiesAsKingdoms(
        lat: Double,
        lon: Double,
        radiusKm: Double = 30.0
    ) async throws -> [Kingdom] {
        let cityResponses = try await fetchCities(lat: lat, lon: lon, radiusKm: radiusKm)
        
        let colors = KingdomColor.allCases
        let kingdoms: [Kingdom] = cityResponses.enumerated().compactMap { index, city in
            // Convert boundary coordinates
            let boundary = city.boundary.map { coord in
                CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
            }
            
            let center = CLLocationCoordinate2D(latitude: city.center_lat, longitude: city.center_lon)
            
            let territory = Territory(
                center: center,
                radiusMeters: city.radius_meters,
                boundary: boundary,
                osmId: city.osm_id
            )
            
            let color = colors[index % colors.count]
            
            // Use kingdom data from backend if available
            let rulerName = city.kingdom?.ruler_name ?? "Unclaimed"
            let rulerId = city.kingdom?.ruler_id
            
            // Create kingdom with backend data
            guard var kingdom = Kingdom(
                name: city.name,
                rulerName: rulerName,
                rulerId: rulerId,
                territory: territory,
                color: color
            ) else {
                return nil
            }
            
            // Update with backend building levels if kingdom data exists
            if let kingdomData = city.kingdom {
                kingdom.treasuryGold = kingdomData.treasury_gold
                kingdom.wallLevel = kingdomData.wall_level
                kingdom.vaultLevel = kingdomData.vault_level
                kingdom.mineLevel = kingdomData.mine_level
                kingdom.marketLevel = kingdomData.market_level
                kingdom.checkedInPlayers = kingdomData.population
            }
            
            return kingdom
        }
        
        print("✅ Converted to \(kingdoms.count) Kingdom objects")
        return kingdoms
    }
}

