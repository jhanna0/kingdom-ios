import SwiftUI

// MARK: - Drop Table Display Configuration
enum DropTableDisplayConfig {
    case creatures(config: HuntConfigResponse?)
    case damage
    case blessing
}

// MARK: - Drop Table Item Display
struct DropTableItemDisplay {
    let icon: String
    let name: String
    let color: Color
}

// MARK: - Drop Table Bar
// Universal drop table visualization used across all hunt phases
// Shows probability segments in a horizontal bar with brutalist styling
// NOW WITH INLINE MASTER ROLL ANIMATION - no overlay needed!

struct DropTableBar: View {
    let title: String
    let slots: [String: Int]
    let displayConfig: DropTableDisplayConfig
    
    // Master roll animation state (optional - only used during resolve)
    var masterRollValue: Int = 0
    var isAnimatingMasterRoll: Bool = false
    
    private var totalSlots: Int {
        slots.values.reduce(0, +)
    }
    
    private var orderedItems: [(key: String, slots: Int, display: DropTableItemDisplay)] {
        switch displayConfig {
        case .creatures(let config):
            let animals = (config?.animals ?? []).sorted { $0.tier < $1.tier }
            return animals.compactMap { animal in
                let slotCount = slots[animal.id] ?? 0
                return (animal.id, slotCount, DropTableItemDisplay(
                    icon: animal.icon,
                    name: animal.name,
                    color: creatureTierColor(animal.tier)
                ))
            }
        case .damage:
            // SOLID colors - no opacity that shows black through!
            return [
                ("miss", slots["miss"] ?? 0, DropTableItemDisplay(icon: "💨", name: "Miss", color: Color(red: 0.7, green: 0.7, blue: 0.7))),
                ("graze", slots["graze"] ?? 0, DropTableItemDisplay(icon: "🩹", name: "Graze", color: Color(red: 0.9, green: 0.6, blue: 0.3))),
                ("hit", slots["hit"] ?? 0, DropTableItemDisplay(icon: "⚔️", name: "Hit", color: Color(red: 0.4, green: 0.7, blue: 0.4))),
                ("crit", slots["crit"] ?? 0, DropTableItemDisplay(icon: "💥", name: "Crit!", color: Color(red: 0.8, green: 0.3, blue: 0.3))),
            ]
        case .blessing:
            // SOLID colors - no opacity that shows black through!
            return [
                ("none", slots["none"] ?? 0, DropTableItemDisplay(icon: "😶", name: "None", color: Color(red: 0.7, green: 0.7, blue: 0.7))),
                ("small", slots["small"] ?? 0, DropTableItemDisplay(icon: "✨", name: "+10%", color: Color(red: 0.4, green: 0.5, blue: 0.8))),
                ("medium", slots["medium"] ?? 0, DropTableItemDisplay(icon: "🌟", name: "+25%", color: Color(red: 0.6, green: 0.4, blue: 0.7))),
                ("large", slots["large"] ?? 0, DropTableItemDisplay(icon: "⚡", name: "+50%", color: Color(red: 0.85, green: 0.7, blue: 0.3))),
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Horizontal bar with segments - brutalist styling
            GeometryReader { geo in
                ZStack {
                    // Offset shadow
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .offset(x: 3, y: 3)
                    
                    // SOLID parchment base - prevents black showing through gaps!
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KingdomTheme.Colors.parchmentLight)
                    
                    HStack(spacing: 0) {
                        ForEach(orderedItems, id: \.key) { item in
                            let fraction = totalSlots > 0 ? CGFloat(item.slots) / CGFloat(totalSlots) : 0
                            if fraction > 0.01 {
                                DropTableSegment(display: item.display, fraction: fraction)
                                    .frame(width: geo.size.width * fraction)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 3)
                    )
                    
                    // MASTER ROLL MARKER - animates across the bar!
                    if isAnimatingMasterRoll || masterRollValue > 0 {
                        let markerX = geo.size.width * CGFloat(masterRollValue) / 100.0
                        
                        VStack(spacing: 0) {
                            // Arrow pointing down
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 20))
                                .foregroundColor(KingdomTheme.Colors.gold)
                            
                            // Vertical line
                            Rectangle()
                                .fill(KingdomTheme.Colors.gold)
                                .frame(width: 3, height: 60)
                        }
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 1, y: 1)
                        .position(x: markerX, y: 25)
                        .animation(
                            isAnimatingMasterRoll ? .linear(duration: 0.03) : .spring(response: 0.5, dampingFraction: 0.6),
                            value: masterRollValue
                        )
                    }
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 16)
            
            // Legend with icons
            HStack(spacing: 6) {
                ForEach(orderedItems, id: \.key) { item in
                    let percent = totalSlots > 0 ? Int(Double(item.slots) / Double(totalSlots) * 100) : 0
                    HStack(spacing: 2) {
                        Text(item.display.icon)
                            .font(.system(size: 14))
                            .opacity(percent > 0 ? 1 : 0.3)
                        Text("\(percent)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(percent > 0 ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium.opacity(0.4))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func creatureTierColor(_ tier: Int) -> Color {
        // SOLID colors - no opacity!
        switch tier {
        case 0: return KingdomTheme.Colors.inkMedium
        case 1: return KingdomTheme.Colors.buttonSuccess
        case 2: return KingdomTheme.Colors.buttonWarning
        case 3: return KingdomTheme.Colors.buttonDanger
        case 4: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Drop Table Segment
struct DropTableSegment: View {
    let display: DropTableItemDisplay
    let fraction: CGFloat
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(display.color)
            
            if fraction > 0.15 {
                Text(display.icon)
                    .font(.system(size: fraction > 0.3 ? 28 : 20))
            }
        }
    }
}
