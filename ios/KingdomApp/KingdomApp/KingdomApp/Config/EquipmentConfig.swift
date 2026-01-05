import SwiftUI

/// SINGLE SOURCE OF TRUTH for all equipment types
struct EquipmentConfig {
    let type: String
    let displayName: String
    let icon: String
    let color: Color
    
    static let all: [String: EquipmentConfig] = [
        "weapon": EquipmentConfig(
            type: "weapon",
            displayName: "Weapon",
            icon: "bolt.fill",
            color: KingdomTheme.Colors.buttonDanger
        ),
        "armor": EquipmentConfig(
            type: "armor",
            displayName: "Armor",
            icon: "shield.fill",
            color: KingdomTheme.Colors.royalBlue
        )
    ]
    
    /// Get config for an equipment type - FULLY DYNAMIC with fallback
    static func get(_ type: String) -> EquipmentConfig {
        return all[type] ?? EquipmentConfig(
            type: type,
            displayName: type.capitalized,
            icon: "wrench.fill",
            color: KingdomTheme.Colors.inkMedium
        )
    }
}



