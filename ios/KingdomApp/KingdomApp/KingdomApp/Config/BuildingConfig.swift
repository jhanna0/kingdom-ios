import SwiftUI

/// FULLY DYNAMIC - NO HARDCODED BUILDINGS!
/// All building data comes from backend via Kingdom.buildingMetadata
/// This is just a helper for SwiftUI rendering
struct BuildingConfig {
    let type: String
    let displayName: String
    let icon: String
    let color: Color
    
    /// Convert BuildingMetadata from backend to BuildingConfig
    static func from(metadata: BuildingMetadata) -> BuildingConfig {
        return BuildingConfig(
            type: metadata.type,
            displayName: metadata.displayName,
            icon: metadata.icon,
            color: Color(hex: metadata.colorHex) ?? KingdomTheme.Colors.inkMedium
        )
    }
    
    /// Emergency fallback if backend metadata is missing (should never happen)
    static func fallback(_ type: String) -> BuildingConfig {
        return BuildingConfig(
            type: type,
            displayName: type.capitalized,
            icon: "building.2.fill",
            color: KingdomTheme.Colors.inkMedium
        )
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize Color from hex string (e.g. "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

