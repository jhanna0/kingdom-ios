import Foundation

/// Contract API endpoints
class ContractAPI {
    private let client = APIClient.shared
    
    // MARK: - Contract CRUD
    
    /// List all contracts for a kingdom
    func listContracts(kingdomId: String? = nil, status: String? = nil) async throws -> [APIContract] {
        var endpoint = "/contracts?"
        
        if let kingdomId = kingdomId {
            endpoint += "kingdom_id=\(kingdomId)&"
        }
        
        if let status = status {
            endpoint += "status=\(status)&"
        }
        
        // Remove trailing & or ?
        endpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "&?"))
        
        let request = client.request(endpoint: endpoint)
        return try await client.execute(request)
    }
    
    /// Get contract by ID
    func getContract(id: String) async throws -> APIContract {
        let request = client.request(endpoint: "/contracts/\(id)")
        return try await client.execute(request)
    }
    
    /// Create a new contract (ruler only)
    func createContract(
        kingdomId: String,
        kingdomName: String,
        buildingType: String,
        buildingLevel: Int,
        rewardPool: Int,
        basePopulation: Int
    ) async throws -> APIContract {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = ContractCreateRequest(
            kingdom_id: kingdomId,
            kingdom_name: kingdomName,
            building_type: buildingType,
            building_level: buildingLevel,
            reward_pool: rewardPool,
            base_population: basePopulation
        )
        
        let request = try client.request(endpoint: "/contracts", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Contract Actions
    
    /// Join a contract as a worker
    func joinContract(contractId: String) async throws -> ContractJoinResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/contracts/\(contractId)/join", method: "POST")
        return try await client.execute(request)
    }
    
    /// Leave a contract
    func leaveContract(contractId: String) async throws {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/contracts/\(contractId)/leave", method: "POST")
        try await client.executeVoid(request)
    }
    
    /// Complete a contract (auto-triggered when ready)
    func completeContract(contractId: String) async throws -> ContractCompleteResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/contracts/\(contractId)/complete", method: "POST")
        return try await client.execute(request)
    }
    
    /// Cancel a contract (ruler only)
    func cancelContract(contractId: String) async throws {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/contracts/\(contractId)/cancel", method: "POST")
        try await client.executeVoid(request)
    }
    
    // MARK: - My Contracts
    
    /// Get contracts the current user is working on
    func getMyContracts() async throws -> [APIContract] {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/contracts/my")
        return try await client.execute(request)
    }
}

