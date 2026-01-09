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
    /// DEPRECATED: Use claimKingdom instead
    /// Coordinates are stored in the CityBoundary, not duplicated in Kingdom
    func createKingdom(
        name: String,
        osmId: String
    ) async throws -> APIKingdom {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let endpoint = "/kingdoms?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)&city_boundary_osm_id=\(osmId)"
        let request = client.request(endpoint: endpoint, method: "POST")
        return try await client.execute(request)
    }
    
    /// Claim an unclaimed kingdom
    func claimKingdom(
        kingdomId: String,
        latitude: Double,
        longitude: Double
    ) async throws -> ConquestResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let endpoint = "/kingdoms/\(kingdomId)/claim?latitude=\(latitude)&longitude=\(longitude)"
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
    /// User is identified from JWT token automatically - no need to send player_id
    func checkIn(
        kingdomId: String,
        location: CLLocationCoordinate2D
    ) async throws -> CheckInResponse {
        let body = CheckInRequest(
            city_boundary_osm_id: kingdomId,
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
    
    // MARK: - Kingdom Management (Ruler Only)
    
    struct SetTaxRateResponse: Codable {
        let success: Bool
        let message: String
        let kingdomId: String
        let kingdomName: String
        let taxRate: Int
        
        enum CodingKeys: String, CodingKey {
            case success
            case message
            case kingdomId = "kingdom_id"
            case kingdomName = "kingdom_name"
            case taxRate = "tax_rate"
        }
    }
    
    /// Set kingdom tax rate (ruler only)
    func setTaxRate(kingdomId: String, taxRate: Int) async throws -> SetTaxRateResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let endpoint = "/kingdoms/\(kingdomId)/tax-rate?tax_rate=\(taxRate)"
        let request = client.request(endpoint: endpoint, method: "PUT")
        return try await client.execute(request)
    }
    
    // MARK: - Decrees
    
    struct DecreeRequest: Codable {
        let text: String
    }
    
    struct MakeDecreeResponse: Codable {
        let success: Bool
        let message: String
        let decreeId: Int
        let kingdomId: String
        let kingdomName: String
        let decreeText: String
        let rulerName: String
        let createdAt: String
        
        enum CodingKeys: String, CodingKey {
            case success, message
            case decreeId = "decree_id"
            case kingdomId = "kingdom_id"
            case kingdomName = "kingdom_name"
            case decreeText = "decree_text"
            case rulerName = "ruler_name"
            case createdAt = "created_at"
        }
    }
    
    /// Make a royal decree (ruler only)
    func makeDecree(kingdomId: String, decreeText: String) async throws -> MakeDecreeResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = DecreeRequest(text: decreeText)
        let request = try client.request(endpoint: "/kingdoms/\(kingdomId)/decree", method: "POST", body: body)
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

