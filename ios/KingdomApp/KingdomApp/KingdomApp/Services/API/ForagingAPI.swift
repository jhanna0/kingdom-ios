import Foundation

// MARK: - Foraging API
// Simple: start (get everything), collect (claim reward)

class ForagingAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    /// Start - returns pre-calculated grid + result
    func startForaging() async throws -> ForagingStartResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/foraging/start",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Collect rewards (only call if won)
    func collectRewards() async throws -> ForagingCollectResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/foraging/collect",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// End without collecting
    func endForaging() async throws -> ForagingEndResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/foraging/end",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Get config
    func getConfig() async throws -> ForagingConfig {
        let request = client.request(endpoint: "/foraging/config", method: "GET")
        return try await client.execute(request)
    }
}
