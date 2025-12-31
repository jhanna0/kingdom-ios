import Foundation

// MARK: - Activity Log Entry

struct ActivityLogEntry: Codable, Identifiable {
    let id: Int
    let userId: Int
    let actionType: String
    let actionCategory: String
    let description: String
    let kingdomId: String?
    let kingdomName: String?
    let amount: Int?
    let visibility: String
    let createdAt: String
    
    // Optional user info (for friend feeds)
    let username: String?
    let displayName: String?
    let userLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount, visibility, username
        case userId = "user_id"
        case actionType = "action_type"
        case actionCategory = "action_category"
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case createdAt = "created_at"
        case displayName = "display_name"
        case userLevel = "user_level"
    }
}

// MARK: - Activity Response

struct PlayerActivityResponse: Codable {
    let success: Bool
    let total: Int
    let activities: [ActivityLogEntry]
}

// MARK: - Activity Extensions

extension ActivityLogEntry {
    var icon: String {
        switch actionType {
        case "build": return "hammer.fill"
        case "vote": return "checkmark.seal.fill"
        case "invasion": return "shield.lefthalf.filled"
        case "property_purchase": return "house.fill"
        case "property_upgrade": return "arrow.up.forward.app.fill"
        case "train": return "figure.strengthtraining.traditional"
        case "travel": return "figure.walk"
        case "checkin": return "location.circle.fill"
        default: return "circle.fill"
        }
    }
    
    var color: String {
        switch actionCategory {
        case "kingdom": return "blue"
        case "combat": return "red"
        case "economy": return "yellow"
        case "social": return "green"
        default: return "gray"
        }
    }
    
    var timeAgo: String {
        // Parse Python datetime format: "2025-12-30T01:33:19.756588"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        guard let date = formatter.date(from: createdAt) else {
            // Fallback: try without fractional seconds
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            guard let date = formatter.date(from: createdAt) else {
                return "recently"
            }
            
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            return formatTimeInterval(timeInterval)
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        return formatTimeInterval(timeInterval)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

