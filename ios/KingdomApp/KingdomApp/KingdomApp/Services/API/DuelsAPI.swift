import Foundation

/// API service for PvP Arena duels
class DuelsAPI {
    private let client = APIClient.shared
    
    // MARK: - Request Types
    
    private struct CreateDuelRequest: Codable {
        let kingdom_id: String
        let wager_gold: Int
    }
    
    private struct InviteFriendRequest: Codable {
        let friend_user_id: Int
    }
    
    // MARK: - Match Creation
    
    /// Create a new duel match
    func createDuel(kingdomId: String, wagerGold: Int = 0) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let body = CreateDuelRequest(kingdom_id: kingdomId, wager_gold: wagerGold)
        let request = try client.request(endpoint: "/duels/create", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    /// Invite a friend to the duel
    func inviteFriend(matchId: Int, friendUserId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let body = InviteFriendRequest(friend_user_id: friendUserId)
        let request = try client.request(endpoint: "/duels/\(matchId)/invite", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Joining
    
    /// Join a duel by match code
    func joinByCode(_ code: String) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/join/\(code.uppercased())", method: "POST")
        return try await client.execute(request)
    }
    
    /// Accept a duel invitation
    func acceptInvitation(invitationId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/invitations/\(invitationId)/accept", method: "POST")
        return try await client.execute(request)
    }
    
    /// Decline a duel invitation
    func declineInvitation(invitationId: Int) async throws -> GenericResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/invitations/\(invitationId)/decline", method: "POST")
        return try await client.execute(request)
    }
    
    /// Get pending duel invitations
    func getInvitations() async throws -> DuelInvitationsResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/invitations")
        return try await client.execute(request)
    }
    
    // MARK: - Match Flow
    
    /// Confirm the opponent (challenger only) - after opponent joins
    func confirmOpponent(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/confirm", method: "POST")
        return try await client.execute(request)
    }
    
    /// Decline the opponent (challenger only) - cancels match, no gold taken
    func declineOpponent(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/decline", method: "POST")
        return try await client.execute(request)
    }
    
    /// Start the duel (after both players confirmed)
    func startMatch(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/start", method: "POST")
        return try await client.execute(request)
    }
    
    /// Execute an attack during your turn
    func attack(matchId: Int) async throws -> DuelAttackResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/attack", method: "POST")
        return try await client.execute(request)
    }
    
    /// Forfeit the match
    func forfeit(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/forfeit", method: "POST")
        return try await client.execute(request)
    }
    
    /// Cancel a waiting match
    func cancel(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/cancel", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Match Info
    
    /// Get match by ID
    func getMatch(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)")
        return try await client.execute(request)
    }
    
    /// Get match by code
    func getMatchByCode(_ code: String) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/code/\(code.uppercased())")
        return try await client.execute(request)
    }
    
    /// Get player's active match (if any)
    func getActiveMatch() async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/active")
        return try await client.execute(request)
    }
    
    // MARK: - Stats & Leaderboard
    
    /// Get player's duel stats
    func getMyStats() async throws -> DuelStatsResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/stats")
        return try await client.execute(request)
    }
    
    /// Get leaderboard
    func getLeaderboard(limit: Int = 10) async throws -> DuelLeaderboardResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/leaderboard?limit=\(limit)")
        return try await client.execute(request)
    }
    
    /// Get recent matches in a kingdom
    func getRecentMatches(kingdomId: String, limit: Int = 10) async throws -> DuelRecentMatchesResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/kingdom/\(kingdomId)/recent?limit=\(limit)")
        return try await client.execute(request)
    }
}

/// Helper response type for simple success/message responses
struct GenericResponse: Codable {
    let success: Bool
    let message: String?
}
