import Foundation

/// Player state API endpoints
class PlayerAPI {
    private let client = APIClient.shared
    
    // MARK: - State Management
    
    /// Load player state from server (with optional auto check-in)
    func loadState(kingdomId: String? = nil) async throws -> APIPlayerState {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        var endpoint = "/player/state"
        
        if let kingdomId = kingdomId {
            endpoint += "?kingdom_id=\(kingdomId)"
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
    
    // MARK: - Player Discovery
    
    /// Get all players in a specific kingdom
    func getPlayersInKingdom(_ kingdomId: String, limit: Int? = nil) async throws -> PlayersInKingdomResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        var endpoint = "/players/in-kingdom/\(kingdomId)"
        if let limit = limit {
            endpoint += "?limit=\(limit)"
        }
        
        let request = client.request(endpoint: endpoint)
        return try await client.execute(request)
    }
    
    /// Get recently active players
    func getActivePlayers(kingdomId: String? = nil, limit: Int = 50) async throws -> ActivePlayersResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        var endpoint = "/players/active?limit=\(limit)"
        if let kingdomId = kingdomId {
            endpoint += "&kingdom_id=\(kingdomId)"
        }
        
        let request = client.request(endpoint: endpoint)
        return try await client.execute(request)
    }
    
    /// Get public profile for any player
    func getPlayerProfile(userId: Int) async throws -> PlayerPublicProfile {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/players/\(userId)/profile")
        return try await client.execute(request)
    }
    
    // MARK: - Hometown Relocation
    
    /// Get hometown relocation status (cooldown, eligibility, warnings)
    func getRelocationStatus() async throws -> RelocationStatusResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/relocation-status")
        return try await client.execute(request)
    }
    
    /// Relocate hometown to current kingdom
    func relocateHometown() async throws -> RelocationResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/player/relocate-hometown", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Subscriber Settings
    
    /// Get subscriber settings (themes, titles, current selections)
    func getSubscriberSettings() async throws -> SubscriberSettingsResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/players/me/subscriber-settings")
        return try await client.execute(request)
    }
    
    /// Update subscriber settings
    func updateSubscriberSettings(_ update: SubscriberSettingsUpdateRequest) async throws -> SubscriberSettingsResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = try client.request(endpoint: "/players/me/subscriber-settings", method: "PUT", body: update)
        return try await client.execute(request)
    }
    
    // MARK: - Username Change
    
    /// Get username change status (cooldown, ruler check)
    func getUsernameStatus() async throws -> UsernameStatusResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/auth/username")
        return try await client.execute(request)
    }
    
    /// Change username (30-day cooldown, rulers cannot change)
    func changeUsername(to newUsername: String) async throws -> UsernameChangeResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = UsernameChangeRequest(new_username: newUsername)
        let request = try client.request(endpoint: "/auth/username", method: "PUT", body: body)
        return try await client.execute(request)
    }
    
}

// MARK: - Relocation Response Models

struct RelocationStatusResponse: Codable {
    let can_relocate: Bool
    let days_until_available: Int
    let cooldown_days: Int
}

struct RelocationResponse: Codable {
    let success: Bool
    let message: String
    let new_hometown_id: String
    let new_hometown_name: String
    let old_hometown_name: String
    let lost_ruler_status: Bool
    let next_relocation_available: String
}

// MARK: - Username Change Models

struct UsernameStatusResponse: Codable {
    let current_username: String
    let can_change: Bool
    let is_ruler: Bool
    let days_until_available: Int
    let cooldown_days: Int
    let last_changed: String?
    let message: String?
}

struct UsernameChangeRequest: Codable {
    let new_username: String
}

struct UsernameChangeResponse: Codable {
    let success: Bool
    let new_username: String
    let message: String
    let next_change_available: String
}

// MARK: - Subscriber Settings Response (see SubscriberSettingsView.swift)

