import Foundation

// MARK: - Garden API
// Personal garden - plant seeds, water, harvest
// Unlocked at Property Tier 1

class GardenAPI {
    private let client = APIClient.shared
    
    // MARK: - Get Garden Status
    
    /// Get garden status - slots, seeds owned, what can be done
    func getStatus() async throws -> GardenStatusResponse {
        let request = client.request(endpoint: "/garden/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Plant Seed
    
    /// Plant a seed in a garden slot
    func plantSeed(slotIndex: Int) async throws -> PlantSeedResponse {
        let request = client.request(endpoint: "/garden/plant/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Water Plant
    
    /// Water a growing plant
    func waterPlant(slotIndex: Int) async throws -> WaterPlantResponse {
        let request = client.request(endpoint: "/garden/water/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Harvest Plant
    
    /// Harvest wheat from a ready plant
    func harvestPlant(slotIndex: Int) async throws -> HarvestPlantResponse {
        let request = client.request(endpoint: "/garden/harvest/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Discard Plant
    
    /// Discard dead plant, weeds, or flowers
    func discardPlant(slotIndex: Int) async throws -> DiscardPlantResponse {
        let request = client.request(endpoint: "/garden/discard/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
}
