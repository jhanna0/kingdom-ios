import Foundation

// MARK: - Kitchen Status Response
// Returned by GET /kitchen/status

struct KitchenStatusResponse: Codable {
    let hasKitchen: Bool
    let kitchenProperty: KitchenPropertyInfo?
    let kitchenRequirement: String?
    let slots: [OvenSlot]
    let wheatCount: Int
    let canLoad: Bool?
    let stats: KitchenStats?
    let config: KitchenUIConfig
    let flavor: KitchenFlavor?
    
    enum CodingKeys: String, CodingKey {
        case hasKitchen = "has_kitchen"
        case kitchenProperty = "kitchen_property"
        case kitchenRequirement = "kitchen_requirement"
        case slots
        case wheatCount = "wheat_count"
        case canLoad = "can_load"
        case stats
        case config
        case flavor
    }
}

struct KitchenPropertyInfo: Codable {
    let id: String
    let kingdomName: String
    let tier: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomName = "kingdom_name"
        case tier
    }
}

struct KitchenStats: Codable {
    let emptySlots: Int
    let baking: Int
    let ready: Int
    let totalLoavesReady: Int
    let totalSlots: Int
    
    enum CodingKeys: String, CodingKey {
        case emptySlots = "empty_slots"
        case baking
        case ready
        case totalLoavesReady = "total_loaves_ready"
        case totalSlots = "total_slots"
    }
}

struct KitchenUIConfig: Codable {
    let emptySlot: OvenSlotUIConfig?
    let bakingSlot: OvenSlotUIConfig?
    let readySlot: OvenSlotUIConfig?
    let oven: OvenSlotUIConfig?
    let bread: OvenSlotUIConfig?
    let bakingHours: Int?
    let loavesPerWheat: Int?
    
    enum CodingKeys: String, CodingKey {
        case emptySlot = "empty_slot"
        case bakingSlot = "baking_slot"
        case readySlot = "ready_slot"
        case oven
        case bread
        case bakingHours = "baking_hours"
        case loavesPerWheat = "loaves_per_wheat"
    }
}

struct OvenSlotUIConfig: Codable {
    let icon: String
    let color: String
    let label: String?
    let description: String?
}

struct KitchenFlavor: Codable {
    let loading: [String]?
    let baking: [String]?
    let ready: [String]?
}

// MARK: - Oven Slot
// Represents a single oven slot with its current state

struct OvenSlot: Codable, Identifiable {
    var id: Int { slotIndex }
    
    let slotIndex: Int
    let status: String  // empty, baking, ready
    let icon: String
    let color: String
    let label: String
    let description: String?
    
    // Baking details
    let wheatUsed: Int?
    let loavesPending: Int?
    
    // Timing (for baking status)
    let startedAt: String?
    let readyAt: String?
    let secondsRemaining: Int?
    let progressPercent: Int?
    
    // Actions
    let canLoad: Bool
    let canCollect: Bool
    
    enum CodingKeys: String, CodingKey {
        case slotIndex = "slot_index"
        case status
        case icon, color, label, description
        case wheatUsed = "wheat_used"
        case loavesPending = "loaves_pending"
        case startedAt = "started_at"
        case readyAt = "ready_at"
        case secondsRemaining = "seconds_remaining"
        case progressPercent = "progress_percent"
        case canLoad = "can_load"
        case canCollect = "can_collect"
    }
    
    // Computed properties for UI
    var isBaking: Bool { status == "baking" }
    var isEmpty: Bool { status == "empty" }
    var isReady: Bool { status == "ready" }
}

// MARK: - Kitchen Action Responses

struct LoadOvenResponse: Codable {
    let success: Bool
    let message: String
    let flavor: String?
    let slot: OvenSlot
    let wheatRemaining: Int
    let readyInSeconds: Int?
    let bakingHours: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message, flavor, slot
        case wheatRemaining = "wheat_remaining"
        case readyInSeconds = "ready_in_seconds"
        case bakingHours = "baking_hours"
    }
}

struct CollectBreadResponse: Codable {
    let success: Bool
    let message: String
    let flavor: String?
    let slot: OvenSlot
    let loavesCollected: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, flavor, slot
        case loavesCollected = "loaves_collected"
    }
}
