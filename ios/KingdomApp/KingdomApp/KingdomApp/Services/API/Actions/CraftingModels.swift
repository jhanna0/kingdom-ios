import Foundation

// MARK: - Crafting Contract

struct CraftingContract: Codable, Identifiable {
    let id: String
    let equipmentType: String
    let tier: Int
    let actionsRequired: Int
    let actionsCompleted: Int
    let goldPaid: Int
    let ironPaid: Int
    let steelPaid: Int
    let createdAt: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, tier, status
        case equipmentType = "equipment_type"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case goldPaid = "gold_paid"
        case ironPaid = "iron_paid"
        case steelPaid = "steel_paid"
        case createdAt = "created_at"
    }
    
    var progress: Double {
        return Double(actionsCompleted) / Double(actionsRequired)
    }
}

// MARK: - Crafting Cost Tier

struct CraftingCostTier: Codable {
    let gold: Int
    let iron: Int
    let steel: Int
    let actionsRequired: Int
    let statBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case gold, iron, steel
        case actionsRequired = "actions_required"
        case statBonus = "stat_bonus"
    }
}

// MARK: - Crafting Costs

struct CraftingCosts: Codable {
    let tier1: CraftingCostTier
    let tier2: CraftingCostTier
    let tier3: CraftingCostTier
    let tier4: CraftingCostTier
    let tier5: CraftingCostTier
    
    enum CodingKeys: String, CodingKey {
        case tier1 = "tier_1"
        case tier2 = "tier_2"
        case tier3 = "tier_3"
        case tier4 = "tier_4"
        case tier5 = "tier_5"
    }
    
    func cost(for tier: Int) -> CraftingCostTier? {
        switch tier {
        case 1: return tier1
        case 2: return tier2
        case 3: return tier3
        case 4: return tier4
        case 5: return tier5
        default: return nil
        }
    }
}

// MARK: - Purchase Craft Response

struct PurchaseCraftResponse: Codable {
    let success: Bool
    let message: String
    let equipmentType: String
    let tier: Int
    let contractId: String
    let actionsRequired: Int
    let statBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, tier
        case equipmentType = "equipment_type"
        case contractId = "contract_id"
        case actionsRequired = "actions_required"
        case statBonus = "stat_bonus"
    }
}

// MARK: - Crafting Action Response

struct CraftingActionResponse: Codable {
    struct EquipmentReward: Codable {
        let id: String
        let type: String
        let tier: Int
        let attackBonus: Int
        let defenseBonus: Int
        let craftedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, type, tier
            case attackBonus = "attack_bonus"
            case defenseBonus = "defense_bonus"
            case craftedAt = "crafted_at"
        }
    }
    
    struct CraftRewards: Codable {
        let xp: Int
        let equipment: EquipmentReward?
    }
    
    let success: Bool
    let message: String
    let contractId: String
    let actionsCompleted: Int
    let actionsRequired: Int
    let progressPercent: Int
    let isComplete: Bool
    let nextCraftAvailableAt: Date
    let rewards: CraftRewards
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case contractId = "contract_id"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case nextCraftAvailableAt = "next_craft_available_at"
    }
}

// MARK: - Equip Response

struct EquipResponse: Codable {
    let success: Bool
    let message: String
    let equipped: CraftingActionResponse.EquipmentReward?
}

