import Foundation

// MARK: - Workshop Status Response
// Returned by GET /workshop/status

struct WorkshopStatusResponse: Codable {
    let hasWorkshop: Bool
    let workshopProperty: WorkshopPropertyInfo?
    let blueprintCount: Int
    let activeContract: ActiveCraftContract?
    let craftableItems: [CraftableItem]
    let workshopRequirement: String
    
    enum CodingKeys: String, CodingKey {
        case hasWorkshop = "has_workshop"
        case workshopProperty = "workshop_property"
        case blueprintCount = "blueprint_count"
        case activeContract = "active_contract"
        case craftableItems = "craftable_items"
        case workshopRequirement = "workshop_requirement"
    }
}

struct WorkshopPropertyInfo: Codable {
    let id: String
    let kingdomName: String
    let tier: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomName = "kingdom_name"
        case tier
    }
}

// MARK: - Active Craft Contract
// When player has started crafting but not finished

struct ActiveCraftContract: Codable {
    let id: Int
    let itemId: String
    let displayName: String
    let icon: String
    let color: String
    let actionsRequired: Int
    let actionsCompleted: Int
    let progressPercent: Int
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case displayName = "display_name"
        case icon, color
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case progressPercent = "progress_percent"
        case createdAt = "created_at"
    }
}

// MARK: - Craftable Item
// An item that can be crafted at the workshop

struct CraftableItem: Codable, Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let color: String
    let description: String
    let type: String
    let attackBonus: Int
    let defenseBonus: Int
    let actionsRequired: Int
    let recipe: [RecipeIngredient]
    let canCraft: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case icon, color, description, type
        case attackBonus = "attack_bonus"
        case defenseBonus = "defense_bonus"
        case actionsRequired = "actions_required"
        case recipe
        case canCraft = "can_craft"
    }
}

// MARK: - Recipe Ingredient
// One material required for crafting

struct RecipeIngredient: Codable, Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let color: String
    let required: Int
    let playerHas: Int
    let hasEnough: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case icon, color, required
        case playerHas = "player_has"
        case hasEnough = "has_enough"
    }
}

// MARK: - Start Craft Response
// Returned by POST /workshop/craft/{item_id}/start

struct StartCraftResponse: Codable {
    let success: Bool
    let message: String
    let contract: CraftContractInfo?
    let blueprintsRemaining: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, contract
        case blueprintsRemaining = "blueprints_remaining"
    }
}

struct CraftContractInfo: Codable {
    let id: Int
    let itemId: String
    let displayName: String
    let icon: String
    let color: String
    let actionsRequired: Int
    let actionsCompleted: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case displayName = "display_name"
        case icon, color
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
    }
}

// MARK: - Work on Craft Response
// Returned by POST /workshop/craft/work

struct CraftWorkResponse: Codable {
    let success: Bool
    let message: String
    let contractId: Int
    let actionsCompleted: Int
    let actionsRequired: Int
    let progressPercent: Int
    let isComplete: Bool
    let nextWorkAvailableAt: String?
    let foodCost: Int
    let foodRemaining: Int
    let xpEarned: Int
    let leveledUp: Bool
    let item: CraftedItemInfo?
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case contractId = "contract_id"
        case actionsCompleted = "actions_completed"
        case actionsRequired = "actions_required"
        case progressPercent = "progress_percent"
        case isComplete = "is_complete"
        case nextWorkAvailableAt = "next_work_available_at"
        case foodCost = "food_cost"
        case foodRemaining = "food_remaining"
        case xpEarned = "xp_earned"
        case leveledUp = "leveled_up"
        case item
    }
}

struct CraftedItemInfo: Codable {
    let id: Int
    let displayName: String
    let icon: String
    let color: String
    let type: String
    let tier: Int
    let attackBonus: Int
    let defenseBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case icon, color, type, tier
        case attackBonus = "attack_bonus"
        case defenseBonus = "defense_bonus"
    }
}

// MARK: - Legacy CraftResponse (keep for compatibility)
typealias CraftResponse = StartCraftResponse
