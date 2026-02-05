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
    
    // Display info from backend
    let iconName: String?
    let colorName: String?
    
    // Subscriber customization (server-driven themes for activity card)
    let subscriberTheme: APIThemeData?
    let selectedTitle: APITitleData?
    
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
        case iconName = "icon"
        case colorName = "color"
        case subscriberTheme = "subscriber_theme"
        case selectedTitle = "selected_title"
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
        // Use backend icon if provided
        if let backendIcon = iconName, !backendIcon.isEmpty {
            return backendIcon
        }
        
        // Fallback to local mapping
        return ActionIconHelper.icon(for: actionType)
    }
    
    var color: Color {
        // Use backend color if provided
        if let backendColor = colorName, !backendColor.isEmpty {
            return KingdomTheme.Colors.color(fromThemeName: backendColor)
        }
        
        // Fallback to local mapping
        return ActionIconHelper.actionColor(for: actionType)
    }
    
    var timeAgo: String {
        TimeFormatter.timeAgo(from: createdAt)
    }
}

