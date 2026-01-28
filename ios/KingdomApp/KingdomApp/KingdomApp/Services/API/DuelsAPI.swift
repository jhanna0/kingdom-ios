import Foundation

/// API service for PvP Arena duels
/// 
/// Simplified flow (like trades):
/// 1. Challenge a friend directly (createDuel with opponentId)
/// 2. Friend accepts/declines
/// 3. Both players start fighting
class DuelsAPI {
    private let client = APIClient.shared
    
    // MARK: - Request Types
    
    private struct CreateDuelRequest: Codable {
        let kingdom_id: String
        let opponent_id: Int
        let wager_gold: Int
    }
    
    private struct LockStyleRequest: Codable {
        let style: String
    }
    
    // MARK: - Challenge Creation
    
    /// Challenge a friend to a duel
    func createDuel(kingdomId: String, opponentId: Int, wagerGold: Int = 0) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let body = CreateDuelRequest(kingdom_id: kingdomId, opponent_id: opponentId, wager_gold: wagerGold)
        let request = try client.request(endpoint: "/duels/create", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Accepting/Declining Challenges
    
    /// Accept a duel challenge
    func acceptInvitation(invitationId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/invitations/\(invitationId)/accept", method: "POST")
        return try await client.execute(request)
    }
    
    /// Decline a duel challenge
    func declineInvitation(invitationId: Int) async throws -> GenericResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/invitations/\(invitationId)/decline", method: "POST")
        return try await client.execute(request)
    }
    
    /// Get pending duel challenges
    func getInvitations() async throws -> DuelInvitationsResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/invitations")
        return try await client.execute(request)
    }
    
    /// Get count of pending challenges (for badge display)
    func getPendingCount() async throws -> DuelPendingCountResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/pending-count")
        return try await client.execute(request)
    }
    
    // MARK: - Match Flow
    
    /// Start the duel (after opponent accepts)
    func startMatch(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/start", method: "POST")
        return try await client.execute(request)
    }
    
    /// Lock in an attack style for the current round
    func lockStyle(matchId: Int, style: String) async throws -> DuelLockStyleResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let body = LockStyleRequest(style: style)
        let request = try client.request(endpoint: "/duels/\(matchId)/lock-style", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Swing-by-Swing Combat (Core Mechanic)
    
    /// Execute ONE swing. Returns the result, then player decides to swing again or stop.
    func swing(matchId: Int) async throws -> DuelSwingResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/swing", method: "POST")
        return try await client.execute(request)
    }
    
    /// Stop swinging and lock in current best roll.
    func stop(matchId: Int) async throws -> DuelStopResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/stop", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Legacy (for backwards compat)
    
    /// Legacy: Execute an attack (maps to swing)
    func attack(matchId: Int) async throws -> DuelAttackResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/attack", method: "POST")
        return try await client.execute(request)
    }

    /// Legacy: Submit round
    func submitRoundSwing(matchId: Int) async throws -> DuelRoundSwingResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/round-swing", method: "POST")
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
    
    /// Claim victory due to opponent timeout
    func claimTimeout(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)/claim-timeout", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Match Info
    
    /// Get match by ID
    func getMatch(matchId: Int) async throws -> DuelResponse {
        guard client.isAuthenticated else { throw APIError.unauthorized }
        
        let request = client.request(endpoint: "/duels/\(matchId)")
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
