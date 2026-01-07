import SwiftUI

// MARK: - Resource Item Model (used for rendering)

struct ResourceItem: Identifiable {
    let id: String  // Resource key (gold, iron, etc.)
    let displayName: String
    let icon: String
    let color: Color
    let amount: Int
}

// MARK: - Color Mapping Helper

private func mapColorName(_ colorName: String) -> Color {
    switch colorName.lowercased() {
    case "goldlight": return KingdomTheme.Colors.goldLight
    case "gray": return .gray
    case "blue": return .blue
    case "brown": return .brown
    case "green": return .green
    case "red": return .red
    case "purple": return .purple
    case "orange": return .orange
    case "cyan": return .cyan
    case "yellow": return .yellow
    default: return KingdomTheme.Colors.inkMedium
    }
}

// MARK: - Number Formatting Helper

extension Int {
    /// Format large numbers with k/m suffix (e.g., 4540 → "4.5k")
    func abbreviated() -> String {
        let number = Double(self)
        
        if abs(number) >= 1_000_000 {
            let formatted = number / 1_000_000
            return String(format: "%.1fm", formatted).replacingOccurrences(of: ".0", with: "")
        } else if abs(number) >= 1_000 {
            let formatted = number / 1_000
            return String(format: "%.1fk", formatted).replacingOccurrences(of: ".0", with: "")
        } else {
            return "\(self)"
        }
    }
    
    /// Runescape-style value colors 🔥
    func valueColor() -> Color {
        switch self {
        case 0..<100:
            return .gray  // Trash tier
        case 100..<1_000:
            return .white  // Common
        case 1_000..<10_000:
            return Color(red: 1.0, green: 1.0, blue: 0.0)  // Yellow - getting interesting
        case 10_000..<100_000:
            return Color(red: 1.0, green: 0.65, blue: 0.0)  // Orange - nice stack!
        case 100_000..<1_000_000:
            return Color(red: 0.0, green: 1.0, blue: 0.0)  // Green - rich!
        default:
            return Color(red: 0.0, green: 1.0, blue: 1.0)  // Cyan - STACKED
        }
    }
}

// MARK: - Inventory Card View

struct InventoryCardView: View {
    @ObservedObject var player: Player
    
    /// FULLY DYNAMIC: Get resources from backend player state - NO HARDCODING!
    /// Backend sends complete resource data with amounts - frontend just renders
    /// Adding new resources only requires backend changes, NO iOS REDEPLOYMENT!
    private var resources: [ResourceItem] {
        // Use dynamic resources_data from backend (preferred)
        if !player.resourcesData.isEmpty {
            return player.resourcesData.map { resource in
                ResourceItem(
                    id: resource.key,
                    displayName: resource.displayName,
                    icon: resource.icon,
                    color: mapColorName(resource.colorName),
                    amount: resource.amount
                )
            }
        }
        
        // Fallback to TierManager + KeyPath mapping (legacy, for old API responses)
        return TierManager.shared.getAllResources().compactMap { item in
            guard let amount = getPlayerAmountFallback(for: item.key) else { return nil }
            return ResourceItem(
                id: item.key,
                displayName: item.info.displayName,
                icon: item.info.icon,
                color: mapColorName(item.info.colorName),
                amount: amount
            )
        }
    }
    
    /// FALLBACK ONLY: Get resource amount using KeyPath mapping
    /// Used only when resources_data is not available (old API responses)
    private func getPlayerAmountFallback(for resourceKey: String) -> Int? {
        let resourceMap: [String: KeyPath<Player, Int>] = [
            "gold": \.gold,
            "iron": \.iron,
            "steel": \.steel,
            "wood": \.wood
        ]
        guard let keyPath = resourceMap[resourceKey] else { return nil }
        return player[keyPath: keyPath]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "backpack.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Inventory")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // DYNAMIC: Render all resources from backend config
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(resources) { resource in
                        InventoryGridItem(
                            icon: resource.icon,
                            iconColor: resource.color,
                            name: resource.displayName,
                            amount: resource.amount
                        )
                    }
                    
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Inventory Grid Item

struct InventoryGridItem: View {
    let icon: String
    let iconColor: Color
    let name: String
    let amount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Icon background
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .brutalistBadge(
                        backgroundColor: iconColor,
                        cornerRadius: 8,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                // Amount badge with Runescape-style colors
                Text(amount.abbreviated())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(amount.valueColor())
                    .padding(.horizontal, 4)
                    .frame(minWidth: 18, minHeight: 18)
                    .brutalistBadge(
                        backgroundColor: .black,
                        cornerRadius: 9,
                        shadowOffset: 1,
                        borderWidth: 1.5
                    )
                    .offset(x: 4, y: -4)
            }
            
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
    }
}

