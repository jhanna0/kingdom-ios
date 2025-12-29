import Foundation

/// API service for property management
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
        let purchased_at: String
        let last_upgraded: String?
        
        // Convert to Property model
        func toProperty() -> Property {
            let dateFormatter = ISO8601DateFormatter()
            
            return Property(
                id: id,
                kingdomId: kingdom_id,
                kingdomName: kingdom_name,
                ownerId: String(owner_id),
                ownerName: owner_name,
                tier: tier,
                purchasedAt: dateFormatter.date(from: purchased_at) ?? Date(),
                lastUpgraded: last_upgraded != nil ? dateFormatter.date(from: last_upgraded!) : nil
            )
        }
    }
    
    struct PurchaseLandRequest: Codable {
        let kingdom_id: String
        let kingdom_name: String
    }
    
    // MARK: - Get Player Properties
    
    func getPlayerProperties() async throws -> [Property] {
        let request = client.request(endpoint: "/properties", method: "GET")
        let response: [PropertyResponse] = try await client.execute(request)
        return response.map { $0.toProperty() }
    }
    
    // MARK: - Purchase Land
    
    func purchaseLand(kingdomId: String, kingdomName: String) async throws -> Property {
        let body = PurchaseLandRequest(kingdom_id: kingdomId, kingdom_name: kingdomName)
        let request = try client.request(endpoint: "/properties/purchase", method: "POST", body: body)
        let response: PropertyResponse = try await client.execute(request)
        return response.toProperty()
    }
    
    // MARK: - Upgrade Property
    
    func upgradeProperty(propertyId: String) async throws -> Property {
        let request = client.request(endpoint: "/properties/\(propertyId)/upgrade", method: "POST")
        let response: PropertyResponse = try await client.execute(request)
        return response.toProperty()
    }
    
    // MARK: - Get Single Property
    
    func getProperty(propertyId: String) async throws -> Property {
        let request = client.request(endpoint: "/properties/\(propertyId)", method: "GET")
        let response: PropertyResponse = try await client.execute(request)
        return response.toProperty()
    }
}

