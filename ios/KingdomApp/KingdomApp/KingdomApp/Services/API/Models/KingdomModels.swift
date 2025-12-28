import Foundation

// MARK: - Kingdom Models

struct APIKingdom: Codable {
    let id: String
    let name: String
    let ruler_id: String?
    let ruler_name: String?
    let latitude: Double?
    let longitude: Double?
    let city_boundary_osm_id: String?
    let population: Int
    let level: Int
    let treasury_gold: Int
    let checked_in_players: Int
    let wall_level: Int
    let vault_level: Int
    let mine_level: Int
    let market_level: Int
    let tax_rate: Int
    let subject_reward_rate: Int
    let allies: [String]?
    let enemies: [String]?
    let created_at: String?
    let updated_at: String?
}

struct APIKingdomSimple: Codable {
    let id: String
    let name: String
    let ruler_id: String?
    let location: LocationData?
    let population: Int
    let level: Int
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - City Boundary Models

struct CityBoundaryResponse: Codable {
    let osm_id: String
    let name: String
    let admin_level: Int
    let center_lat: Double
    let center_lon: Double
    let boundary: [[Double]]  // Array of [lat, lon] pairs
    let radius_meters: Double
    let cached: Bool
}

// MARK: - Check-in Models

struct CheckInRequest: Codable {
    let player_id: String
    let kingdom_id: String
    let latitude: Double
    let longitude: Double
}

struct CheckInResponse: Codable {
    let success: Bool
    let message: String
    let rewards: CheckInRewards
}

struct CheckInRewards: Codable {
    let gold: Int
    let experience: Int
}

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

