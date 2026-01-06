import SwiftUI

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
            
            // Resource grid (3 columns)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    InventoryGridItem(
                        icon: "g.circle.fill",
                        iconColor: KingdomTheme.Colors.goldLight,
                        name: "Gold",
                        amount: player.gold
                    )
                    
                    InventoryGridItem(
                        icon: "cube.fill",
                        iconColor: .gray,
                        name: "Iron",
                        amount: player.iron
                    )
                    
                    InventoryGridItem(
                        icon: "cube.fill",
                        iconColor: .blue,
                        name: "Steel",
                        amount: player.steel
                    )
                }
                
                HStack(spacing: 10) {
                    InventoryGridItem(
                        icon: "tree.fill",
                        iconColor: .brown,
                        name: "Wood",
                        amount: player.wood
                    )
                    
                    Spacer()
                        .frame(maxWidth: .infinity)
                    
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
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .brutalistBadge(
                        backgroundColor: iconColor,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                // Amount badge with Runescape-style colors
                Text(amount.abbreviated())
                    .font(FontStyles.labelBadge)
                    .foregroundColor(amount.valueColor())
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 22)
                    .brutalistBadge(
                        backgroundColor: .black,
                        cornerRadius: 11,
                        shadowOffset: 1,
                        borderWidth: 1.5
                    )
                    .offset(x: 6, y: -6)
            }
            
            Text(name)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
    }
}

