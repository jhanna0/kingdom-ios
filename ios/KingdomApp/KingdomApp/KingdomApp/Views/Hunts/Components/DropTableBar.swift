import SwiftUI

// MARK: - Drop Table Item Display (local view model)
struct DropTableItemDisplay {
    let key: String
    let icon: String
    let name: String
    let color: Color
}

// MARK: - Drop Table Bar
// Universal drop table visualization - FULLY DATA-DRIVEN FROM BACKEND!
// Shows probability segments in a horizontal bar with brutalist styling
// NOW WITH INLINE MASTER ROLL ANIMATION - no overlay needed!

struct DropTableBar: View {
    let title: String
    let slots: [String: Int]
    let itemConfigs: [DropTableItemConfig]  // FROM BACKEND - no hardcoding!
    
    // Master roll animation state (optional - only used during resolve)
    var masterRollValue: Int = 0
    var isAnimatingMasterRoll: Bool = false
    
    private var totalSlots: Int {
        slots.values.reduce(0, +)
    }
    
    /// Convert backend configs to display items with slot counts
    /// Order is preserved from backend - that's the left-to-right order on the bar!
    private var orderedItems: [DropTableItemDisplay] {
        itemConfigs.map { config in
            DropTableItemDisplay(
                key: config.key,
                icon: config.icon,
                name: config.name,
                color: Color(hex: config.color) ?? .gray
            )
        }
    }
    
    private func slotsForKey(_ key: String) -> Int {
        slots[key] ?? 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Horizontal bar with segments - brutalist styling - FULL WIDTH
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
                            let slotCount = slotsForKey(item.key)
                            let fraction = totalSlots > 0 ? CGFloat(slotCount) / CGFloat(totalSlots) : 0
                            if fraction > 0.01 {
                                DropTableSegment(icon: item.icon, color: item.color, fraction: fraction)
                                    .frame(width: geo.size.width * fraction)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 3)
                    )
                    
                    // MASTER ROLL CROSSHAIRS - animates across the bar!
                    if isAnimatingMasterRoll || masterRollValue > 0 {
                        let markerX = geo.size.width * CGFloat(masterRollValue) / 100.0
                        
                        Image(systemName: "scope")
                            .font(.system(size: 44, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                            .position(x: markerX, y: 25)
                    }
                }
            }
            .frame(height: 50)
            // NO internal padding - bar should be full width of container
            
            // Legend with icons - FROM BACKEND DATA!
            HStack(spacing: 6) {
                ForEach(orderedItems, id: \.key) { item in
                    let slotCount = slotsForKey(item.key)
                    let percent = totalSlots > 0 ? Int(Double(slotCount) / Double(totalSlots) * 100) : 0
                    HStack(spacing: 2) {
                        Text(item.icon)
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
}

// MARK: - Drop Table Segment
struct DropTableSegment: View {
    let icon: String
    let color: Color
    let fraction: CGFloat
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(color)
            
            if fraction > 0.15 {
                Text(icon)
                    .font(.system(size: fraction > 0.3 ? 28 : 20))
            }
        }
    }
}

