import Foundation
import CoreLocation

/// Kingdom API endpoints
class KingdomAPI {
    private let client = APIClient.shared
    
    // MARK: - Kingdom CRUD
    
    /// List all kingdoms
    func listKingdoms(skip: Int = 0, limit: Int = 50) async throws -> [APIKingdom] {
        let request = client.request(endpoint: "/kingdoms?skip=\(skip)&limit=\(limit)")
        return try await client.execute(request)
    }
    
    /// Get kingdom by ID
    func getKingdom(id: String) async throws -> APIKingdom {
        let request = client.request(endpoint: "/kingdoms/\(id)")
        return try await client.execute(request)
    }
    
    /// Create a new kingdom (user becomes ruler)
    func createKingdom(
        name: String,
        osmId: String,
        latitude: Double,
        longitude: Double
    ) async throws -> APIKingdom {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let endpoint = "/kingdoms?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)&city_boundary_osm_id=\(osmId)&latitude=\(latitude)&longitude=\(longitude)"
        let request = client.request(endpoint: endpoint, method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - My Kingdoms
    
    /// Get kingdoms where current user is ruler
    func getMyKingdoms() async throws -> [MyKingdomResponse] {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/my-kingdoms")
        return try await client.execute(request)
    }
    
    // MARK: - Check-in
    
    /// Check in to a kingdom
    func checkIn(
        playerId: String,
        kingdomId: String,
        location: CLLocationCoordinate2D
    ) async throws -> CheckInResponse {
        let body = CheckInRequest(
            player_id: playerId,
            kingdom_id: kingdomId,
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        let request = try client.request(endpoint: "/checkin", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Conquest
    
    /// Attempt to conquer a kingdom
    func conquer(
        kingdomId: String,
        latitude: Double,
        longitude: Double
    ) async throws -> ConquestResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let endpoint = "/kingdoms/\(kingdomId)/conquer?latitude=\(latitude)&longitude=\(longitude)"
        let request = client.request(endpoint: endpoint, method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Leaderboard
    
    struct LeaderboardResponse: Codable {
        let category: String
        let leaderboard: [LeaderboardEntry]
    }
    
    struct LeaderboardEntry: Codable {
        let rank: Int
        let user_id: String
        let username: String?
        let display_name: String
        let avatar_url: String?
        let score: Int
        let level: Int
    }
    
    /// Get leaderboard
    func getLeaderboard(category: String = "reputation", limit: Int = 50) async throws -> LeaderboardResponse {
        let request = client.request(endpoint: "/leaderboard?category=\(category)&limit=\(limit)")
        return try await client.execute(request)
    }
}

