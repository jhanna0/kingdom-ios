import Foundation

// MARK: - Coup Join Response

struct CoupJoinResponse: Codable {
    let success: Bool
    let message: String
    let side: String
    let attackerCount: Int
    let defenderCount: Int
    
    enum CodingKeys: String, CodingKey {
        case success, message, side
        case attackerCount = "attacker_count"
        case defenderCount = "defender_count"
    }
}

