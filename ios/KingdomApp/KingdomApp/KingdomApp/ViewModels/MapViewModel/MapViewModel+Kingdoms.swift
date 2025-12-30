import Foundation
import MapKit
import CoreLocation

// MARK: - Kingdom Loading & Refreshing
extension MapViewModel {
    
    /// Load real town data from backend API
    /// Backend handles caching and ensures all clients get consistent city boundaries
    func loadRealTowns(around location: CLLocationCoordinate2D) {
        guard !isLoading else { return }
        
        isLoading = true
        loadingStatus = "Consulting the kingdom cartographers..."
        errorMessage = nil
        
        Task {
            // Fetch directly from backend API (no local cache)
            do {
                // Fetch cities from backend API (which handles OSM fetching and DB caching)
                let foundKingdoms = try await apiService.fetchCities(
                    lat: location.latitude,
                    lon: location.longitude,
                    radiusKm: loadRadiusMiles * 1.60934  // Convert miles to km
                )
                
                if foundKingdoms.isEmpty {
                    loadingStatus = "The realm lies shrouded in fog..."
                    errorMessage = "No cities found in this area."
                    print("❌ No towns found from API")
                    isLoading = false
                } else {
                    // Backend is the source of truth - just use it directly
                    kingdoms = foundKingdoms
                    
                    // Sync player's fiefsRuled with kingdoms they rule
                    syncPlayerKingdoms()
                    
                    print("✅ Loaded \(foundKingdoms.count) towns from backend API")
                    
                    // Re-check location now that kingdoms are loaded
                    if let currentLocation = userLocation {
                        checkKingdomLocation(currentLocation)
                    }
                    
                    // Done loading
                    isLoading = false
                }
            } catch {
                loadingStatus = "The royal cartographers have failed..."
                errorMessage = "API Error: \(error.localizedDescription)"
                print("❌ Failed to fetch cities from API: \(error.localizedDescription)")
                isLoading = false
            }
        }
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
}


