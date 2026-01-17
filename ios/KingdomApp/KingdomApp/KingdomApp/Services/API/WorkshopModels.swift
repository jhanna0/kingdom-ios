import Foundation

// MARK: - Workshop Status Response
// Returned by GET /workshop/status

struct WorkshopStatusResponse: Codable {
    let hasWorkshop: Bool
    let workshopProperty: WorkshopPropertyInfo?
    let blueprintCount: Int
    let craftableItems: [CraftableItem]
    let workshopRequirement: String
    
    enum CodingKeys: String, CodingKey {
        case hasWorkshop = "has_workshop"
        case workshopProperty = "workshop_property"
        case blueprintCount = "blueprint_count"
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
    let recipe: [RecipeIngredient]
    let canCraft: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case icon, color, description, type
        case attackBonus = "attack_bonus"
        case defenseBonus = "defense_bonus"
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

// MARK: - Craft Response
// Returned by POST /workshop/craft/{item_id}

struct CraftResponse: Codable {
    let success: Bool
    let message: String
    let item: CraftedItemInfo?
    let blueprintsRemaining: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, item
        case blueprintsRemaining = "blueprints_remaining"
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
