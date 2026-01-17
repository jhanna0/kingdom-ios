import Foundation

// MARK: - Workshop API
// Blueprint-based crafting at Workshop (Property T3+)
// Uses contract system: start craft → work actions → complete

class WorkshopAPI {
    private let client = APIClient.shared
    
    // MARK: - Get Workshop Status
    
    /// Get workshop status - owned blueprints, active contract, materials, craftability
    func getStatus() async throws -> WorkshopStatusResponse {
        let request = client.request(endpoint: "/workshop/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Start Crafting
    
    /// Start crafting an item - creates contract, deducts blueprint + materials
    func startCraft(itemId: String) async throws -> StartCraftResponse {
        let request = client.request(endpoint: "/workshop/craft/\(itemId)/start", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Work on Craft
    
    /// Work on active crafting contract - uses cooldown system
    func workOnCraft() async throws -> CraftWorkResponse {
        let request = client.request(endpoint: "/workshop/craft/work", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Legacy (deprecated)
    
    /// Legacy instant craft - redirects to startCraft
    @available(*, deprecated, message: "Use startCraft instead")
    func craft(itemId: String) async throws -> CraftResponse {
        return try await startCraft(itemId: itemId)
    }
}
