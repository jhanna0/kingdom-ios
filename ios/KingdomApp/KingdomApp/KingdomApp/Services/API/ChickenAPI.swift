import Foundation

// MARK: - Chicken Coop API
// Hatch rare eggs, raise chickens, collect eggs
// Unlocked at Property Tier 4 (Beautiful Maison)

class ChickenAPI {
    private let client = APIClient.shared
    
    // MARK: - Get Coop Status
    
    /// Get chicken coop status - slots, happiness, eggs available
    func getStatus() async throws -> ChickenStatusResponse {
        let request = client.request(endpoint: "/chicken/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Hatch Egg
    
    /// Hatch a rare egg in a slot (consumes rare_egg, starts incubation)
    func hatchEgg(slotIndex: Int) async throws -> HatchEggResponse {
        let request = client.request(endpoint: "/chicken/hatch/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Name Chicken
    
    /// Name a hatched chicken (one-time only)
    func nameChicken(slotIndex: Int, name: String) async throws -> NameChickenResponse {
        let body = ["name": name]
        let request = try client.request(endpoint: "/chicken/name/\(slotIndex)", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Tamagotchi Actions (Feed, Play, Clean)
    
    /// Perform an action on a chicken (feed, play, clean)
    func performAction(slotIndex: Int, action: String) async throws -> ChickenActionResponse {
        let body = ["action": action]
        let request = try client.request(endpoint: "/chicken/action/\(slotIndex)", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Collect Eggs
    
    /// Collect eggs from a chicken (95% meat, 5% rare_egg)
    func collectEggs(slotIndex: Int) async throws -> CollectEggsResponse {
        let request = client.request(endpoint: "/chicken/collect/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
    
}
