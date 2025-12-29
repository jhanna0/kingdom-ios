import Foundation

/// Player state API endpoints
class PlayerAPI {
    private let client = APIClient.shared
    
    // MARK: - State Management
    
    /// Load player state from server (with optional auto check-in)
    func loadState(kingdomId: String? = nil, lat: Double? = nil, lon: Double? = nil) async throws -> APIPlayerState {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        var endpoint = "/player/state"
        var queryParams: [String] = []
        
        if let kingdomId = kingdomId, let lat = lat, let lon = lon {
            queryParams.append("kingdom_id=\(kingdomId)")
            queryParams.append("lat=\(lat)")
            queryParams.append("lon=\(lon)")
        }
        
        if !queryParams.isEmpty {
            endpoint += "?" + queryParams.joined(separator: "&")
        }
        
        let request = client.request(endpoint: endpoint)
        return try await client.execute(request)
    }
    
    /// Save player state to server (full update)
    func saveState(_ state: [String: Any]) async throws -> APIPlayerState {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: state)
        let request = client.request(endpoint: "/player/state", method: "PUT", jsonData: bodyData)
        
        let result: APIPlayerState = try await client.execute(request)
        
        await MainActor.run {
            self.client.lastSyncTime = Date()
        }
        
        return result
    }
    
    /// Sync player state with server (merge)
    func syncState(_ state: [String: Any]) async throws -> PlayerSyncResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body: [String: Any] = [
            "player_state": state,
            "last_sync_time": ISO8601DateFormatter().string(from: client.lastSyncTime ?? Date.distantPast)
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = client.request(endpoint: "/player/sync", method: "POST", jsonData: bodyData)
        
        let response: PlayerSyncResponse = try await client.execute(request)
        
        await MainActor.run {
            self.client.lastSyncTime = Date()
        }
        
        return response
    }
    
    /// Reset player state to defaults
    func resetState() async throws -> APIPlayerState {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/reset", method: "POST")
        
        struct ResetResponse: Codable {
            let success: Bool
            let message: String
            let player_state: APIPlayerState
        }
        
        let response: ResetResponse = try await client.execute(request)
        return response.player_state
    }
    
    // MARK: - Gold Operations
    
    /// Add gold to player
    func addGold(_ amount: Int) async throws -> Int {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/gold/add?amount=\(amount)", method: "POST")
        let response: GoldResponse = try await client.execute(request)
        return response.new_gold
    }
    
    /// Spend gold (validates sufficient funds)
    func spendGold(_ amount: Int) async throws -> Int {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/gold/spend?amount=\(amount)", method: "POST")
        let response: GoldResponse = try await client.execute(request)
        return response.new_gold
    }
    
    // MARK: - Experience & Leveling
    
    /// Add experience and handle level ups
    func addExperience(_ amount: Int) async throws -> ExperienceResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/experience/add?amount=\(amount)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Reputation
    
    /// Add reputation (global and optionally to specific kingdom)
    func addReputation(_ amount: Int, kingdomId: String? = nil) async throws -> ReputationResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        var endpoint = "/player/reputation/add?amount=\(amount)"
        if let kingdomId = kingdomId {
            endpoint += "&kingdom_id=\(kingdomId)"
        }
        
        let request = client.request(endpoint: endpoint, method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Training
    
    /// Train a combat stat (costs gold)
    func trainStat(_ stat: String) async throws -> TrainResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/train/\(stat)", method: "POST")
        return try await client.execute(request)
    }
    
    /// Use skill point to increase stat
    func useSkillPoint(on stat: String) async throws -> SkillPointResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/skill-point/\(stat)", method: "POST")
        return try await client.execute(request)
    }
    
}

