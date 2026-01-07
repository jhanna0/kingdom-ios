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
            icon: "eye.fill",
            color: KingdomTheme.Colors.royalEmerald
        ),
        "science": SkillConfig(
            type: "science",
            displayName: "Science",
            icon: "flask.fill",
            color: Color(red: 0.4, green: 0.7, blue: 1.0)  // Light blue
        ),
        "faith": SkillConfig(
            type: "faith",
            displayName: "Faith",
            icon: "hands.sparkles.fill",
            color: Color(red: 0.65, green: 0.55, blue: 0.95)  // Deep lavender - holy vibes with better visibility
        ),
        "philosophy": SkillConfig(
            type: "philosophy",
            displayName: "Philosophy",
            icon: "book.fill",
            color: Color(red: 0.6, green: 0.5, blue: 0.35)  // Warm bronze - wisdom and ancient knowledge
        ),
        "merchant": SkillConfig(
            type: "merchant",
            displayName: "Merchant",
            icon: "dollarsign.circle.fill",
            color: Color(red: 0.85, green: 0.65, blue: 0.2)  // Rich amber gold - wealth and trade
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

