import Foundation

/// Convert backend action names to proper display format (present continuous tense)
func actionNameToDisplayName(_ actionName: String?) -> String {
    guard let name = actionName?.lowercased() else { return "another action" }
    switch name {
    case "patrol": return "Patrolling"
    case "work": return "Working"
    case "scout": return "Scouting"
    case "sabotage": return "Sabotaging"
    case "training": return "Training"
    default: return name.capitalized
    }
}



