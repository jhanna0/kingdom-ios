import Foundation

// MARK: - Workshop API
// Blueprint-based crafting at Workshop (Property T3+)

class WorkshopAPI {
    private let client = APIClient.shared
    
    // MARK: - Get Workshop Status
    
    /// Get workshop status - owned blueprints, materials, craftability
    func getStatus() async throws -> WorkshopStatusResponse {
        let request = client.request(endpoint: "/workshop/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Craft Item
    
    /// Craft an item - consumes 1 blueprint + materials
    func craft(itemId: String) async throws -> CraftResponse {
        let request = client.request(endpoint: "/workshop/craft/\(itemId)", method: "POST")
        return try await client.execute(request)
    }
}
