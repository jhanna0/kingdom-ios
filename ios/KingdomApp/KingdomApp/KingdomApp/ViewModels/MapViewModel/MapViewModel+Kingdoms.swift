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
                    
                    // Check location
                    if let currentLocation = userLocation {
                        checkKingdomLocation(currentLocation)
                    }
                    
                    print("✅ Current city loaded: \(kingdom.name)")
                }
                
                // UI IS NOW READY - user can interact
                isLoading = false
                loadingStatus = "Loading nearby kingdoms...\n(New areas take longer to map the first time)"
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
            kingdom.wallLevel = kingdomData.wall_level
            kingdom.vaultLevel = kingdomData.vault_level
            kingdom.mineLevel = kingdomData.mine_level
            kingdom.marketLevel = kingdomData.market_level
            kingdom.farmLevel = kingdomData.farm_level
            kingdom.educationLevel = kingdomData.education_level
            kingdom.travelFee = kingdomData.travel_fee
            kingdom.checkedInPlayers = kingdomData.population
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
                kingdoms[index].wallLevel = apiKingdom.wall_level
                kingdoms[index].vaultLevel = apiKingdom.vault_level
                kingdoms[index].mineLevel = apiKingdom.mine_level
                kingdoms[index].marketLevel = apiKingdom.market_level
                kingdoms[index].farmLevel = apiKingdom.farm_level
                kingdoms[index].educationLevel = apiKingdom.education_level
                kingdoms[index].taxRate = apiKingdom.tax_rate
                kingdoms[index].travelFee = apiKingdom.travel_fee
                kingdoms[index].checkedInPlayers = apiKingdom.population
                kingdoms[index].activeContract = nil // Clear completed contract
                    
                    // Update building upgrade costs
                    kingdoms[index].wallUpgradeCost = apiKingdom.wall_upgrade_cost.map {
                        BuildingUpgradeCost(actionsRequired: $0.actions_required, constructionCost: $0.construction_cost, canAfford: $0.can_afford)
                    }
                    kingdoms[index].vaultUpgradeCost = apiKingdom.vault_upgrade_cost.map {
                        BuildingUpgradeCost(actionsRequired: $0.actions_required, constructionCost: $0.construction_cost, canAfford: $0.can_afford)
                    }
                    kingdoms[index].mineUpgradeCost = apiKingdom.mine_upgrade_cost.map {
                        BuildingUpgradeCost(actionsRequired: $0.actions_required, constructionCost: $0.construction_cost, canAfford: $0.can_afford)
                    }
                    kingdoms[index].marketUpgradeCost = apiKingdom.market_upgrade_cost.map {
                        BuildingUpgradeCost(actionsRequired: $0.actions_required, constructionCost: $0.construction_cost, canAfford: $0.can_afford)
                    }
                    kingdoms[index].farmUpgradeCost = apiKingdom.farm_upgrade_cost.map {
                        BuildingUpgradeCost(actionsRequired: $0.actions_required, constructionCost: $0.construction_cost, canAfford: $0.can_afford)
                    }
                    kingdoms[index].educationUpgradeCost = apiKingdom.education_upgrade_cost.map {
                        BuildingUpgradeCost(actionsRequired: $0.actions_required, constructionCost: $0.construction_cost, canAfford: $0.can_afford)
                    }
                    
                    // Update currentKingdomInside if it's the same kingdom
                    if currentKingdomInside?.id == kingdomId {
                        currentKingdomInside = kingdoms[index]
                    }
                    
                    print("✅ Refreshed kingdom \(apiKingdom.name) - Market Lv.\(apiKingdom.market_level)")
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


