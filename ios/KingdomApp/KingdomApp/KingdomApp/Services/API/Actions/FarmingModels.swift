import Foundation

// MARK: - Farm Action Response

struct FarmActionResponse: Codable {
    let success: Bool
    let message: String
    let nextFarmAvailableAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case nextFarmAvailableAt = "next_farm_available_at"
    }
}

