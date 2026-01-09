import Foundation

/// API service for property management
/// NOTE: Tier info is now handled by TierManager (single source of truth at /tiers endpoint)
class PropertyAPI {
    private let client = APIClient.shared
    
    // MARK: - Response Models
    
    struct PropertyResponse: Codable {
        let id: String
        let kingdom_id: String
        let kingdom_name: String
        let owner_id: Int
        let owner_name: String
        let tier: Int
        let location: String?
        let purchased_at: String
        let last_upgraded: String?
        
        // Convert to Property model
        func toProperty() -> Property {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            return Property(
                id: id,
                kingdomId: kingdom_id,
                kingdomName: kingdom_name,
                ownerId: String(owner_id),
                ownerName: owner_name,
                tier: tier,
                location: location,
                purchasedAt: dateFormatter.date(from: purchased_at) ?? Date(),
                lastUpgraded: last_upgraded != nil ? dateFormatter.date(from: last_upgraded!) : nil
            )
        }
    }
    
    struct PurchaseLandRequest: Codable {
        let kingdom_id: String
        let kingdom_name: String
        let location: String
    }
    
    struct PropertyUpgradeResponse: Codable {
        let success: Bool
        let message: String
        let contractId: String
        let propertyId: String
        let fromTier: Int
        let toTier: Int
        let cost: Int
        let actionsRequired: Int
        
        enum CodingKeys: String, CodingKey {
            case success, message, cost
            case contractId = "contract_id"
            case propertyId = "property_id"
            case fromTier = "from_tier"
            case toTier = "to_tier"
            case actionsRequired = "actions_required"
        }
    }
    
    struct PurchaseConstructionResponse: Codable {
        let success: Bool
        let message: String
        let contractId: String
        let propertyId: String
        let kingdomId: String
        let kingdomName: String
        let location: String
        let actionsRequired: Int
        let costPaid: Int
        
        enum CodingKeys: String, CodingKey {
            case success, message, location
            case contractId = "contract_id"
            case propertyId = "property_id"
            case kingdomId = "kingdom_id"
            case kingdomName = "kingdom_name"
            case actionsRequired = "actions_required"
            case costPaid = "cost_paid"
        }
    }
    
    // MARK: - Get Property Status (ALL data in one call)
    
    struct PropertyStatus: Codable {
        let player_gold: Int
        let player_wood: Int
        let player_reputation: Int
        let player_level: Int
        let player_building_skill: Int
        let properties: [PropertyResponse]
        let property_upgrade_contracts: [PropertyUpgradeContract]?
        let properties_upgrade_status: [PropertyUpgradeStatusItem]
        let current_kingdom: CurrentKingdomInfo?
        let land_price: Int?
        let can_afford: Bool
        let already_owns_property_in_current_kingdom: Bool
        let meets_reputation_requirement: Bool
        let can_purchase: Bool
    }
    
    struct PropertyUpgradeStatusItem: Codable {
        let property_id: String
        let current_tier: Int
        let max_tier: Int?
        let can_upgrade: Bool
        let resource_costs: [ResourceCost]  // DYNAMIC - any resources!
        let actions_required: Int
        let can_afford: Bool
        let missing_resources: [MissingResource]?
        let active_contract: ActiveUpgradeContract?
    }
    
    struct PropertyUpgradeContract: Codable {
        let contract_id: String
        let property_id: String
        let kingdom_id: String?  // Only for construction (from_tier=0)
        let kingdom_name: String?  // Only for construction (from_tier=0)
        let location: String?  // Only for construction (from_tier=0)
        let from_tier: Int
        let to_tier: Int
        let target_tier_name: String
        let actions_required: Int
        let actions_completed: Int
        let cost: Int
        let status: String
        let started_at: String
    }
    
    struct CurrentKingdomInfo: Codable {
        let id: String
        let name: String
        let population: Int
    }
    
    func getPropertyStatus() async throws -> PropertyStatus {
        let request = client.request(endpoint: "/properties/status", method: "GET")
        let response: PropertyStatus = try await client.execute(request)
        return response
    }
    
    // MARK: - Purchase Land (starts construction contract)
    
    func purchaseLand(kingdomId: String, kingdomName: String, location: String) async throws -> PurchaseConstructionResponse {
        let body = PurchaseLandRequest(kingdom_id: kingdomId, kingdom_name: kingdomName, location: location)
        let request = try client.request(endpoint: "/properties/purchase", method: "POST", body: body)
        let response: PurchaseConstructionResponse = try await client.execute(request)
        return response
    }
    
    // MARK: - Upgrade Property (Purchase Contract)
    
    func purchasePropertyUpgrade(propertyId: String) async throws -> PropertyUpgradeResponse {
        let request = client.request(endpoint: "/properties/\(propertyId)/upgrade/purchase", method: "POST")
        let response: PropertyUpgradeResponse = try await client.execute(request)
        return response
    }
    
    // MARK: - Get Single Property
    
    func getProperty(propertyId: String) async throws -> Property {
        let request = client.request(endpoint: "/properties/\(propertyId)", method: "GET")
        let response: PropertyResponse = try await client.execute(request)
        return response.toProperty()
    }
    
    // MARK: - Get Upgrade Status
    
    /// Dynamic resource cost - any resource type!
    struct ResourceCost: Codable {
        let resource: String
        let amount: Int
        let display_name: String
        let icon: String
        let player_has: Int?
        let has_enough: Bool?
    }
    
    struct MissingResource: Codable {
        let resource: String
        let needed: Int
    }
    
    struct PropertyUpgradeStatus: Codable {
        let property_id: String
        let current_tier: Int
        let max_tier: Int
        let can_upgrade: Bool
        let resource_costs: [ResourceCost]  // Dynamic list of ALL costs!
        let actions_required: Int
        let can_afford: Bool
        let missing_resources: [MissingResource]?
        let active_contract: ActiveUpgradeContract?
        let player_building_skill: Int
    }
    
    struct ActiveUpgradeContract: Codable {
        let contract_id: String
        let property_id: String
        let to_tier: Int
        let actions_required: Int
        let actions_completed: Int
        let status: String
    }
    
    func getPropertyUpgradeStatus(propertyId: String) async throws -> PropertyUpgradeStatus {
        let request = client.request(endpoint: "/properties/\(propertyId)/upgrade/status", method: "GET")
        let response: PropertyUpgradeStatus = try await client.execute(request)
        return response
    }
}

