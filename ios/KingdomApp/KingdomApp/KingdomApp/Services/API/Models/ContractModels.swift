import Foundation

// MARK: - Contract Models

struct APIContract: Codable {
    let id: String
    let kingdom_id: String
    let kingdom_name: String
    let building_type: String
    let building_level: Int
    let base_population: Int
    let base_hours_required: Double
    let work_started_at: String?
    let reward_pool: Int
    let workers: [String]
    let created_by: String
    let created_at: String
    let completed_at: String?
    let status: String  // open, in_progress, completed, cancelled
}

struct ContractCreateRequest: Codable {
    let kingdom_id: String
    let kingdom_name: String
    let building_type: String
    let building_level: Int
    let reward_pool: Int
    let base_population: Int
}

struct ContractJoinResponse: Codable {
    let success: Bool
    let message: String
    let contract: APIContract
}

struct ContractCompleteResponse: Codable {
    let success: Bool
    let message: String
    let rewards_distributed: Int
    let workers_paid: Int
}

