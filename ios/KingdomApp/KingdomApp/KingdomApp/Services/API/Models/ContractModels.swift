import Foundation

// MARK: - Contract Models

struct APIContract: Codable {
    let id: Int
    let kingdom_id: String
    let kingdom_name: String
    let building_type: String
    let building_level: Int
    let base_population: Int
    let base_hours_required: Double
    let work_started_at: String?
    
    // Action-based system
    let total_actions_required: Int
    let actions_completed: Int
    let action_contributions: [String: Int]
    
    // Costs & Rewards
    let construction_cost: Int?  // Optional - only for kingdom building contracts
    let reward_pool: Int
    let created_by: Int  // Changed from String to Int - backend uses integer user ID
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
    let total_actions: Int
    let contributors: Int
}

