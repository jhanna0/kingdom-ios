import SwiftUI

/// SINGLE SOURCE OF TRUTH for all skill types
/// No more scattered switch statements - ONE place to define everything
struct SkillConfig {
    let type: String
    let displayName: String
    let icon: String
    let color: Color
    
    static let all: [String: SkillConfig] = [
        "attack": SkillConfig(
            type: "attack",
            displayName: "Attack",
            icon: "bolt.fill",
            color: KingdomTheme.Colors.buttonDanger
        ),
        "defense": SkillConfig(
            type: "defense",
            displayName: "Defense",
            icon: "shield.fill",
            color: KingdomTheme.Colors.royalBlue
        ),
        "leadership": SkillConfig(
            type: "leadership",
            displayName: "Leadership",
            icon: "crown.fill",
            color: KingdomTheme.Colors.royalPurple
        ),
        "building": SkillConfig(
            type: "building",
            displayName: "Building",
            icon: "hammer.fill",
            color: KingdomTheme.Colors.imperialGold
        ),
        "intelligence": SkillConfig(
            type: "intelligence",
            displayName: "Intelligence",
            icon: "brain.head.profile",
            color: KingdomTheme.Colors.royalEmerald
        )
    ]
    
    /// Get config for a skill type - FULLY DYNAMIC with fallback
    static func get(_ type: String) -> SkillConfig {
        return all[type] ?? SkillConfig(
            type: type,
            displayName: type.capitalized,
            icon: "figure.strengthtraining.traditional",
            color: KingdomTheme.Colors.inkMedium
        )
    }
}

