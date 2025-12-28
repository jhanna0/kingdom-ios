import Foundation
import CoreLocation
import Combine

/// API Service for Kingdom backend communication
/// Handles all network requests to the Kingdom API server
class KingdomAPIService: ObservableObject {
    // MARK: - Configuration
    
    // TODO: Replace with your Mac's IP address from terminal
    // Run: ipconfig getifaddr en0
    private let baseURL = "http://192.168.1.13:8000"
    
    private let session: URLSession
    
    // MARK: - Published State
    
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        
        // Test connection on init
        Task {
            await testConnection()
        }
    }
    
    // MARK: - Health Check
    
    /// Test if API is reachable
    func testConnection() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    isConnected = false
                    lastError = "Server returned invalid response"
                }
                return false
            }
            
            // Try to parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status == "healthy" {
                await MainActor.run {
                    isConnected = true
                    lastError = nil
                }
                print("✅ Connected to Kingdom API")
                return true
            }
            
            await MainActor.run {
                isConnected = false
            }
            return false
            
        } catch {
            await MainActor.run {
                isConnected = false
                lastError = error.localizedDescription
            }
            print("❌ Failed to connect to API: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Player API
    
    struct APIPlayer: Codable {
        let id: String
        let name: String
        let gold: Int
        let level: Int
        let created_at: String?
    }
    
    /// Create a new player on the server
    func createPlayer(id: String, name: String, gold: Int = 100, level: Int = 1) async throws -> APIPlayer {
        let url = URL(string: "\(baseURL)/players")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": id,
            "name": name,
            "gold": gold,
            "level": level
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to create player")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(APIPlayer.self, from: data)
    }
    
    /// Get player from server
    func getPlayer(id: String) async throws -> APIPlayer {
        let url = URL(string: "\(baseURL)/players/\(id)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.notFound("Player not found")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(APIPlayer.self, from: data)
    }
    
    /// Update player on server
    func updatePlayer(id: String, name: String, gold: Int, level: Int) async throws -> APIPlayer {
        let url = URL(string: "\(baseURL)/players/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": id,
            "name": name,
            "gold": gold,
            "level": level
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to update player")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(APIPlayer.self, from: data)
    }
    
    /// List all players
    func listPlayers() async throws -> [APIPlayer] {
        let url = URL(string: "\(baseURL)/players")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to list players")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([APIPlayer].self, from: data)
    }
    
    // MARK: - Kingdom API
    
    struct APIKingdom: Codable {
        let id: String
        let name: String
        let ruler_id: String
        let location: LocationData
        let population: Int
        let level: Int
    }
    
    struct LocationData: Codable {
        let latitude: Double
        let longitude: Double
    }
    
    /// Create a new kingdom on the server
    func createKingdom(
        id: String,
        name: String,
        rulerId: String,
        location: CLLocationCoordinate2D,
        population: Int = 0,
        level: Int = 1
    ) async throws -> APIKingdom {
        let url = URL(string: "\(baseURL)/kingdoms")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": id,
            "name": name,
            "ruler_id": rulerId,
            "location": [
                "latitude": location.latitude,
                "longitude": location.longitude
            ],
            "population": population,
            "level": level
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to create kingdom")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(APIKingdom.self, from: data)
    }
    
    /// Get kingdom from server
    func getKingdom(id: String) async throws -> APIKingdom {
        let url = URL(string: "\(baseURL)/kingdoms/\(id)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.notFound("Kingdom not found")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(APIKingdom.self, from: data)
    }
    
    /// List all kingdoms
    func listKingdoms() async throws -> [APIKingdom] {
        let url = URL(string: "\(baseURL)/kingdoms")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to list kingdoms")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([APIKingdom].self, from: data)
    }
    
    // MARK: - Check-in API
    
    struct CheckInResponse: Codable {
        let success: Bool
        let message: String
        let rewards: Rewards
    }
    
    struct Rewards: Codable {
        let gold: Int
        let experience: Int
    }
    
    /// Check in to a kingdom
    func checkIn(playerId: String, kingdomId: String, location: CLLocationCoordinate2D) async throws -> CheckInResponse {
        let url = URL(string: "\(baseURL)/checkin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "player_id": playerId,
            "kingdom_id": kingdomId,
            "location": [
                "latitude": location.latitude,
                "longitude": location.longitude
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to check in")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CheckInResponse.self, from: data)
    }
    
    // MARK: - Sync Helpers
    
    /// Sync local player to server
    func syncPlayer(_ player: Player) async throws {
        do {
            // Try to get existing player
            _ = try await getPlayer(id: player.playerId)
            
            // Player exists, update it
            _ = try await updatePlayer(
                id: player.playerId,
                name: player.name,
                gold: player.gold,
                level: player.level
            )
            
            print("✅ Synced player to server")
            
        } catch APIError.notFound {
            // Player doesn't exist, create it
            _ = try await createPlayer(
                id: player.playerId,
                name: player.name,
                gold: player.gold,
                level: player.level
            )
            
            print("✅ Created player on server")
        }
    }
    
    /// Sync local kingdom to server
    func syncKingdom(_ kingdom: Kingdom) async throws {
        guard let rulerId = kingdom.rulerId else {
            print("⚠️ Cannot sync unclaimed kingdom")
            return
        }
        
        do {
            // Try to get existing kingdom
            _ = try await getKingdom(id: kingdom.id.uuidString)
            
            print("✅ Kingdom already exists on server")
            
        } catch APIError.notFound {
            // Kingdom doesn't exist, create it
            _ = try await createKingdom(
                id: kingdom.id.uuidString,
                name: kingdom.name,
                rulerId: rulerId,
                location: kingdom.territory.center,
                population: kingdom.checkedInPlayers,
                level: kingdom.wallLevel
            )
            
            print("✅ Created kingdom on server")
        }
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case notFound(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let message):
            return "Server error: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

