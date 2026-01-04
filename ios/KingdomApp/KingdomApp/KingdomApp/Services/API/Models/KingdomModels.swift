import Foundation

// MARK: - Kingdom Models

/// DYNAMIC Building data from backend - includes metadata
struct APIBuildingData: Codable {
    let type: String  // e.g. "wall", "vault", "mine"
    let display_name: String  // e.g. "Walls", "Vault"
    let icon: String  // SF Symbol name
    let color: String  // Hex color code
    let category: String  // "economy", "defense", "civic"
    let description: String  // Building description
    let level: Int  // Current building level
    let max_level: Int  // Maximum level
}

struct APIBuildingUpgradeCost: Codable {
    let actions_required: Int
    let construction_cost: Int
    let can_afford: Bool
}

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
    
    // DYNAMIC BUILDINGS - Array with full metadata from backend
    let buildings: [APIBuildingData]?
    
    // Legacy building levels (kept for backwards compatibility)
    let wall_level: Int
    let vault_level: Int
    let mine_level: Int
    let market_level: Int
    let farm_level: Int
    let education_level: Int
    let lumbermill_level: Int
    
    let tax_rate: Int
    let travel_fee: Int
    let subject_reward_rate: Int
    let allies: [String]?
    let enemies: [String]?
    let created_at: String?
    let updated_at: String?
    
    // Building upgrade costs
    let wall_upgrade_cost: APIBuildingUpgradeCost?
    let vault_upgrade_cost: APIBuildingUpgradeCost?
    let mine_upgrade_cost: APIBuildingUpgradeCost?
    let market_upgrade_cost: APIBuildingUpgradeCost?
    let farm_upgrade_cost: APIBuildingUpgradeCost?
    let education_upgrade_cost: APIBuildingUpgradeCost?
    let lumbermill_upgrade_cost: APIBuildingUpgradeCost?
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

struct CityKingdomData: Codable {
    let id: String
    let ruler_id: Int?  // PostgreSQL auto-generated integer
    let ruler_name: String?
    let level: Int
    let population: Int
    let treasury_gold: Int
    
    // DYNAMIC BUILDINGS - Array with full metadata from backend
    let buildings: [APIBuildingData]?
    
    // Legacy building levels (kept for backwards compatibility)
    let wall_level: Int
    let vault_level: Int
    let mine_level: Int
    let market_level: Int
    let farm_level: Int
    let education_level: Int
    let lumbermill_level: Int?  // Optional for backwards compatibility
    
    let travel_fee: Int
    let can_claim: Bool  // Backend determines if current user can claim
    let can_declare_war: Bool  // Backend determines if current user can declare war
    let can_form_alliance: Bool  // Backend determines if current user can form alliance
    let is_allied: Bool  // True if allied with any of player's kingdoms
    let is_enemy: Bool  // True if at war with any of player's kingdoms
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

