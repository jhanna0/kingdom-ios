import Foundation
import SwiftUI

// MARK: - Gather Action Response

struct GatherResponse: Codable {
    let success: Bool
    let resourceType: String
    let resourceName: String
    let resourceIcon: String
    let tier: String              // "black", "brown", "green", "gold"
    let amount: Int               // 0, 1, 2, or 3
    let color: String             // Theme color name (e.g. "buttonSuccess")
    let message: String
    let newTotal: Int
    let haptic: String?           // "medium", "heavy", or null
    
    enum CodingKeys: String, CodingKey {
        case success
        case resourceType = "resource_type"
        case resourceName = "resource_name"
        case resourceIcon = "resource_icon"
        case tier, amount, color, message, haptic
        case newTotal = "new_total"
    }
    
    /// Get SwiftUI Color from theme color name
    var tierColor: Color {
        KingdomTheme.Colors.color(fromThemeName: color)
    }
}

// MARK: - Gather Config Response

struct GatherConfigResponse: Codable {
    let resources: [GatherResourceConfig]
    let tiers: [GatherTierConfig]
}

struct GatherResourceConfig: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
}

struct GatherTierConfig: Codable, Identifiable {
    var id: String { tier }
    
    let tier: String
    let name: String
    let amount: Int
    let color: String
    let probability: Int
    
    var tierColor: Color {
        Color(hex: color) ?? .gray
    }
}
