import Foundation

// MARK: - Kingdom Models

/// Building upgrade cost - included in each building
struct APIBuildingUpgradeCost: Codable {
    let actions_required: Int
    let construction_cost: Int
    let can_afford: Bool
}

/// Resource cost per action - FULLY DYNAMIC from backend
struct APIPerActionCost: Codable {
    let resource: String  // e.g. "wood", "iron", "stone"
    let amount: Int  // Amount required per action
}

/// Info for a single building tier - FULLY DYNAMIC from backend
struct APIBuildingTierInfo: Codable {
    let tier: Int
    let name: String  // e.g. "Wooden Palisade", "Stone Wall"
    let benefit: String  // e.g. "+2 defenders", "20% protected"
    let description: String  // e.g. "Basic wooden wall"
    let per_action_costs: [APIPerActionCost]?  // Resource costs per action (wood, iron, etc.)
}

/// Click action for a building - DYNAMIC from backend
struct APIBuildingClickAction: Codable {
    let type: String  // e.g. "gathering", "market", "townhall"
    let resource: String?  // For gathering: "wood", "iron"
    let exhausted: Bool?  // True if daily limit reached (for gathering)
    let exhausted_message: String?  // Message to show when exhausted
}

/// Catch-up info for players who joined after building was constructed
struct APIBuildingCatchupInfo: Codable {
    let needs_catchup: Bool  // True if player must complete catch-up to use this building
    let can_use: Bool  // True if player can use this building
    let actions_required: Int  // Total catch-up actions required
    let actions_completed: Int  // Completed catch-up actions
    let actions_remaining: Int  // Remaining catch-up actions
}

/// DYNAMIC Building data from backend - includes metadata, upgrade costs, and tier info
/// Frontend iterates this array - NO HARDCODING required!
struct APIBuildingData: Codable {
    let type: String  // e.g. "wall", "vault", "mine"
    let display_name: String  // e.g. "Walls", "Vault"
    let icon: String  // SF Symbol name
    let color: String  // Hex color code
    let category: String  // "economy", "defense", "civic"
    let description: String  // Building description
    let level: Int  // Current building level
    let max_level: Int  // Maximum level
    let sort_order: Int?  // Display order (lower = first)
    let upgrade_cost: APIBuildingUpgradeCost?  // Cost to upgrade (nil if at max)
    
    // Click action - what happens when building is tapped (nil = not clickable)
    let click_action: APIBuildingClickAction?
    
    // Catch-up info - for players who joined after building was constructed
    // If needs_catchup is true, player must complete catch-up work before using
    let catchup: APIBuildingCatchupInfo?
    
    // Current tier info
    let tier_name: String  // Name of current tier (e.g. "Stone Wall")
    let tier_benefit: String  // Benefit of current tier (e.g. "+4 defenders")
    
    // All tiers info - for detail view to show all levels
    let all_tiers: [APIBuildingTierInfo]
}

/// Full kingdom response from /kingdoms/{id} endpoint
/// FULLY DYNAMIC - buildings array contains all building data with upgrade costs
struct APIKingdom: Codable {
    let id: String
    let name: String
    let ruler_id: Int?  // PostgreSQL auto-generated integer
    let ruler_name: String?
    let city_boundary_osm_id: String?
    let population: Int
    let level: Int
    let treasury_gold: Int
    let checked_in_players: Int
    let active_citizens: Int?  // Optional for backwards compatibility
    
    // DYNAMIC BUILDINGS - Array with full metadata + upgrade costs from backend
    // Frontend should iterate this array - NO HARDCODING!
    let buildings: [APIBuildingData]?
    
    let tax_rate: Int
    let travel_fee: Int
    let subject_reward_rate: Int
    let allies: [String]?
    let enemies: [String]?
    let created_at: String?
    let updated_at: String?
}

struct APIKingdomSimple: Codable {
    let id: String
    let name: String
    let ruler_id: Int?  // PostgreSQL auto-generated integer
    let location: LocationData?
    let population: Int
    let level: Int
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - City Boundary Models

/// Alliance info when kingdoms are allied
struct AllianceInfo: Codable {
    let id: Int
    let days_remaining: Int
    let expires_at: String?
}

/// Active alliance info for hometown display
struct ActiveAllianceData: Codable, Identifiable {
    let id: Int
    let allied_kingdom_id: String
    let allied_kingdom_name: String
    let allied_ruler_name: String?
    let days_remaining: Int
    let expires_at: String?
}

/// Kingdom data attached to a city boundary response
/// FULLY DYNAMIC - buildings array contains all building data with upgrade costs
struct CityKingdomData: Codable {
    let id: String
    let ruler_id: Int?  // PostgreSQL auto-generated integer
    let ruler_name: String?
    let level: Int
    let population: Int
    let active_citizens: Int?  // Optional for backwards compatibility
    let treasury_gold: Int
    
    // DYNAMIC BUILDINGS - Array with full metadata + upgrade costs from backend
    // Frontend should iterate this array - NO HARDCODING!
    let buildings: [APIBuildingData]?
    
    let travel_fee: Int
    let can_claim: Bool  // Backend determines if current user can claim
    let can_declare_war: Bool  // Backend determines if current user can declare war
    let can_form_alliance: Bool  // Backend determines if current user can form alliance
    let is_allied: Bool  // True if allied with any of player's kingdoms
    let is_enemy: Bool  // True if at war with any of player's kingdoms
    let alliance_info: AllianceInfo?  // Details about alliance if is_allied is true
    let allies: [String]?  // Kingdom IDs of allied kingdoms
    let enemies: [String]?  // Kingdom IDs of enemy kingdoms
    let active_alliances: [ActiveAllianceData]?  // All active alliances (only for player's hometown)
    
    // Coup eligibility
    let can_stage_coup: Bool?  // Backend determines if current user can stage coup
    let coup_ineligibility_reason: String?  // Why user can't stage coup (e.g., "Need T3 leadership")
    
    // War state - Backend is source of truth!
    let is_at_war: Bool?  // True if there's an active battle (coup or invasion)
    
    // Active coup/battle in this kingdom (if any)
    let active_coup: ActiveCoupData?
}

/// Active battle data for map badge and quick access (coups or invasions)
struct ActiveCoupData: Codable, Identifiable {
    let id: Int
    let kingdom_id: String
    let kingdom_name: String
    let initiator_name: String
    let status: String  // 'pledge' or 'battle'
    let time_remaining_seconds: Int
    let attacker_count: Int
    let defender_count: Int
    let user_side: String?  // 'attackers', 'defenders', or nil
    let can_pledge: Bool
    let pledge_end_time: String?  // ISO timestamp - when pledge phase ends
    let battle_type: String?  // "coup" or "invasion" - NEW: distinguish battle types
    
    /// Whether this is an invasion (vs a coup)
    var isInvasion: Bool {
        return battle_type == "invasion"
    }
    
    /// Whether this is a coup (vs an invasion)
    var isCoup: Bool {
        return battle_type == nil || battle_type == "coup"
    }
    
    /// Formatted time remaining
    var timeRemainingFormatted: String {
        let hours = time_remaining_seconds / 3600
        let minutes = (time_remaining_seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            let seconds = time_remaining_seconds % 60
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(time_remaining_seconds)s"
        }
    }
    
    /// Parse pledge_end_time to Date for scheduling notifications
    var pledgeEndDate: Date? {
        guard let timeString = pledge_end_time else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timeString) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timeString)
    }
}

struct CityBoundaryResponse: Codable {
    let osm_id: String
    let name: String
    let admin_level: Int
    let center_lat: Double
    let center_lon: Double
    let boundary: [[Double]]  // Array of [lat, lon] pairs (may be empty for neighbors)
    let radius_meters: Double
    let cached: Bool
    let is_current: Bool  // True if user is currently inside this city
    let kingdom: CityKingdomData?  // NULL if unclaimed
    
    // Default is_current to false for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        osm_id = try container.decode(String.self, forKey: .osm_id)
        name = try container.decode(String.self, forKey: .name)
        admin_level = try container.decode(Int.self, forKey: .admin_level)
        center_lat = try container.decode(Double.self, forKey: .center_lat)
        center_lon = try container.decode(Double.self, forKey: .center_lon)
        boundary = try container.decode([[Double]].self, forKey: .boundary)
        radius_meters = try container.decode(Double.self, forKey: .radius_meters)
        cached = try container.decode(Bool.self, forKey: .cached)
        is_current = try container.decodeIfPresent(Bool.self, forKey: .is_current) ?? false
        kingdom = try container.decodeIfPresent(CityKingdomData.self, forKey: .kingdom)
    }
}

/// Lazy-loaded boundary response (for filling in neighbor polygons)
struct BoundaryResponse: Codable {
    let osm_id: String
    let name: String
    let boundary: [[Double]]  // Array of [lat, lon] pairs
    let radius_meters: Double
    let from_cache: Bool  // True if from DB, false if fetched from OSM
}

// MARK: - Check-in Models

struct CheckInRequest: Codable {
    let city_boundary_osm_id: String  // Kingdom OSM ID
    let latitude: Double
    let longitude: Double
}

struct CheckInResponse: Codable {
    let success: Bool
    let message: String
    let rewards: CheckInRewards
}

// Note: CheckInRewards is defined in PlayerModels.swift

// MARK: - Conquest Models

struct ConquestResponse: Codable {
    let success: Bool
    let message: String
    let kingdom: ConquestKingdomInfo?
    let rewards: ConquestRewards?
    let cost: Int?
}

struct ConquestKingdomInfo: Codable {
    let id: String
    let name: String
    let level: Int
    let population: Int
}

struct ConquestRewards: Codable {
    let experience: Int
    let reputation: Int
}

// MARK: - My Kingdoms Response

struct MyKingdomResponse: Codable, Identifiable {
    let id: String
    let name: String
    let treasury_gold: Int
    let checked_in_players: Int
}

