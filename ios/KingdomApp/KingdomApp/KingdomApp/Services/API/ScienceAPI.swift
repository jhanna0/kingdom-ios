import Foundation

// MARK: - Science API
// High/Low guessing game API - backend validates all guesses!

class ScienceAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    /// Start a new experiment - backend pre-calculates all numbers
    func startExperiment() async throws -> ScienceStartResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/science/start",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Submit a guess - backend validates against pre-calculated answer
    func makeGuess(_ guess: String) async throws -> ScienceGuessResponse {
        struct GuessRequest: Encodable {
            let guess: String
        }
        let request = try client.request(
            endpoint: "/science/guess",
            method: "POST",
            body: GuessRequest(guess: guess)
        )
        return try await client.execute(request)
    }
    
    /// Collect rewards
    func collectRewards() async throws -> ScienceCollectResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/science/collect",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// End without collecting
    func endExperiment() async throws -> ScienceEndResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/science/end",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Get player stats
    func getStats() async throws -> SciencePlayerStats {
        let request = client.request(endpoint: "/science/stats", method: "GET")
        return try await client.execute(request)
    }
    
    /// Get config
    func getConfig() async throws -> ScienceConfig {
        let request = client.request(endpoint: "/science/config", method: "GET")
        return try await client.execute(request)
    }
}
