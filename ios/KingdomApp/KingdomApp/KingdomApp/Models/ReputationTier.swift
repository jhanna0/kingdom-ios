import SwiftUI

/// Reputation tier helper with display properties
enum ReputationTier {
    case stranger
    case resident
    case citizen
    case notable
    case champion
    case legendary
    
    var displayName: String {
        switch self {
        case .stranger: return "Stranger"
        case .resident: return "Resident"
        case .citizen: return "Citizen"
        case .notable: return "Notable"
        case .champion: return "Champion"
        case .legendary: return "Legendary"
        }
    }
    
    var icon: String {
        switch self {
        case .stranger: return "person.fill"
        case .resident: return "house.fill"
        case .citizen: return "person.2.fill"
        case .notable: return "star.fill"
        case .champion: return "crown.fill"
        case .legendary: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .stranger: return .gray
        case .resident: return KingdomTheme.Colors.buttonPrimary
        case .citizen: return .blue
        case .notable: return .purple
        case .champion: return KingdomTheme.Colors.gold
        case .legendary: return .orange
        }
    }
    
    static func from(reputation: Int) -> ReputationTier {
        if reputation >= 1000 { return .legendary }
        if reputation >= 500 { return .champion }
        if reputation >= 300 { return .notable }
        if reputation >= 150 { return .citizen }
        if reputation >= 50 { return .resident }
        return .stranger
    }
}

