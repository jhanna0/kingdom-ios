import Foundation

// MARK: - Research API

class ResearchAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    /// Get research configuration
    func getConfig() async throws -> ResearchConfig {
        let request = client.request(endpoint: "/research/config", method: "GET")
        return try await client.execute(request)
    }
    
    /// Run a complete experiment - returns ALL phase results
    func runExperiment() async throws -> ExperimentResponse {
        struct EmptyRequest: Encodable {}
        let request = try client.request(
            endpoint: "/research/experiment",
            method: "POST",
            body: EmptyRequest()
        )
        return try await client.execute(request)
    }
    
    /// Get player's research stats
    func getStats() async throws -> PlayerResearchStats {
        let request = client.request(endpoint: "/research/stats", method: "GET")
        return try await client.execute(request)
    }
}
