import Foundation

// MARK: - Models

struct EquipmentResponse: Codable {
    let equippedWeapon: EquipmentItem?
    let equippedArmor: EquipmentItem?
    let unequippedWeapons: [EquipmentItem]
    let unequippedArmor: [EquipmentItem]
    
    enum CodingKeys: String, CodingKey {
        case equippedWeapon = "equipped_weapon"
        case equippedArmor = "equipped_armor"
        case unequippedWeapons = "unequipped_weapons"
        case unequippedArmor = "unequipped_armor"
    }
}

struct EquipmentItem: Codable, Identifiable {
    let id: Int
    let itemId: String?
    let displayName: String
    let icon: String
    let type: String
    let tier: Int
    let attackBonus: Int
    let defenseBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case displayName = "display_name"
        case icon
        case type
        case tier
        case attackBonus = "attack_bonus"
        case defenseBonus = "defense_bonus"
    }
}

struct EquipResponse: Codable {
    let success: Bool
    let equipped: EquipmentItem?
}

struct UnequipResponse: Codable {
    let success: Bool
}

// MARK: - API

class EquipmentAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    func getEquipment() async throws -> EquipmentResponse {
        let request = client.request(endpoint: "/equipment", method: "GET")
        return try await client.execute(request)
    }
    
    func equip(itemId: Int) async throws -> EquipResponse {
        let request = client.request(endpoint: "/equipment/equip/\(itemId)", method: "POST")
        return try await client.execute(request)
    }
    
    func unequip(itemId: Int) async throws -> UnequipResponse {
        let request = client.request(endpoint: "/equipment/unequip/\(itemId)", method: "POST")
        return try await client.execute(request)
    }
}
