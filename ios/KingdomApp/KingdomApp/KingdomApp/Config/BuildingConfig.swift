import SwiftUI

/// SINGLE SOURCE OF TRUTH for all building types
struct BuildingConfig {
    let type: String
    let displayName: String
    let icon: String
    let color: Color
    
    static let all: [String: BuildingConfig] = [
        "wall": BuildingConfig(
            type: "wall",
            displayName: "Walls",
            icon: "rectangle.stack.fill",
            color: Color(red: 0.42, green: 0.58, blue: 0.60) // Steel blue (defensive)
        ),
        "vault": BuildingConfig(
            type: "vault",
            displayName: "Vault",
            icon: "lock.shield.fill",
            color: KingdomTheme.Colors.imperialGold // Gold (treasury)
        ),
        "mine": BuildingConfig(
            type: "mine",
            displayName: "Mine",
            icon: "mountain.2.fill",
            color: Color(red: 0.55, green: 0.45, blue: 0.35) // Brown (mining)
        ),
        "market": BuildingConfig(
            type: "market",
            displayName: "Market",
            icon: "cart.fill",
            color: KingdomTheme.Colors.royalEmerald // Green (commerce)
        ),
        "farm": BuildingConfig(
            type: "farm",
            displayName: "Farm",
            icon: "leaf.fill",
            color: Color(red: 0.55, green: 0.60, blue: 0.45) // Sage green (agriculture)
        ),
        "education": BuildingConfig(
            type: "education",
            displayName: "Education",
            icon: "book.fill",
            color: KingdomTheme.Colors.royalPurple // Purple (learning)
        )
    ]
    
    /// Get config for a building type - FULLY DYNAMIC with fallback
    static func get(_ type: String) -> BuildingConfig {
        return all[type] ?? BuildingConfig(
            type: type,
            displayName: type.capitalized,
            icon: "building.2.fill",
            color: KingdomTheme.Colors.inkMedium
        )
    }
}

