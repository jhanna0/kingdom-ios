import Foundation

// MARK: - Fishing API
// API client for the chill fishing minigame

class FishingAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    // MARK: - Session Management
    
    /// Start a new fishing session
    func startFishing() async throws -> FishingStartResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/fishing/start",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Get current fishing session status
    func getStatus() async throws -> FishingStatusResponse {
        let request = client.request(endpoint: "/fishing/status", method: "GET")
        return try await client.execute(request)
    }
    
    /// End session and collect rewards
    func endFishing() async throws -> FishingEndResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/fishing/end",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    // MARK: - Fishing Actions
    
    /// Cast the line - returns ALL roll results pre-calculated
    func cast() async throws -> FishingCastResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/fishing/cast",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Reel in the fish - returns ALL roll results pre-calculated
    func reel() async throws -> FishingReelResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/fishing/reel",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    // MARK: - Configuration
    
    /// Get fishing configuration (fish types, phases, etc.)
    func getConfig() async throws -> FishingConfig {
        let request = client.request(endpoint: "/fishing/config", method: "GET")
        return try await client.execute(request)
    }
}
