import Foundation

// MARK: - Garden Status Response
// Returned by GET /garden/status

struct GardenStatusResponse: Codable {
    let hasGarden: Bool
    let gardenProperty: GardenPropertyInfo?
    let gardenRequirement: String?
    let slots: [GardenSlot]
    let seedCount: Int
    let canPlant: Bool?
    let stats: GardenStats?
    let config: GardenUIConfig
    
    enum CodingKeys: String, CodingKey {
        case hasGarden = "has_garden"
        case gardenProperty = "garden_property"
        case gardenRequirement = "garden_requirement"
        case slots
        case seedCount = "seed_count"
        case canPlant = "can_plant"
        case stats
        case config
    }
}

struct GardenPropertyInfo: Codable {
    let id: String
    let kingdomName: String
    let tier: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomName = "kingdom_name"
        case tier
    }
}

struct GardenStats: Codable {
    let emptySlots: Int
    let growingPlants: Int
    let flowers: Int
    let totalSlots: Int
    
    enum CodingKeys: String, CodingKey {
        case emptySlots = "empty_slots"
        case growingPlants = "growing_plants"
        case flowers
        case totalSlots = "total_slots"
    }
}

struct GardenUIConfig: Codable {
    let emptySlot: SlotUIConfig?
    let growingSlot: SlotUIConfig?
    let deadSlot: SlotUIConfig?
    let wateringCan: SlotUIConfig?
    let wateringIntervalHours: Int?
    let wateringCyclesRequired: Int?
    
    enum CodingKeys: String, CodingKey {
        case emptySlot = "empty_slot"
        case growingSlot = "growing_slot"
        case deadSlot = "dead_slot"
        case wateringCan = "watering_can"
        case wateringIntervalHours = "watering_interval_hours"
        case wateringCyclesRequired = "watering_cycles_required"
    }
}

struct SlotUIConfig: Codable {
    let icon: String
    let color: String
    let label: String?
}

// MARK: - Garden Slot
// Represents a single garden slot with its current state

struct GardenSlot: Codable, Identifiable {
    var id: Int { slotIndex }
    
    let slotIndex: Int
    let status: String  // empty, growing, dead, ready
    let plantType: String?  // weed, flower, wheat
    let icon: String
    let color: String
    let label: String
    let description: String?
    let rarity: String?  // common, uncommon, rare (for flowers)
    let rarityColor: String?  // hex color for rarity badge
    
    // Growing progress
    let wateringCycles: Int?
    let wateringCyclesRequired: Int?
    let progressPercent: Int?
    let lastWateredAt: String?
    let wateringDeadline: String?
    let secondsUntilWater: Int?  // For notification scheduling
    
    // Actions
    let canPlant: Bool
    let canWater: Bool
    let canHarvest: Bool
    let canDiscard: Bool
    
    // Future plant preview (determined at planting!)
    let futurePlantType: String?
    let futureIcon: String?
    let futureColor: String?
    
    enum CodingKeys: String, CodingKey {
        case slotIndex = "slot_index"
        case status
        case plantType = "plant_type"
        case icon, color, label, description, rarity
        case rarityColor = "rarity_color"
        case wateringCycles = "watering_cycles"
        case wateringCyclesRequired = "watering_cycles_required"
        case progressPercent = "progress_percent"
        case lastWateredAt = "last_watered_at"
        case wateringDeadline = "watering_deadline"
        case secondsUntilWater = "seconds_until_water"
        case canPlant = "can_plant"
        case canWater = "can_water"
        case canHarvest = "can_harvest"
        case canDiscard = "can_discard"
        case futurePlantType = "future_plant_type"
        case futureIcon = "future_icon"
        case futureColor = "future_color"
    }
    
    // Computed properties for UI
    var isGrowing: Bool { status == "growing" }
    var isEmpty: Bool { status == "empty" }
    var isDead: Bool { status == "dead" }
    var isReady: Bool { status == "ready" }
}

// MARK: - Garden Action Responses

struct PlantSeedResponse: Codable {
    let success: Bool
    let message: String
    let slot: GardenSlot
    let seedsRemaining: Int
    let nextWaterInSeconds: Int?  // For notification scheduling
    let wateringIntervalHours: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, slot
        case seedsRemaining = "seeds_remaining"
        case nextWaterInSeconds = "next_water_in_seconds"
        case wateringIntervalHours = "watering_interval_hours"
    }
}

struct WaterPlantResponse: Codable {
    let success: Bool
    let message: String
    let slot: GardenSlot
    let isFullyGrown: Bool
    let plantType: String?
    let nextWaterInSeconds: Int?  // For notification scheduling
    let wateringIntervalHours: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, slot
        case isFullyGrown = "is_fully_grown"
        case plantType = "plant_type"
        case nextWaterInSeconds = "next_water_in_seconds"
        case wateringIntervalHours = "watering_interval_hours"
    }
}

struct HarvestPlantResponse: Codable {
    let success: Bool
    let message: String
    let slot: GardenSlot
    let wheatGained: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, slot
        case wheatGained = "wheat_gained"
    }
}

struct DiscardPlantResponse: Codable {
    let success: Bool
    let message: String
    let slot: GardenSlot
}
