import Foundation

// MARK: - Actions API

class ActionsAPI {
    private let client = APIClient.shared
    
    // MARK: - Status
    
    func getActionStatus() async throws -> AllActionStatus {
        let request = client.request(endpoint: "/actions/status", method: "GET")
        return try await client.execute(request)
    }
    
    // MARK: - Generic Action (Fully Dynamic!)
    
    /// Perform any action using the endpoint from ActionStatus
    /// Backend provides complete endpoint with all params - frontend just POSTs
    func performGenericAction(endpoint: String) async throws -> GenericActionResponse {
        let request = client.request(endpoint: endpoint, method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Contracts (Work)
    
    func workOnContract(contractId: String) async throws -> WorkActionResponse {
        let request = client.request(endpoint: "/actions/work/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Patrol
    
    func startPatrol() async throws -> PatrolActionResponse {
        let request = client.request(endpoint: "/actions/patrol", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Farming
    
    func performFarming() async throws -> FarmActionResponse {
        let request = client.request(endpoint: "/actions/farm", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Training
    
    func getTrainingCosts() async throws -> TrainingCostsResponse {
        let request = client.request(endpoint: "/actions/train/costs", method: "GET")
        return try await client.execute(request)
    }
    
    func purchaseTraining(type: String) async throws -> PurchaseTrainingResponse {
        let request = client.request(endpoint: "/actions/train/purchase?training_type=\(type)", method: "POST")
        return try await client.execute(request)
    }
    
    func workOnTraining(contractId: String) async throws -> TrainingActionResponse {
        let request = client.request(endpoint: "/actions/train/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Crafting
    
    func getCraftingCosts() async throws -> CraftingCosts {
        struct Response: Codable {
            let costs: CraftingCosts
        }
        let request = client.request(endpoint: "/actions/craft/costs", method: "GET")
        let response: Response = try await client.execute(request)
        return response.costs
    }
    
    func purchaseCraft(equipmentType: String, tier: Int) async throws -> PurchaseCraftResponse {
        let request = client.request(
            endpoint: "/actions/craft/purchase?equipment_type=\(equipmentType)&tier=\(tier)",
            method: "POST"
        )
        return try await client.execute(request)
    }
    
    func workOnCraft(contractId: String) async throws -> CraftingActionResponse {
        let request = client.request(endpoint: "/actions/craft/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Sabotage
    
    func sabotageContract(contractId: String) async throws -> SabotageActionResponse {
        let request = client.request(endpoint: "/actions/sabotage/\(contractId)", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Property Upgrades
    // NOTE: Property upgrades use performGenericAction() with the dynamic endpoint from the contract
    // The endpoint comes from PropertyUpgradeContract.endpoint (e.g., "/actions/work-property/{contract_id}")
    
    // MARK: - Coups
    
    func joinCoup(coupId: Int, side: String) async throws -> CoupJoinResponse {
        struct JoinRequest: Codable {
            let side: String
        }
        
        let body = JoinRequest(side: side)
        let request = try client.request(endpoint: "/battles/\(coupId)/join", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Gathering
    
    /// Gather a resource (wood or iron)
    /// No backend cooldown - frontend handles 0.5s tap cooldown
    func gatherResource(resourceType: String) async throws -> GatherResponse {
        let request = client.request(
            endpoint: "/actions/gather?resource_type=\(resourceType)",
            method: "POST"
        )
        return try await client.execute(request)
    }
    
    /// Get gathering configuration (resource types and tier info)
    func getGatherConfig() async throws -> GatherConfigResponse {
        let request = client.request(endpoint: "/actions/gather/config", method: "GET")
        return try await client.execute(request)
    }
}



