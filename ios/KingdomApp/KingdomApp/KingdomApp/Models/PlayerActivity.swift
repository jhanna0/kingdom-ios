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
    let trainingType: String?
    let equipmentType: String?
    
    enum CodingKeys: String, CodingKey {
        case trainingType = "training_type"
        case equipmentType = "equipment_type"
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
        // For travel fees, show gold coin icon
        if actionType == "travel_fee" {
            return "g.circle.fill"
        }
        
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
        // For travel fees, use gold color
        if actionType == "travel_fee" {
            return KingdomTheme.Colors.imperialGold
        }
        
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
        TimeFormatter.timeAgo(from: createdAt)
    }
}

