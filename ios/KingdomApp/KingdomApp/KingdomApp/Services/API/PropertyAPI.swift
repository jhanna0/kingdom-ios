import Foundation

/// API service for property management
/// NOTE: Tier info is now handled by TierManager (single source of truth at /tiers endpoint)
class PropertyAPI {
    private let client = APIClient.shared
    
    // MARK: - Response Models
    
    struct PropertyRoom: Codable {
        let id: String
        let name: String
        let icon: String
        let color: String
        let description: String
        let route: String
        let has_badge: Bool?
    }
    
    struct AvailableOption: Codable {
        let id: String
        let name: String
        let tier: Int
        let icon: String?
        let description: String?
        let gold_per_action: Double?
        let actions_required: Int?
        let per_action_costs: [ResourceCost]?
    }
    
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
        let available_rooms: [PropertyRoom]?
        let built_rooms: [String]?  // Room IDs that have been built
        let available_options: [AvailableOption]?  // Options that can still be built
        // Fortification fields
        let fortification_unlocked: Bool?
        let fortification_percent: Int?
        let fortification_base_percent: Int?
        let fortification: FortificationInfo?
        
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
                lastUpgraded: last_upgraded != nil ? dateFormatter.date(from: last_upgraded!) : nil,
                fortificationUnlocked: fortification_unlocked ?? (tier >= 2),
                fortificationPercent: fortification?.percent ?? fortification_percent ?? 0,
                fortificationBasePercent: fortification?.base_percent ?? fortification_base_percent ?? 0
            )
        }
    }
    
    struct FortificationInfo: Codable {
        let percent: Int
        let base_percent: Int
        let decays_per_day: Int
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
        let goldCost: Int
        let actionsRequired: Int

        enum CodingKeys: String, CodingKey {
            case success, message
            case contractId = "contract_id"
            case propertyId = "property_id"
            case fromTier = "from_tier"
            case toTier = "to_tier"
            case goldCost = "gold_cost"
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
        let land_price: Int?  // OLD: Total cost (backwards compat)
        let gold_per_action_for_land: Double?  // NEW: Per-action cost
        let actions_for_land: Int?  // NEW: Number of actions needed
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
        let gold_per_action: Double?  // Gold cost per action
        let current_tax_rate: Int?  // Tax rate for display
        let status: String
        let started_at: String
        let per_action_costs: [ResourceCost]?  // Resources consumed per work action
        let option_id: String?  // Which specific room/option is being built
        let option_name: String?  // Display name for the room
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
    
    func purchasePropertyUpgrade(propertyId: String, optionId: String? = nil) async throws -> PropertyUpgradeResponse {
        let request: URLRequest
        if let optionId = optionId {
            request = try client.request(endpoint: "/properties/\(propertyId)/upgrade/purchase", method: "POST", body: ["option_id": optionId])
        } else {
            request = client.request(endpoint: "/properties/\(propertyId)/upgrade/purchase", method: "POST")
        }
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
        // Gold paid upfront to start
        let gold_cost: Int?
        // Resources required per action (wood, iron, etc.)
        let per_action_costs: [ResourceCost]?
        // Total resources needed over all actions (for display)
        let total_costs: [TotalResourceCost]?
        let actions_required: Int
        let can_afford: Bool  // Can afford gold to START
        let player_gold: Int?
        let active_contract: ActiveUpgradeContract?
        let player_building_skill: Int
    }
    
    /// Total resource cost over all actions (for display like "280 wood total")
    struct TotalResourceCost: Codable {
        let resource: String
        let amount: Int  // Per-action amount
        let total_amount: Int  // Total over all actions
        let per_action_amount: Int  // Same as amount, for clarity
        let display_name: String
        let icon: String
    }
    
    struct ActiveUpgradeContract: Codable {
        let contract_id: String
        let property_id: String
        let to_tier: Int
        let actions_required: Int
        let actions_completed: Int
        let status: String
        let per_action_costs: [ResourceCost]?  // What each action costs
    }
    
    func getPropertyUpgradeStatus(propertyId: String) async throws -> PropertyUpgradeStatus {
        let request = client.request(endpoint: "/properties/\(propertyId)/upgrade/status", method: "GET")
        let response: PropertyUpgradeStatus = try await client.execute(request)
        return response
    }
    
    // MARK: - Fortification
    
    struct FortifyOptionItem: Codable, Identifiable {
        let id: Int
        let item_id: String?
        let display_name: String
        let icon: String
        let type: String
        let tier: Int
        let gain_min: Int
        let gain_max: Int
        let is_equipped: Bool
        let count: Int
        
        var gainRange: String {
            "+\(gain_min)-\(gain_max)%"
        }
    }
    
    struct FortificationTLDR: Codable {
        let title: String
        let icon: String
        let points: [String]
    }
    
    struct FortificationTierGain: Codable {
        let tier: Int
        let min: Int
        let max: Int
    }
    
    struct FortificationGainRanges: Codable {
        let title: String
        let icon: String
        let color: String
        let tiers: [FortificationTierGain]
    }
    
    struct FortificationT5Bonus: Codable {
        let base: Int
        let text: String
        let icon: String
        let color: String
    }
    
    struct FortificationUIStrings: Codable {
        let convert_card_title: String
        let convert_card_icon: String
        let convert_card_accent_color: String
        
        let loading_eligible_items: String
        let locked_message: String
        let empty_title: String
        let empty_message: String
        let choose_item_message: String
        
        let weapons_label: String
        let armor_label: String
        
        let primary_action_label: String
        let confirmation_title: String
        let confirmation_confirm_label: String
        let confirmation_cancel_label: String
        let confirmation_message_template: String
        
        let result_title: String
        let result_ok_label: String
        let result_message_template: String
        
        let generic_error_title: String
        let generic_error_ok_label: String
    }
    
    struct FortificationExplanation: Codable {
        let title: String
        let ui: FortificationUIStrings
        let tldr: FortificationTLDR
        let gain_ranges: FortificationGainRanges
        let decay: String
        let decay_icon: String
        let decay_color: String
        let cap: Int
        let rules: String
        let rules_icon: String
        let rules_color: String
        let tip: String
        let tip_icon: String
        let tip_color: String
        let t5_bonus: FortificationT5Bonus?
    }
    
    struct FortifyOptionsResponse: Codable {
        let property_id: String
        let fortification_unlocked: Bool
        let current_fortification: Int
        let base_fortification: Int
        let eligible_items: [FortifyOptionItem]
        let weapon_count: Int
        let armor_count: Int
        let explanation: FortificationExplanation
    }
    
    struct FortifyRequest: Codable {
        let player_item_id: Int
    }
    
    struct FortifyResponse: Codable {
        let success: Bool
        let message: String
        let fortification_before: Int
        let fortification_gain: Int
        let fortification_after: Int
        let item_consumed: String
    }
    
    func getFortifyOptions(propertyId: String) async throws -> FortifyOptionsResponse {
        let request = client.request(endpoint: "/properties/\(propertyId)/fortify/options", method: "GET")
        let response: FortifyOptionsResponse = try await client.execute(request)
        return response
    }
    
    func fortifyProperty(propertyId: String, itemId: Int) async throws -> FortifyResponse {
        let body = FortifyRequest(player_item_id: itemId)
        let request = try client.request(endpoint: "/properties/\(propertyId)/fortify", method: "POST", body: body)
        let response: FortifyResponse = try await client.execute(request)
        return response
    }
}

