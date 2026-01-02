import SwiftUI

/// Centralized helper for action icons and names across the app
struct ActionIconHelper {
    
    /// Get icon for action type
    static func icon(for actionType: String) -> String {
        switch actionType.lowercased() {
        case "farm", "farming":
            return "leaf.fill"
        case "work", "build":
            return "hammer.fill"
        case "patrol":
            return "eye.fill"
        case "scout", "scouting":
            return "magnifyingglass"
        case "sabotage":
            return "flame.fill"
        case "training", "train":
            return "figure.strengthtraining.traditional"
        case "craft", "crafting":
            return "hammer.fill"
        case "vote":
            return "checkmark.seal.fill"
        case "invasion":
            return "shield.lefthalf.filled"
        case "property_purchase":
            return "house.fill"
        case "property_upgrade":
            return "arrow.up.forward.app.fill"
        case "travel":
            return "figure.walk"
        case "checkin":
            return "location.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    /// Get display name for action type
    static func displayName(for actionType: String) -> String {
        switch actionType.lowercased() {
        case "farm", "farming":
            return "Farm"
        case "work", "build":
            return "Work"
        case "patrol":
            return "Patrol"
        case "scout", "scouting":
            return "Scout"
        case "sabotage":
            return "Sabotage"
        case "training", "train":
            return "Training"
        case "craft", "crafting":
            return "Crafting"
        case "vote":
            return "Vote"
        case "invasion":
            return "Invasion"
        case "property_purchase":
            return "Property Purchase"
        case "property_upgrade":
            return "Property Upgrade"
        case "travel":
            return "Travel"
        case "checkin":
            return "Check In"
        default:
            return actionType.capitalized
        }
    }
    
    /// Get short activity description for action type
    static func activityDescription(for actionType: String) -> String {
        switch actionType.lowercased() {
        case "farm", "farming":
            return "Farmed"
        case "work", "build":
            return "Worked on contract"
        case "patrol":
            return "Patrolled"
        case "scout", "scouting":
            return "Scouted"
        case "sabotage":
            return "Sabotaged"
        case "training", "train":
            return "Trained"
        case "craft", "crafting":
            return "Crafted"
        case "vote":
            return "Voted"
        case "invasion":
            return "Invaded"
        case "property_purchase":
            return "Purchased property"
        case "property_upgrade":
            return "Upgraded property"
        case "travel":
            return "Traveled"
        case "checkin":
            return "Checked in"
        default:
            return actionType.capitalized
        }
    }
    
    /// Get color for action category
    static func color(for category: String) -> Color {
        switch category.lowercased() {
        case "kingdom":
            return KingdomTheme.Colors.buttonPrimary
        case "combat":
            return KingdomTheme.Colors.buttonDanger
        case "economy":
            return KingdomTheme.Colors.inkMedium
        case "social":
            return KingdomTheme.Colors.buttonSuccess
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
    
    /// Get color for specific action type
    static func actionColor(for actionType: String) -> Color {
        switch actionType.lowercased() {
        case "farm", "farming":
            return KingdomTheme.Colors.buttonSuccess // Green
        case "work", "build":
            return KingdomTheme.Colors.inkMedium // Gold
        case "patrol":
            return KingdomTheme.Colors.buttonPrimary // Blue
        case "scout", "scouting":
            return KingdomTheme.Colors.buttonWarning // Orange
        case "sabotage":
            return KingdomTheme.Colors.buttonDanger // Red
        case "training", "train":
            return KingdomTheme.Colors.buttonPrimary // Blue
        case "craft", "crafting":
            return KingdomTheme.Colors.buttonWarning // Orange
        case "vote":
            return KingdomTheme.Colors.buttonPrimary // Blue
        case "invasion":
            return KingdomTheme.Colors.buttonDanger // Red
        case "property_purchase":
            return KingdomTheme.Colors.buttonSuccess // Green
        case "property_upgrade":
            return KingdomTheme.Colors.buttonWarning // Orange
        case "travel":
            return KingdomTheme.Colors.buttonPrimary // Blue
        case "checkin":
            return KingdomTheme.Colors.buttonSuccess // Green
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
}

