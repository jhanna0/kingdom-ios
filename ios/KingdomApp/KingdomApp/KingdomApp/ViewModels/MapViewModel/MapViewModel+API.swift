import Foundation

// MARK: - API Sync Methods
extension MapViewModel {
    
    /// Sync player data to backend API
    func syncPlayerToAPI() {
        Task {
            do {
                try await apiService.syncPlayer(player)
                print("✅ Player synced to API")
            } catch {
                print("⚠️ Failed to sync player to API: \(error.localizedDescription)")
            }
        }
    }
    
    /// Sync kingdom to backend API
    /// Note: Kingdoms are server-authoritative and updated through specific actions
    /// (check-in, conquest, contracts, etc.) rather than direct state sync
    func syncKingdomToAPI(_ kingdom: Kingdom) {
        // Kingdom state is managed by the server through specific actions:
        // - Check-ins update population and activity
        // - Conquests change rulers
        // - Contracts upgrade buildings
        // - Economy system handles treasury
        // No direct client-to-server kingdom state sync needed
        print("ℹ️ Kingdom state is server-authoritative: \(kingdom.name)")
    }
    
    /// Test API connectivity
    func testAPIConnection() {
        Task {
            let isConnected = await apiService.testConnection()
            if isConnected {
                print("✅ API connection successful")
            } else {
                print("❌ API connection failed")
            }
        }
    }
    
    /// Fetch global action cooldown status
    func fetchGlobalCooldown() async {
        guard apiService.isAuthenticated else { return }
        
        do {
            let status = try await actionsAPI.getActionStatus()
            await MainActor.run {
                self.globalCooldown = status.globalCooldown
                self.slotCooldowns = status.slotCooldowns // Store slot cooldowns for parallel actions
                self.cooldownFetchedAt = Date()
            }
        } catch {
            print("⚠️ Failed to fetch global cooldown: \(error.localizedDescription)")
        }
    }
    
    /// Refresh cooldown immediately (call after performing actions)
    func refreshCooldown() {
        Task {
            await fetchGlobalCooldown()
        }
    }
    
    /// Fetch cooldown once on app load
    func loadInitialCooldown() {
        Task {
            await fetchGlobalCooldown()
        }
    }
}




