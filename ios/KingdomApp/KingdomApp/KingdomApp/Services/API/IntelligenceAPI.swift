import Foundation

extension APIClient {
    
    // MARK: - Intelligence Operations
    
    /// Get military strength of a kingdom (own kingdom or scouted intel)
    func getMilitaryStrength(kingdomId: String) async throws -> MilitaryStrengthResponse {
        let request = self.request(endpoint: "/intelligence/military-strength/\(kingdomId)", method: "GET")
        let response: MilitaryStrengthResponse = try await execute(request)
        return response
    }
    
    /// Gather intelligence on an enemy kingdom
    func gatherIntelligence(kingdomId: String) async throws -> GatherIntelligenceResponse {
        let request = self.request(endpoint: "/intelligence/gather/\(kingdomId)", method: "POST")
        let response: GatherIntelligenceResponse = try await execute(request)
        return response
    }
}

