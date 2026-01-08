import Foundation

// MARK: - Global Cooldown (Legacy)

struct GlobalCooldown: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let blockingAction: String?
    let blockingSlot: String?  // NEW: Which slot is blocking
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case blockingAction = "blocking_action"
        case blockingSlot = "blocking_slot"
    }
}

// MARK: - Slot Cooldown (NEW: Parallel Actions)

/// Per-slot cooldown status - enables parallel actions!
struct SlotCooldown: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let blockingAction: String?
    let blockingSlot: String?
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case blockingAction = "blocking_action"
        case blockingSlot = "blocking_slot"
    }
}

// MARK: - Slot Info (NEW: Backend-driven slot rendering)

/// Slot definition from backend - frontend renders these dynamically!
/// NO hardcoding of slot names, icons, or colors allowed.
struct SlotInfo: Codable, Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let colorTheme: String
    let displayOrder: Int
    let description: String?
    let location: String  // "home", "enemy", or "any"
    let contentType: String  // "actions", "training_contracts", "building_contracts" - tells frontend which renderer to use
    let actions: [String]  // Action keys that belong to this slot
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case icon
        case colorTheme = "color_theme"
        case displayOrder = "display_order"
        case description
        case location
        case contentType = "content_type"
        case actions
    }
}

// MARK: - Expected Reward

struct ExpectedReward: Codable {
    let gold: Int?
    let goldGross: Int?
    let goldBonusMultiplier: Double?
    let buildingSkill: Int?
    let reputation: Int?
    let experience: Int?
    
    enum CodingKeys: String, CodingKey {
        case gold
        case goldGross = "gold_gross"
        case goldBonusMultiplier = "gold_bonus_multiplier"
        case buildingSkill = "building_skill"
        case reputation
        case experience
    }
}

// MARK: - Action Status

struct ActionStatus: Codable {
    let ready: Bool
    let secondsRemaining: Int
    let cooldownMinutes: Double?
    let isPatrolling: Bool?
    let activePatrollers: Int?
    let currentStat: Int?
    let sessionsAvailable: Int?
    let purchaseCost: Int?
    let expectedReward: ExpectedReward?
    
    // Action metadata (ALL from API - frontend is dumb renderer!)
    let unlocked: Bool?
    let actionType: String?
    let requirementsMet: Bool?
    let requirementDescription: String?
    let title: String?
    let icon: String?
    let description: String?
    let category: String?
    let themeColor: String?  // Maps to KingdomTheme.Colors
    let displayOrder: Int?
    let endpoint: String?  // FULLY DYNAMIC: Backend provides complete endpoint with all params
    let slot: String?  // NEW: Which slot this action belongs to (building, economy, security, etc)
    
    enum CodingKeys: String, CodingKey {
        case ready
        case secondsRemaining = "seconds_remaining"
        case cooldownMinutes = "cooldown_minutes"
        case isPatrolling = "is_patrolling"
        case activePatrollers = "active_patrollers"
        case currentStat = "current_stat"
        case sessionsAvailable = "sessions_available"
        case purchaseCost = "purchase_cost"
        case expectedReward = "expected_reward"
        case unlocked
        case actionType = "action_type"
        case requirementsMet = "requirements_met"
        case requirementDescription = "requirement_description"
        case title, icon, description, category
        case themeColor = "theme_color"
        case displayOrder = "display_order"
        case endpoint
        case slot  // NEW
    }
}

// MARK: - All Action Status (Combined Response)

struct AllActionStatus: Codable {
    // NEW: Parallel actions support
    let parallelActionsEnabled: Bool?
    let slotCooldowns: [String: SlotCooldown]?  // NEW: Per-slot cooldowns
    let slots: [SlotInfo]?  // NEW: Slot definitions from backend (display names, icons, colors, order)
    
    // Legacy global cooldown (kept for backward compatibility)
    let globalCooldown: GlobalCooldown
    let actions: [String: ActionStatus]  // DYNAMIC - API decides what actions are available
    
    // Legacy fields for backward compatibility
    let work: ActionStatus
    let patrol: ActionStatus
    let farm: ActionStatus
    let sabotage: ActionStatus
    let scout: ActionStatus
    let training: ActionStatus
    let crafting: ActionStatus
    let vaultHeist: ActionStatus?
    
    let trainingContracts: [TrainingContract]
    let trainingCosts: TrainingCosts
    let craftingQueue: [CraftingContract]
    let craftingCosts: CraftingCosts
    let propertyUpgradeContracts: [PropertyUpgradeContract]?
    let contracts: [APIContract]
    
    // Helper to check if parallel actions are enabled
    var supportsParallelActions: Bool {
        return parallelActionsEnabled == true && slotCooldowns != nil
    }
    
    // Helper to get cooldown for a specific slot
    func cooldown(for slot: String) -> SlotCooldown? {
        return slotCooldowns?[slot]
    }
    
    enum CodingKeys: String, CodingKey {
        case parallelActionsEnabled = "parallel_actions_enabled"
        case slotCooldowns = "slot_cooldowns"
        case slots  // NEW: Slot definitions from backend
        case globalCooldown = "global_cooldown"
        case actions
        case work, patrol, farm, sabotage, scout, training, crafting, contracts
        case vaultHeist = "vault_heist"
        case trainingContracts = "training_contracts"
        case trainingCosts = "training_costs"
        case craftingQueue = "crafting_queue"
        case craftingCosts = "crafting_costs"
        case propertyUpgradeContracts = "property_upgrade_contracts"
    }
    
    // Helper to get slots for a specific location
    func slotsForLocation(_ location: String) -> [SlotInfo] {
        guard let allSlots = slots else { return [] }
        return allSlots
            .filter { $0.location == "any" || $0.location == location }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    // Get home kingdom slots (beneficial actions)
    var homeSlots: [SlotInfo] {
        slotsForLocation("home")
    }
    
    // Get enemy kingdom slots (hostile actions)
    var enemySlots: [SlotInfo] {
        slotsForLocation("enemy")
    }
}

// MARK: - Action Rewards

struct ActionRewards: Codable {
    let gold: Int?
    let reputation: Int?
    let experience: Int?
    let iron: Int?
}

// MARK: - Generic Action Response (Dynamic Actions)

/// Universal response model for all dynamic actions
/// Backend always returns: success, message, rewards (optional)
struct GenericActionResponse: Codable {
    let success: Bool
    let message: String
    let rewards: ActionRewards?
    
    // Optional fields that some actions may include
    let nextActionAvailableAt: Date?
    let nextFarmAvailableAt: Date?
    let nextWorkAvailableAt: Date?
    let nextScoutAvailableAt: Date?
    let nextSabotageAvailableAt: Date?
    let nextTrainAvailableAt: Date?
    let expiresAt: Date?
    
    // Incident-specific fields (for infiltration actions)
    let triggered: Bool?           // Was an incident triggered?
    let successChance: Double?     // What was the calculated success chance?
    let roll: Double?              // What did they roll?
    let intelligenceTier: Int?     // Attacker's intelligence tier
    let activePatrols: Int?        // How many enemy patrols were active
    let incident: IncidentInfo?    // Incident data if triggered
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case nextActionAvailableAt = "next_action_available_at"
        case nextFarmAvailableAt = "next_farm_available_at"
        case nextWorkAvailableAt = "next_work_available_at"
        case nextScoutAvailableAt = "next_scout_available_at"
        case nextSabotageAvailableAt = "next_sabotage_available_at"
        case nextTrainAvailableAt = "next_train_available_at"
        case expiresAt = "expires_at"
        case triggered
        case successChance = "success_chance"
        case roll
        case intelligenceTier = "intelligence_tier"
        case activePatrols = "active_patrols"
        case incident
    }
    
    /// Check if this is an infiltration response
    var isInfiltrationResponse: Bool {
        return triggered != nil || successChance != nil
    }
}

// MARK: - Incident Info (for infiltration responses)

struct IncidentInfo: Codable {
    let incidentId: String
    let attackerKingdomId: String
    let defenderKingdomId: String
    let status: String
    let attackerTier: Int
    let slots: [String: Int]?
    let probabilities: [String: Double]?
    let timeRemainingSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case incidentId = "incident_id"
        case attackerKingdomId = "attacker_kingdom_id"
        case defenderKingdomId = "defender_kingdom_id"
        case status
        case attackerTier = "attacker_tier"
        case slots
        case probabilities
        case timeRemainingSeconds = "time_remaining_seconds"
    }
}



