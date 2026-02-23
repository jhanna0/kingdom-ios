import Foundation

// MARK: - Chicken Status Response
// Returned by GET /chicken/status

struct ChickenStatusResponse: Codable {
    let hasCoop: Bool
    let coopProperty: ChickenPropertyInfo?
    let coopRequirement: String?
    let slots: [ChickenSlot]
    let rareEggCount: Int
    let canHatch: Bool?
    let stats: ChickenStats?
    let config: ChickenUIConfig
    
    enum CodingKeys: String, CodingKey {
        case hasCoop = "has_coop"
        case coopProperty = "coop_property"
        case coopRequirement = "coop_requirement"
        case slots
        case rareEggCount = "rare_egg_count"
        case canHatch = "can_hatch"
        case stats
        case config
    }
}

struct ChickenPropertyInfo: Codable {
    let id: String
    let kingdomName: String
    let tier: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomName = "kingdom_name"
        case tier
    }
}

struct ChickenStats: Codable {
    let emptySlots: Int
    let incubating: Int
    let aliveChickens: Int
    let eggsReady: Int
    let totalSlots: Int
    
    enum CodingKeys: String, CodingKey {
        case emptySlots = "empty_slots"
        case incubating
        case aliveChickens = "alive_chickens"
        case eggsReady = "eggs_ready"
        case totalSlots = "total_slots"
    }
}

struct ChickenUIConfig: Codable {
    let emptySlot: SlotUIConfig?
    let incubatingSlot: SlotUIConfig?
    let aliveSlot: SlotUIConfig?
    let egg: SlotUIConfig?
    let incubationHours: Int?
    let eggIntervalHours: Int?
    let minStatForEggs: Int?
    let badgeThreshold: Int?
    
    enum CodingKeys: String, CodingKey {
        case emptySlot = "empty_slot"
        case incubatingSlot = "incubating_slot"
        case aliveSlot = "alive_slot"
        case egg
        case incubationHours = "incubation_hours"
        case eggIntervalHours = "egg_interval_hours"
        case minStatForEggs = "min_stat_for_eggs"
        case badgeThreshold = "badge_threshold"
    }
}

// MARK: - Chicken Slot
// Represents a single chicken slot with its current state

struct ChickenSlot: Codable, Identifiable {
    var id: Int { slotIndex }
    
    let slotIndex: Int
    let status: String  // empty, incubating, alive
    let icon: String
    let color: String
    let label: String
    
    // Chicken info (when alive)
    let name: String?
    let canRename: Bool?
    
    // Tamagotchi stats (when alive)
    let stats: ChickenTamagotchiStats?
    let overallStatus: String?  // happy, sad
    let needsAttention: Bool?
    let minStatForEggs: Int?
    
    // Actions available (when alive)
    let actions: [ChickenAction]?
    
    // Eggs (when alive)
    let eggsAvailable: Int?
    let totalEggsLaid: Int?
    let secondsUntilEgg: Int?
    
    // Incubation tracking
    let incubationStartedAt: String?
    let hatchTime: String?
    let secondsUntilHatch: Int?
    let progressPercent: Int?
    
    // Capabilities
    let canHatch: Bool
    let canName: Bool
    let canCollect: Bool
    
    enum CodingKeys: String, CodingKey {
        case slotIndex = "slot_index"
        case status, icon, color, label
        case name
        case canRename = "can_rename"
        case stats
        case overallStatus = "overall_status"
        case needsAttention = "needs_attention"
        case minStatForEggs = "min_stat_for_eggs"
        case actions
        case eggsAvailable = "eggs_available"
        case totalEggsLaid = "total_eggs_laid"
        case secondsUntilEgg = "seconds_until_egg"
        case incubationStartedAt = "incubation_started_at"
        case hatchTime = "hatch_time"
        case secondsUntilHatch = "seconds_until_hatch"
        case progressPercent = "progress_percent"
        case canHatch = "can_hatch"
        case canName = "can_name"
        case canCollect = "can_collect"
    }
    
    // Computed properties for UI
    var isEmpty: Bool { status == "empty" }
    var isIncubating: Bool { status == "incubating" }
    var isAlive: Bool { status == "alive" }
    var isHappy: Bool { overallStatus == "happy" }
}

// MARK: - Tamagotchi Stats

struct ChickenTamagotchiStats: Codable {
    let hunger: Int
    let happiness: Int
    let cleanliness: Int
}

// MARK: - Chicken Action

struct ChickenAction: Codable, Identifiable {
    var id: String { actionId }
    
    let actionId: String
    let label: String
    let icon: String
    let stat: String
    let goldCost: Int
    let restoreAmount: Int
    let enabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case actionId = "id"
        case label, icon, stat
        case goldCost = "gold_cost"
        case restoreAmount = "restore_amount"
        case enabled
    }
}

// MARK: - Chicken Action Responses

struct HatchEggResponse: Codable {
    let success: Bool
    let message: String
    let slot: ChickenSlot
    let rareEggsRemaining: Int
    let incubationHours: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, slot
        case rareEggsRemaining = "rare_eggs_remaining"
        case incubationHours = "incubation_hours"
    }
}

struct NameChickenResponse: Codable {
    let success: Bool
    let message: String
    let slot: ChickenSlot
}

struct ChickenActionResponse: Codable {
    let success: Bool
    let message: String
    let action: String
    let stat: String
    let gained: Int
    let newValue: Int
    let goldSpent: Int
    let slot: ChickenSlot
    
    enum CodingKeys: String, CodingKey {
        case success, message, action, stat, gained
        case newValue = "new_value"
        case goldSpent = "gold_spent"
        case slot
    }
}

struct CollectEggsResponse: Codable {
    let success: Bool
    let message: String
    let slot: ChickenSlot
    let eggsCollected: Int
    let meatGained: Int
    let rareEggsGained: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, slot
        case eggsCollected = "eggs_collected"
        case meatGained = "meat_gained"
        case rareEggsGained = "rare_eggs_gained"
    }
}
