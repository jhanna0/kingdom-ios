import Foundation

// MARK: - Patrol Action Response

struct PatrolActionResponse: Codable {
    let success: Bool
    let message: String
    let expiresAt: Date
    let rewards: ActionRewards?
    
    enum CodingKeys: String, CodingKey {
        case success, message, rewards
        case expiresAt = "expires_at"
    }
}

