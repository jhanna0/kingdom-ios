import Foundation

// MARK: - Hunt API
// API client for hunting endpoints

class HuntAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    // MARK: - Hunt Management
    
    /// Create a new hunt in a kingdom
    func createHunt(kingdomId: String) async throws -> HuntResponse {
        struct CreateRequest: Encodable {
            let kingdom_id: String
        }
        let request = try client.request(
            endpoint: "/hunts/create",
            method: "POST",
            body: CreateRequest(kingdom_id: kingdomId)
        )
        return try await client.execute(request)
    }
    
    /// Join an existing hunt
    func joinHunt(huntId: String) async throws -> HuntResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/join", method: "POST")
        return try await client.execute(request)
    }
    
    /// Leave a hunt
    func leaveHunt(huntId: String) async throws -> HuntResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/leave", method: "POST")
        return try await client.execute(request)
    }
    
    /// Toggle ready status
    func toggleReady(huntId: String) async throws -> HuntResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/ready", method: "POST")
        return try await client.execute(request)
    }
    
    /// Start the hunt (leader only)
    func startHunt(huntId: String) async throws -> HuntResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/start", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Multi-Roll Phase Execution
    
    /// Execute a single roll within the current phase
    func executeRoll(huntId: String) async throws -> RollResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/roll", method: "POST")
        return try await client.execute(request)
    }
    
    /// Resolve/finalize the current phase (e.g., Master Roll for tracking)
    func resolvePhase(huntId: String) async throws -> PhaseResultResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/resolve", method: "POST")
        return try await client.execute(request)
    }
    
    /// Advance to the next phase
    func nextPhase(huntId: String) async throws -> HuntResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/next-phase", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Legacy Phase Execution
    
    /// Execute a hunt phase (legacy single-roll mode)
    func executePhase(huntId: String, phase: HuntPhase) async throws -> PhaseResultResponse {
        let request = client.request(endpoint: "/hunts/\(huntId)/phase/\(phase.rawValue)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Hunt Status
    
    /// Get hunt status
    func getHunt(huntId: String) async throws -> HuntSession {
        let request = client.request(endpoint: "/hunts/\(huntId)", method: "GET")
        return try await client.execute(request)
    }
    
    /// Get active hunt in a kingdom
    func getActiveHunt(kingdomId: String) async throws -> ActiveHuntResponse {
        let request = client.request(endpoint: "/hunts/kingdom/\(kingdomId)", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Configuration
    
    /// Get probability preview for current player
    func getHuntPreview() async throws -> HuntPreviewResponse {
        let request = client.request(endpoint: "/hunts/preview", method: "GET")
        return try await client.execute(request)
    }
    
    /// Get hunt configuration
    func getHuntConfig() async throws -> HuntConfigResponse {
        let request = client.request(endpoint: "/hunts/config", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Leaderboard
    
    /// Get hunt leaderboard for a kingdom
    func getLeaderboard(kingdomId: String) async throws -> HuntLeaderboardResponse {
        let request = client.request(endpoint: "/hunts/leaderboard/\(kingdomId)", method: "GET")
        return try await client.execute(request)
    }
}
