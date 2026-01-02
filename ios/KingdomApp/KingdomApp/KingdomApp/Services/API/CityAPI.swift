import Foundation
import CoreLocation

/// City boundary API endpoints
class CityAPI {
    private let client = APIClient.shared
    
    // MARK: - FAST Loading (Two-Step)
    
    /// Step 1: Get ONLY the city the user is in (< 2 seconds)
    /// Call this FIRST to unblock the UI immediately
    func fetchCurrentCity(lat: Double, lon: Double) async throws -> CityBoundaryResponse {
        let request = client.request(
            endpoint: "/cities/current?lat=\(lat)&lon=\(lon)"
        )
        let city: CityBoundaryResponse = try await client.execute(request)
        print("✅ Current city: \(city.name)")
        return city
    }
    
    /// Step 2: Get neighbor cities (call AFTER UI is showing current city)
    /// Returns cities that DIRECTLY border the current city (shared boundaries)
    func fetchNeighbors(lat: Double, lon: Double) async throws -> [CityBoundaryResponse] {
        let request = client.request(
            endpoint: "/cities/neighbors?lat=\(lat)&lon=\(lon)"
        )
        let cities: [CityBoundaryResponse] = try await client.execute(request)
        print("✅ Loaded \(cities.count) neighbors")
        return cities
    }
    
    /// Lazy-load boundary polygon for a single city
    func fetchBoundary(osmId: String) async throws -> BoundaryResponse {
        let request = client.request(
            endpoint: "/cities/\(osmId)/boundary"
        )
        return try await client.execute(request)
    }
    
    /// Batch fetch boundaries for multiple cities in parallel
    /// Much faster than calling fetchBoundary() multiple times
    func fetchBoundariesBatch(osmIds: [String]) async throws -> [BoundaryResponse] {
        let request = try client.request(
            endpoint: "/cities/boundaries/batch",
            method: "POST",
            body: osmIds
        )
        return try await client.execute(request)
    }
    
    // MARK: - Legacy (loads everything at once)
    
    /// Legacy: Fetch all cities at once (slower)
    func fetchCities(
        lat: Double,
        lon: Double,
        radiusKm: Double = 30.0
    ) async throws -> [CityBoundaryResponse] {
        let request = client.request(
            endpoint: "/cities?lat=\(lat)&lon=\(lon)&radius=\(radiusKm)"
        )
        let cities: [CityBoundaryResponse] = try await client.execute(request)
        print("✅ Received \(cities.count) cities (legacy)")
        return cities
    }
    
    // MARK: - Conversion Helper
    
    /// Convert a single CityBoundaryResponse to Kingdom
    func convertToKingdom(_ city: CityBoundaryResponse, colorIndex: Int) -> Kingdom? {
        let colors = KingdomColor.allCases
        
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
        
        let color = colors[colorIndex % colors.count]
        let rulerName = city.kingdom?.ruler_name ?? "Unclaimed"
        let rulerId = city.kingdom?.ruler_id
        let canClaim = city.kingdom?.can_claim ?? false
        let canDeclareWar = city.kingdom?.can_declare_war ?? false
        let canFormAlliance = city.kingdom?.can_form_alliance ?? false
        
        guard var kingdom = Kingdom(
            name: city.name,
            rulerName: rulerName,
            rulerId: rulerId,
            territory: territory,
            color: color,
            canClaim: canClaim,
            canDeclareWar: canDeclareWar,
            canFormAlliance: canFormAlliance
        ) else {
            return nil
        }
        
        kingdom.isCurrentCity = city.is_current
        kingdom.hasBoundaryCached = !city.boundary.isEmpty
        
        if let kingdomData = city.kingdom {
            kingdom.treasuryGold = kingdomData.treasury_gold
            kingdom.wallLevel = kingdomData.wall_level
            kingdom.vaultLevel = kingdomData.vault_level
            kingdom.mineLevel = kingdomData.mine_level
            kingdom.marketLevel = kingdomData.market_level
            kingdom.farmLevel = kingdomData.farm_level
            kingdom.educationLevel = kingdomData.education_level
            kingdom.travelFee = kingdomData.travel_fee
            kingdom.checkedInPlayers = kingdomData.population
            kingdom.isAllied = kingdomData.is_allied
            kingdom.isEnemy = kingdomData.is_enemy
        }
        
        return kingdom
    }
    
    /// Legacy: Convert city responses to Kingdom objects
    func fetchCitiesAsKingdoms(
        lat: Double,
        lon: Double,
        radiusKm: Double = 30.0
    ) async throws -> [Kingdom] {
        let cityResponses = try await fetchCities(lat: lat, lon: lon, radiusKm: radiusKm)
        
        let kingdoms: [Kingdom] = cityResponses.enumerated().compactMap { index, city in
            convertToKingdom(city, colorIndex: index)
        }
        
        print("✅ Converted to \(kingdoms.count) Kingdom objects")
        return kingdoms
    }
}

