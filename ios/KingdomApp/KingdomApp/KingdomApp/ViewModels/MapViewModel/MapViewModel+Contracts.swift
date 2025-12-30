import Foundation

// MARK: - Contract System
extension MapViewModel {
    
    /// Create a new contract for building upgrade
    func createContract(kingdom: Kingdom, buildingType: BuildingType, rewardPool: Int) async throws -> Bool {
        guard let index = kingdoms.firstIndex(where: { $0.id == kingdom.id }) else {
            print("❌ Kingdom not found")
            throw NSError(domain: "MapViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kingdom not found"])
        }
        
        // Check if ruler owns this kingdom
        guard kingdoms[index].rulerId == player.playerId else {
            print("❌ You don't rule this kingdom")
            throw NSError(domain: "MapViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "You don't rule this kingdom"])
        }
        
        // Get building type string and next level
        let (buildingTypeStr, currentLevel) = getBuildingInfo(kingdom: kingdoms[index], buildingType: buildingType)
        
        // Check if building can be upgraded
        if currentLevel >= 5 {
            print("❌ Building already at max level")
            throw NSError(domain: "MapViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Building already at max level"])
        }
        
        let nextLevel = currentLevel + 1
        
        // Call API to create contract
        do {
            let apiContract = try await contractAPI.createContract(
                kingdomId: kingdom.id,
                kingdomName: kingdom.name,
                buildingType: buildingTypeStr,
                buildingLevel: nextLevel,
                rewardPool: rewardPool,
                basePopulation: kingdoms[index].checkedInPlayers
            )
            
            print("✅ Contract created via API: \(apiContract.id)")
            
            // Reload contracts to show the new one
            await loadContracts()
            
            return true
        } catch {
            print("❌ Failed to create contract: \(error)")
            throw error
        }
    }
    
    /// Get all available contracts (from API)
    func getAvailableContracts() -> [Contract] {
        // TODO: Fetch from API
        // For now return empty - we'll load async
        return []
    }
    
    /// Fetch contracts from API
    func loadContracts() async {
        do {
            print("🔄 Loading contracts from API...")
            // Load both open AND in_progress contracts so users can see their active work
            let openContracts = try await contractAPI.listContracts(kingdomId: nil, status: "open")
            print("   📋 Open contracts: \(openContracts.count)")
            let inProgressContracts = try await contractAPI.listContracts(kingdomId: nil, status: "in_progress")
            print("   📋 In-progress contracts: \(inProgressContracts.count)")
            let allContracts = openContracts + inProgressContracts
            
            await MainActor.run {
                // Convert APIContract to local Contract model
                self.availableContracts = allContracts.compactMap { apiContract in
                    Contract(
                        id: apiContract.id,
                        kingdomId: apiContract.kingdom_id,
                        kingdomName: apiContract.kingdom_name,
                        buildingType: apiContract.building_type,
                        buildingLevel: apiContract.building_level,
                        basePopulation: apiContract.base_population,
                        baseHoursRequired: apiContract.base_hours_required,
                        workStartedAt: apiContract.work_started_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        totalActionsRequired: apiContract.total_actions_required,
                        actionsCompleted: apiContract.actions_completed,
                        actionContributions: apiContract.action_contributions,
                        rewardPool: apiContract.reward_pool,
                        createdBy: apiContract.created_by,
                        createdAt: ISO8601DateFormatter().date(from: apiContract.created_at) ?? Date(),
                        completedAt: apiContract.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        status: Contract.ContractStatus(rawValue: apiContract.status) ?? .open
                    )
                }
                print("✅ Loaded \(self.availableContracts.count) contracts from API (open: \(openContracts.count), in_progress: \(inProgressContracts.count))")
            }
        } catch {
            print("❌ Failed to load contracts: \(error)")
        }
    }
    
    // Helper to get building info
    func getBuildingInfo(kingdom: Kingdom, buildingType: BuildingType) -> (String, Int) {
        switch buildingType {
        case .walls:
            return ("Walls", kingdom.wallLevel)
        case .vault:
            return ("Vault", kingdom.vaultLevel)
        case .mine:
            return ("Mine", kingdom.mineLevel)
        case .market:
            return ("Market", kingdom.marketLevel)
        case .farm:
            return ("Farm", kingdom.farmLevel)
        case .education:
            return ("Education", kingdom.educationLevel)
        }
    }
}


