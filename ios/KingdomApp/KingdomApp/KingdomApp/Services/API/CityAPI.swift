import Foundation
import CoreLocation

/// City boundary API endpoints
class CityAPI {
    private let client = APIClient.shared
    
    // MARK: - FAST Startup (Single Call)
    
    /// FASTEST: Single call for app initialization
    /// Combines: /cities/current + /player/state + last_login update
    /// Use this on app launch to minimize round trips
    func fetchStartup(lat: Double, lon: Double) async throws -> StartupResponse {
        let request = client.request(
            endpoint: "/startup?lat=\(lat)&lon=\(lon)"
        )
        let response: StartupResponse = try await client.execute(request)
        print("✅ Startup: \(response.city.name) + player state loaded")
        return response
    }
    
    // MARK: - FAST Loading (Two-Step) [DEPRECATED - use fetchStartup instead]
    
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
        let canStageCoup = city.kingdom?.can_stage_coup ?? false
        let coupIneligibilityReason = city.kingdom?.coup_ineligibility_reason
        
        guard var kingdom = Kingdom(
            name: city.name,
            rulerName: rulerName,
            rulerId: rulerId,
            territory: territory,
            color: color,
            canClaim: canClaim,
            canDeclareWar: canDeclareWar,
            canFormAlliance: canFormAlliance,
            canStageCoup: canStageCoup,
            coupIneligibilityReason: coupIneligibilityReason
        ) else {
            return nil
        }
        
        kingdom.isCurrentCity = city.is_current
        kingdom.hasBoundaryCached = !city.boundary.isEmpty
        
        if let kingdomData = city.kingdom {
            kingdom.treasuryGold = kingdomData.treasury_gold
            kingdom.travelFee = kingdomData.travel_fee
            kingdom.checkedInPlayers = kingdomData.population
            kingdom.activeCitizens = kingdomData.active_citizens ?? 0
            kingdom.isAllied = kingdomData.is_allied
            kingdom.isEnemy = kingdomData.is_enemy
            kingdom.isEmpire = kingdomData.is_empire ?? false
            
            // Parse allies and enemies arrays into Sets
            kingdom.allies = Set(kingdomData.allies ?? [])
            kingdom.enemies = Set(kingdomData.enemies ?? [])
            
            // Alliance info if allied
            if let allianceData = kingdomData.alliance_info {
                let expiresAt = allianceData.expires_at.flatMap { ISO8601DateFormatter().date(from: $0) }
                kingdom.allianceInfo = KingdomAllianceInfo(
                    id: allianceData.id,
                    daysRemaining: allianceData.days_remaining,
                    expiresAt: expiresAt
                )
            }
            
            // Active alliances (only for player's hometown)
            if let alliancesData = kingdomData.active_alliances {
                print("🤝 iOS: Parsing \(alliancesData.count) active alliances for \(city.name)")
                kingdom.activeAlliances = alliancesData.map { alliance in
                    let expiresAt = alliance.expires_at.flatMap { ISO8601DateFormatter().date(from: $0) }
                    print("🤝 iOS: Alliance with \(alliance.allied_kingdom_name)")
                    return ActiveAlliance(
                        id: alliance.id,
                        alliedKingdomId: alliance.allied_kingdom_id,
                        alliedKingdomName: alliance.allied_kingdom_name,
                        alliedRulerName: alliance.allied_ruler_name,
                        daysRemaining: alliance.days_remaining,
                        expiresAt: expiresAt
                    )
                }
                print("🤝 iOS: Kingdom \(city.name) now has \(kingdom.activeAlliances.count) alliances")
            } else {
                print("🤝 iOS: No active_alliances in response for \(city.name)")
            }
            
            // War state - Backend is source of truth!
            kingdom.isAtWar = kingdomData.is_at_war ?? false
            
            // Active battle data (if any)
            kingdom.activeCoup = kingdomData.active_coup
            
            // DYNAMIC BUILDINGS - Iterate buildings array from backend
            // NO HARDCODING - just loop through whatever buildings the backend sends!
            if let buildings = kingdomData.buildings {
                for building in buildings {
                    // Store level in dynamic dict
                    kingdom.buildingLevels[building.type] = building.level
                    
                    // Convert upgrade cost if present
                    let upgradeCost: BuildingUpgradeCost? = building.upgrade_cost.map {
                        BuildingUpgradeCost(
                            actionsRequired: $0.actions_required,
                            constructionCost: $0.construction_cost,
                            canAfford: $0.can_afford
                        )
                    }
                    kingdom.buildingUpgradeCosts[building.type] = upgradeCost
                    
                    // Convert all tiers info
                    let allTiers = building.all_tiers.map { tier in
                        let perActionCosts = (tier.per_action_costs ?? []).map { cost in
                            BuildingPerActionCost(resource: cost.resource, amount: cost.amount)
                        }
                        return BuildingTierInfo(
                            tier: tier.tier,
                            name: tier.name,
                            benefit: tier.benefit,
                            tierDescription: tier.description,
                            perActionCosts: perActionCosts
                        )
                    }
                    
                    // Convert click action if present
                    let clickAction: BuildingClickAction? = building.click_action.map {
                        BuildingClickAction(type: $0.type, resource: $0.resource, exhausted: $0.exhausted ?? false, exhaustedMessage: $0.exhausted_message)
                    }
                    
                    // Convert catchup info if present
                    let catchupInfo: BuildingCatchupInfo? = building.catchup.map {
                        BuildingCatchupInfo(
                            needsCatchup: $0.needs_catchup,
                            canUse: $0.can_use,
                            actionsRequired: $0.actions_required,
                            actionsCompleted: $0.actions_completed,
                            actionsRemaining: $0.actions_remaining
                        )
                    }
                    
                    // Convert permit info if present
                    let permitInfo: BuildingPermitInfo? = building.permit.map {
                        // Parse ISO date string to Date
                        var expiresAt: Date? = nil
                        if let expiresStr = $0.permit_expires_at {
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime]
                            expiresAt = formatter.date(from: expiresStr)
                        }
                        
                        return BuildingPermitInfo(
                            canAccess: $0.can_access,
                            reason: $0.reason,
                            isHometown: $0.is_hometown,
                            isAllied: $0.is_allied,
                            needsPermit: $0.needs_permit,
                            hasValidPermit: $0.has_valid_permit,
                            permitExpiresAt: expiresAt,
                            permitMinutesRemaining: $0.permit_minutes_remaining,
                            hometownHasBuilding: $0.hometown_has_building,
                            hometownBuildingLevel: $0.hometown_building_level,
                            hasActiveCatchup: $0.has_active_catchup,
                            canBuyPermit: $0.can_buy_permit,
                            permitCost: $0.permit_cost,
                            permitDurationMinutes: $0.permit_duration_minutes
                        )
                    }
                    
                    // Store full metadata
                    kingdom.buildingMetadata[building.type] = BuildingMetadata(
                        type: building.type,
                        displayName: building.display_name,
                        icon: building.icon,
                        colorHex: building.color,
                        category: building.category,
                        description: building.description,
                        level: building.level,
                        maxLevel: building.max_level,
                        sortOrder: building.sort_order ?? 100,
                        upgradeCost: upgradeCost,
                        clickAction: clickAction,
                        catchup: catchupInfo,
                        permit: permitInfo,
                        tierName: building.tier_name,
                        tierBenefit: building.tier_benefit,
                        allTiers: allTiers
                    )
                }
            }
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

