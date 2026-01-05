import Foundation

// MARK: - Weather API (SIMPLE!)

class WeatherAPI {
    private let client = APIClient.shared
    
    /// Get weather for a specific kingdom
    func getKingdomWeather(kingdomId: String) async throws -> WeatherResponse {
        let request = client.request(endpoint: "/weather/kingdom/\(kingdomId)", method: "GET")
        return try await client.execute(request)
    }
    
    /// Get weather for player's current kingdom
    func getCurrentWeather() async throws -> WeatherResponse {
        let request = client.request(endpoint: "/weather/current", method: "GET")
        return try await client.execute(request)
    }
}



