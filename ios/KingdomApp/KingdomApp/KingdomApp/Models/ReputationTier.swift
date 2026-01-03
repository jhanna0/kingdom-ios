import SwiftUI

/// Reputation tier helper with display properties
/// Uses TierManager as single source of truth for tier data
enum ReputationTier: Int {
    case stranger = 1
    case resident = 2
    case citizen = 3
    case notable = 4
    case champion = 5
    case legendary = 6
    
    private var tierManager: TierManager { TierManager.shared }
    
    var displayName: String {
        tierManager.reputationTierName(self.rawValue)
    }
    
    var icon: String {
        tierManager.reputationTierIcon(self.rawValue)
    }
    
    var color: Color {
        // Colors stay in frontend since they're UI-specific
        switch self {
        case .stranger: return .gray
        case .resident: return KingdomTheme.Colors.buttonPrimary
        case .citizen: return .blue
        case .notable: return .purple
        case .champion: return KingdomTheme.Colors.inkMedium
        case .legendary: return .orange
        }
    }
    
    static func from(reputation: Int) -> ReputationTier {
        let tier = TierManager.shared.reputationTierFor(reputation: reputation)
        return ReputationTier(rawValue: tier) ?? .stranger
    }
}

