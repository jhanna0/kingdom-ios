import Foundation

// MARK: - Kitchen API
// Kitchen oven - bake wheat into sourdough bread
// Unlocked at Property Tier 3 (Villa)

class KitchenAPI {
    private let client = APIClient.shared
    
    // MARK: - Get Kitchen Status
    
    /// Get kitchen status - oven slots, wheat owned, what can be done
    func getStatus() async throws -> KitchenStatusResponse {
        let request = client.request(endpoint: "/kitchen/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Load Oven
    
    /// Load wheat into an oven slot to start baking
    /// - Parameters:
    ///   - slotIndex: The oven slot to load (0-3)
    ///   - wheatAmount: Amount of wheat to use (1-4, default 1). Each wheat produces 12 loaves.
    func loadOven(slotIndex: Int, wheatAmount: Int = 1) async throws -> LoadOvenResponse {
        var body: [String: Any] = [:]
        if wheatAmount > 1 {
            body["wheat_amount"] = wheatAmount
        }
        
        let request = client.request(
            endpoint: "/kitchen/load/\(slotIndex)?wheat_amount=\(wheatAmount)",
            method: "POST"
        )
        return try await client.execute(request)
    }
    
    // MARK: - Collect Bread
    
    /// Collect finished sourdough from an oven slot
    func collectBread(slotIndex: Int) async throws -> CollectBreadResponse {
        let request = client.request(endpoint: "/kitchen/collect/\(slotIndex)", method: "POST")
        return try await client.execute(request)
    }
}
