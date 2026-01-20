import Foundation
import MapKit
import CoreLocation

// MARK: - Kingdom Loading & Refreshing
extension MapViewModel {
    
    /// Load real town data from backend API - TWO STEP for speed
    /// Step 1: Load current city FAST (< 2s) - unblock UI (with retry)
    /// Step 2: Load neighbors in background
    func loadRealTowns(around location: CLLocationCoordinate2D) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingStatus = "Finding your kingdom..."
        errorMessage = nil
        
        Task {
            // STEP 1: Get current city with retry logic (up to 5 attempts)
            let maxRetries = 5
            var currentCity: CityBoundaryResponse?
            var lastError: Error?
            
            for attempt in 1...maxRetries {
                do {
                    if attempt > 1 {
                        await MainActor.run {
                            loadingStatus = "Finding your kingdom... (attempt \(attempt)/\(maxRetries))"
                        }
                        print("🔄 Retrying current city load (attempt \(attempt)/\(maxRetries))")
                    }
                    
                    currentCity = try await apiService.city.fetchCurrentCity(
                        lat: location.latitude,
                        lon: location.longitude
                    )
                    break // Success! Exit retry loop
                    
                } catch {
                    lastError = error
                    print("❌ Attempt \(attempt) failed: \(error)")
                    
                    // Wait before retrying (except on last attempt)
                    if attempt < maxRetries {
                        print("⏳ Waiting 2 seconds before retry...")
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    }
                }
            }
            
            // Check if we successfully loaded the current city
            guard let city = currentCity else {
                // Failed after all retries
                await MainActor.run {
                    let errorDescription = lastError?.localizedDescription ?? "Unknown error"
                    
                    if errorDescription.contains("No city found") {
                        loadingStatus = ""
                        errorMessage = "No kingdoms discovered at this location. The royal cartographers have not yet mapped this region. Try a major city or move to a different area."
                        print("❌ Failed to load current city after \(maxRetries) attempts: \(errorDescription)")
                    } else if errorDescription.contains("network") || errorDescription.contains("internet") {
                        loadingStatus = "Connection to royal archives lost..."
                        errorMessage = "Cannot reach the kingdom servers. Check your internet connection and try again."
                        print("❌ Network error loading current city after \(maxRetries) attempts: \(errorDescription)")
                    } else {
                        loadingStatus = "The royal cartographers have failed..."
                        errorMessage = "Error loading kingdom after \(maxRetries) attempts: \(errorDescription)"
                        print("❌ Failed to load current city after \(maxRetries) attempts: \(errorDescription)")
                    }
                    
                    isLoading = false
                }
                return
            }
            
            // Convert to Kingdom and show immediately
            let kingdom = convertCityToKingdom(city, index: 0)
            
            await MainActor.run {
                if let kingdom = kingdom {
                    kingdoms = [kingdom]
                    syncPlayerKingdoms()
                    print("✅ Current city loaded: \(kingdom.name)")
                }
                
                // UI IS NOW READY - user can interact
                isLoading = false
                loadingStatus = "Loading nearby kingdoms...\n(New areas take longer to map the first time)"
            }
            
            // SEQUENTIAL: Load player state FIRST (sets hometownKingdomId), 
            // THEN check for coups - fixes race condition
            if let kingdom = kingdom {
                do {
                    let updatedState = try await apiService.loadPlayerState(kingdomId: kingdom.id)
                    
                    await MainActor.run {
                        player.updateFromAPIState(updatedState)
                        latestTravelEvent = updatedState.travel_event
                        
                        // Set currentKingdomInside so checkKingdomLocation doesn't duplicate
                        currentKingdomInside = kingdoms.first { $0.id == kingdom.id }
                        
                        // NOW we can check for coups - hometownKingdomId is set
                        updateActiveCoupFromKingdoms()
                        print("✅ Auto-checked in to \(kingdom.name)")
                    }
                    
                    // Refresh kingdom data
                    await refreshKingdom(id: kingdom.id)
                } catch {
                    print("⚠️ Failed to load player state: \(error.localizedDescription)")
                    // Still try to update coup state with what we have
                    await MainActor.run {
                        updateActiveCoupFromKingdoms()
                    }
                }
            }
            
            // STEP 2: Load neighbors in background with retry (can be slower)
            var neighbors: [CityBoundaryResponse]?
            var lastNeighborError: Error?
            
            for attempt in 1...maxRetries {
                do {
                    if attempt > 1 {
                        await MainActor.run {
                            loadingStatus = "Loading nearby kingdoms... (attempt \(attempt)/\(maxRetries))"
                        }
                        print("🔄 Retrying neighbors load (attempt \(attempt)/\(maxRetries))")
                    }
                    
                    neighbors = try await apiService.city.fetchNeighbors(
                        lat: location.latitude,
                        lon: location.longitude
                    )
                    break // Success! Exit retry loop
                    
                } catch {
                    lastNeighborError = error
                    print("❌ Neighbor attempt \(attempt) failed: \(error)")
                    
                    // Wait before retrying (except on last attempt)
                    if attempt < maxRetries {
                        print("⏳ Waiting 2 seconds before retry...")
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    }
                }
            }
            
            // Process neighbors if we got them
            if let neighbors = neighbors {
                let neighborKingdoms = neighbors.enumerated().compactMap { index, city in
                    convertCityToKingdom(city, index: index + 1)
                }
                
                await MainActor.run {
                    // Add neighbors to kingdoms list, avoiding duplicates
                    let existingIds = Set(kingdoms.map { $0.id })
                    let newKingdoms = neighborKingdoms.filter { !existingIds.contains($0.id) }
                    kingdoms.append(contentsOf: newKingdoms)
                    syncPlayerKingdoms()
                    updateActiveCoupFromKingdoms()
                    
                    let withBoundary = kingdoms.filter { $0.hasBoundaryCached }.count
                    print("✅ Total: \(kingdoms.count) kingdoms (\(withBoundary) with boundaries)")
                    loadingStatus = ""
                }
                
                // Load missing boundaries in background
                await loadMissingBoundaries()
            } else {
                // Failed after all retries - log but continue with just current city
                print("⚠️ Failed to load neighbors after \(maxRetries) attempts: \(lastNeighborError?.localizedDescription ?? "Unknown error")")
                await MainActor.run {
                    loadingStatus = ""
                }
            }
        }
    }
    
    /// Convert CityBoundaryResponse to Kingdom object
    private func convertCityToKingdom(_ city: CityBoundaryResponse, index: Int) -> Kingdom? {
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
        
        let color = colors[index % colors.count]
        let rulerName = city.kingdom?.ruler_name ?? "Unclaimed"
        let rulerId = city.kingdom?.ruler_id
        let canClaim = city.kingdom?.can_claim ?? false
        
        guard var kingdom = Kingdom(
            name: city.name,
            rulerName: rulerName,
            rulerId: rulerId,
            territory: territory,
            color: color,
            canClaim: canClaim
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
            
            // War state - Backend is source of truth!
            kingdom.isAtWar = kingdomData.is_at_war ?? false
            
            // Active battle data (if any)
            kingdom.activeCoup = kingdomData.active_coup
            if let battle = kingdomData.active_coup {
                print("🔥 BATTLE FOUND in \(kingdom.name): id=\(battle.id), status=\(battle.status), type=\(battle.battle_type ?? "coup")")
            }
            
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
                        BuildingTierInfo(
                            tier: tier.tier,
                            name: tier.name,
                            benefit: tier.benefit,
                            tierDescription: tier.description
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
                        tierName: building.tier_name,
                        tierBenefit: building.tier_benefit,
                        allTiers: allTiers
                    )
                }
            }
            
            // Alliance data
            kingdom.isAllied = kingdomData.is_allied
            kingdom.isEnemy = kingdomData.is_enemy
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
                kingdom.activeAlliances = alliancesData.map { alliance in
                    let expiresAt = alliance.expires_at.flatMap { ISO8601DateFormatter().date(from: $0) }
                    return ActiveAlliance(
                        id: alliance.id,
                        alliedKingdomId: alliance.allied_kingdom_id,
                        alliedKingdomName: alliance.allied_kingdom_name,
                        alliedRulerName: alliance.allied_ruler_name,
                        daysRemaining: alliance.days_remaining,
                        expiresAt: expiresAt
                    )
                }
            }
        }
        
        return kingdom
    }
    
    /// Refresh kingdoms - try again with real data
    func refreshKingdoms() {
        if let location = userLocation {
            loadRealTowns(around: location)
        } else {
            errorMessage = "The royal astronomers cannot find you! Grant them permission to track the stars."
        }
    }
    
    /// Refresh kingdom data from backend (force fetch)
    func refreshKingdomData() async {
        guard let location = userLocation else { return }
        
        do {
            let foundKingdoms = try await apiService.fetchCities(
                lat: location.latitude,
                lon: location.longitude,
                radiusKm: loadRadiusMiles * 1.60934
            )
            
            await MainActor.run {
                // Backend is the source of truth - just use it
                kingdoms = foundKingdoms
                
                // Update currentKingdomInside if needed
                if let currentId = currentKingdomInside?.id {
                    currentKingdomInside = kingdoms.first(where: { $0.id == currentId })
                }
                
                print("✅ Refreshed kingdom data from backend")
            }
        } catch {
            print("❌ Failed to refresh kingdoms: \(error)")
        }
    }
    
    /// Refresh a specific kingdom from backend
    func refreshKingdom(id kingdomId: String) async {
        do {
            let apiKingdom = try await apiService.kingdom.getKingdom(id: kingdomId)
            
            await MainActor.run {
                if let index = kingdoms.firstIndex(where: { $0.id == kingdomId }) {
                    kingdoms[index].treasuryGold = apiKingdom.treasury_gold
                    kingdoms[index].taxRate = apiKingdom.tax_rate
                    kingdoms[index].travelFee = apiKingdom.travel_fee
                    kingdoms[index].checkedInPlayers = apiKingdom.checked_in_players
                    kingdoms[index].activeCitizens = apiKingdom.active_citizens ?? 0
                    kingdoms[index].activeContract = nil // Clear completed contract
                    
                    // DYNAMIC BUILDINGS - Iterate buildings array from backend
                    // NO HARDCODING - just loop through whatever buildings the backend sends!
                    if let buildings = apiKingdom.buildings {
                        for building in buildings {
                            // Store level
                            kingdoms[index].buildingLevels[building.type] = building.level
                            
                            // Convert and store upgrade cost
                            let upgradeCost: BuildingUpgradeCost? = building.upgrade_cost.map {
                                BuildingUpgradeCost(
                                    actionsRequired: $0.actions_required,
                                    constructionCost: $0.construction_cost,
                                    canAfford: $0.can_afford
                                )
                            }
                            kingdoms[index].buildingUpgradeCosts[building.type] = upgradeCost
                            
                            // Convert all tiers info
                            let allTiers = building.all_tiers.map { tier in
                                BuildingTierInfo(
                                    tier: tier.tier,
                                    name: tier.name,
                                    benefit: tier.benefit,
                                    tierDescription: tier.description
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
                            
                            // Store full metadata
                            kingdoms[index].buildingMetadata[building.type] = BuildingMetadata(
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
                                tierName: building.tier_name,
                                tierBenefit: building.tier_benefit,
                                allTiers: allTiers
                            )
                        }
                    }
                    
                    // Update currentKingdomInside if it's the same kingdom
                    if currentKingdomInside?.id == kingdomId {
                        currentKingdomInside = kingdoms[index]
                    }
                    
                    // Log first building for debugging
                    let firstBuilding = apiKingdom.buildings?.first
                    print("✅ Refreshed kingdom \(apiKingdom.name) - \(apiKingdom.buildings?.count ?? 0) buildings loaded")
                    if let b = firstBuilding {
                        print("   First building: \(b.display_name) Lv.\(b.level)")
                    }
                }
            }
        } catch {
            print("❌ Failed to refresh kingdom: \(error)")
        }
    }
    
    /// Refresh player data from backend
    func refreshPlayerFromBackend() async {
        do {
            let apiPlayerState = try await apiService.loadPlayerState()
            
            await MainActor.run {
                // Use the full sync method to update ALL player fields
                player.updateFromAPIState(apiPlayerState)
                print("✅ Refreshed player state - Gold: \(apiPlayerState.gold)")
            }
        } catch {
            print("❌ Failed to refresh player state: \(error)")
        }
    }
    
    /// Lazy-load boundary for a kingdom that doesn't have one cached
    /// Called when user taps on a neighbor kingdom marker
    func loadKingdomBoundary(kingdomId: String) async {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdomId }) else {
            print("⚠️ Kingdom \(kingdomId) not found")
            return
        }
        
        // Skip if already has boundary
        guard !kingdoms[index].hasBoundaryCached else {
            print("✅ Kingdom \(kingdomId) already has boundary")
            return
        }
        
        do {
            print("🌐 Lazy-loading boundary for \(kingdoms[index].name)...")
            let boundaryResponse = try await apiService.city.fetchBoundary(osmId: kingdomId)
            
            // Convert to CLLocationCoordinate2D array
            let boundary = boundaryResponse.boundary.map { coord in
                CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
            }
            
            await MainActor.run {
                // Update the kingdom with the new boundary
                kingdoms[index].updateBoundary(boundary, radiusMeters: boundaryResponse.radius_meters)
                
                // Update currentKingdomInside if it's the same kingdom
                if currentKingdomInside?.id == kingdomId {
                    currentKingdomInside = kingdoms[index]
                }
                
                print("✅ Loaded boundary for \(kingdoms[index].name) (\(boundary.count) points)")
            }
        } catch {
            print("❌ Failed to load boundary for \(kingdomId): \(error)")
        }
    }
    
    /// Lazy-load all missing boundaries in background (PARALLEL)
    /// Call this after initial load to fill in neighbor polygons
    /// Retries up to 5 times for new areas that take time to map
    func loadMissingBoundaries() async {
        let missing = kingdoms.filter { !$0.hasBoundaryCached }
        var missingIds = missing.map { $0.id }
        
        if missingIds.isEmpty {
            print("✅ All boundaries already loaded")
            return
        }
        
        // Update loading status for new areas
        await MainActor.run {
            loadingStatus = "Mapping new areas... (this may take a moment)"
        }
        
        print("🌐 Batch loading \(missingIds.count) missing boundaries in parallel...")
        
        let maxRetries = 5
        var attempt = 0
        
        // Retry loop - keep trying until all boundaries are loaded or max retries reached
        while !missingIds.isEmpty && attempt < maxRetries {
            attempt += 1
            print("📍 Attempt \(attempt)/\(maxRetries) - \(missingIds.count) boundaries remaining")
            
            await MainActor.run {
                if attempt > 1 {
                    loadingStatus = "Mapping new areas... (attempt \(attempt)/\(maxRetries))"
                }
            }
            
            do {
                // Fetch all remaining boundaries in parallel with one request
                let boundaryResponses = try await apiService.city.fetchBoundariesBatch(osmIds: missingIds)
                
                var successfullyLoaded: [String] = []
                
                await MainActor.run {
                    // Update each kingdom with its boundary
                    for boundaryResponse in boundaryResponses {
                        guard let index = kingdoms.firstIndex(where: { $0.id == boundaryResponse.osm_id }) else {
                            continue
                        }
                        
                        // Skip if no boundary returned (failed fetch)
                        if boundaryResponse.boundary.isEmpty {
                            print("⚠️ No boundary for \(kingdoms[index].name)")
                            continue
                        }
                        
                        // Convert to CLLocationCoordinate2D array
                        let boundary = boundaryResponse.boundary.map { coord in
                            CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
                        }
                        
                        // Update the kingdom
                        kingdoms[index].updateBoundary(boundary, radiusMeters: boundaryResponse.radius_meters)
                        
                        print("✅ Loaded boundary for \(kingdoms[index].name) (\(boundary.count) points)")
                        successfullyLoaded.append(boundaryResponse.osm_id)
                        
                        // Update currentKingdomInside if it's the same kingdom
                        if currentKingdomInside?.id == kingdoms[index].id {
                            currentKingdomInside = kingdoms[index]
                        }
                    }
                    
                    let loaded = boundaryResponses.filter { !$0.boundary.isEmpty }.count
                    print("✅ Batch attempt \(attempt): \(loaded)/\(missingIds.count) boundaries loaded")
                }
                
                // Remove successfully loaded IDs from missing list
                missingIds = missingIds.filter { !successfullyLoaded.contains($0) }
                
                // If we still have missing boundaries, wait a bit before retrying
                if !missingIds.isEmpty && attempt < maxRetries {
                    print("⏳ Waiting 2 seconds before retry...")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
                
            } catch {
                print("❌ Batch attempt \(attempt) failed: \(error)")
                
                // Wait before retrying on error
                if attempt < maxRetries {
                    print("⏳ Waiting 3 seconds before retry...")
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                }
            }
        }
        
        await MainActor.run {
            loadingStatus = ""
            
            // Check if we successfully loaded everything
            if missingIds.isEmpty {
                print("🎉 All boundaries successfully loaded after \(attempt) attempt(s)")
            } else {
                // Only show error if we failed after all retries
                print("⚠️ Failed to load \(missingIds.count) boundaries after \(maxRetries) attempts")
                errorMessage = "Failed to map some areas after \(maxRetries) attempts. The royal cartographers need more time."
            }
        }
    }
}


