import Foundation
import SwiftUI

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
    let details: ActivityDetails?
    
    // Optional user info (for friend feeds)
    let username: String?
    let displayName: String?
    let userLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount, visibility, username, details
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

// MARK: - Activity Details

struct ActivityDetails: Codable {
    // Training-specific
    let trainingType: String?
    let tier: Int?
    let progress: String?
    let completed: Bool?
    
    // Equipment crafting
    let equipmentType: String?
    
    // Can add more fields as needed for other action types
    
    enum CodingKeys: String, CodingKey {
        case trainingType = "training_type"
        case equipmentType = "equipment_type"
        case tier, progress, completed
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
        // For training, use the specific skill icon if available
        if actionType.lowercased() == "train" || actionType.lowercased() == "training" {
            if let trainingType = details?.trainingType {
                return SkillConfig.get(trainingType).icon
            }
        }
        
        // For crafting, use equipment-specific icons
        if actionType.lowercased() == "craft" || actionType.lowercased() == "crafting" {
            if let equipmentType = details?.equipmentType {
                switch equipmentType {
                case "weapon":
                    return "bolt.fill"
                case "armor":
                    return "shield.fill"
                default:
                    break
                }
            }
        }
        
        return ActionIconHelper.icon(for: actionType)
    }
    
    var color: Color {
        // For training, use the specific skill color if available
        if actionType.lowercased() == "train" || actionType.lowercased() == "training" {
            if let trainingType = details?.trainingType {
                return SkillConfig.get(trainingType).color
            }
        }
        
        // For crafting, use equipment-specific colors
        if actionType.lowercased() == "craft" || actionType.lowercased() == "crafting" {
            if let equipmentType = details?.equipmentType {
                switch equipmentType {
                case "weapon":
                    return KingdomTheme.Colors.buttonDanger
                case "armor":
                    return KingdomTheme.Colors.royalBlue
                default:
                    break
                }
            }
        }
        
        return ActionIconHelper.actionColor(for: actionType)
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

