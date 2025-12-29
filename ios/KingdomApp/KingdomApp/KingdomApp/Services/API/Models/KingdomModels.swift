import Foundation

// MARK: - Kingdom Models

struct APIBuildingUpgradeCost: Codable {
    let actions_required: Int
    let suggested_reward: Int
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
    let wall_level: Int
    let vault_level: Int
    let mine_level: Int
    let market_level: Int
    let farm_level: Int
    let education_level: Int
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
    let wall_level: Int
    let vault_level: Int
    let mine_level: Int
    let market_level: Int
    let farm_level: Int
    let education_level: Int
    let travel_fee: Int
}

struct CityBoundaryResponse: Codable {
    let osm_id: String
    let name: String
    let admin_level: Int
    let center_lat: Double
    let center_lon: Double
    let boundary: [[Double]]  // Array of [lat, lon] pairs
    let radius_meters: Double
    let cached: Bool
    let kingdom: CityKingdomData?  // NULL if unclaimed
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

struct MyKingdomResponse: Codable {
    let id: String
    let name: String
    let level: Int
    let population: Int
    let treasury_gold: Int
    let checkins_count: Int
    let became_ruler_at: String?
    let local_reputation: Int
}

