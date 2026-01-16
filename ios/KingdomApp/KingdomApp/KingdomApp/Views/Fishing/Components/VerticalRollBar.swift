import SwiftUI

// MARK: - Vertical Roll Bar
// A vertical probability bar for the fishing minigame
// Shows drop table segments stacked vertically (common at bottom, rare at top)

struct VerticalRollBar: View {
    let items: [FishingDropTableItem]
    let slots: [String: Int]
    let markerValue: Int  // 1-100, where the marker sits
    let showMarker: Bool
    let markerIcon: String
    
    // Animation state
    @State private var animatedMarkerValue: Int = 0
    
    private var total: Int {
        slots.values.reduce(0, +)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background (always visible)
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.territoryNeutral7)
                
                // Segments (bottom to top = common to rare)
                VStack(spacing: 0) {
                    ForEach(items.reversed(), id: \.key) { item in
                        let count = slots[item.key] ?? 0
                        let frac = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                        
                        Rectangle()
                            .fill(themeColor(item.color))
                            .frame(height: max(0, geo.size.height * frac))
                            .animation(.easeInOut(duration: 0.5), value: count)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 3)
                )
                
                // Marker
                if showMarker {
                    let markerY = geo.size.height * (1 - CGFloat(animatedMarkerValue) / 100.0)
                    
                    HStack(spacing: 0) {
                        // Line extending left
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 12, height: 3)
                            .shadow(color: .black, radius: 1, x: 0, y: 1)
                        
                        // Icon
                        Image(systemName: markerIcon)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                    }
                    .position(x: geo.size.width / 2 + 8, y: markerY)
                }
            }
        }
        .onChange(of: markerValue) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedMarkerValue = newValue
            }
        }
        .onAppear {
            animatedMarkerValue = markerValue
        }
    }
    
    /// Map theme color name to actual Color
    private func themeColor(_ name: String) -> Color {
        switch name.lowercased() {
        // Buttons
        case "buttonprimary": return KingdomTheme.Colors.buttonPrimary
        case "buttonsecondary": return KingdomTheme.Colors.buttonSecondary
        case "buttonsuccess": return KingdomTheme.Colors.buttonSuccess
        case "buttondanger": return KingdomTheme.Colors.buttonDanger
        case "buttonwarning": return KingdomTheme.Colors.buttonWarning
        
        // Ink
        case "inkdark": return KingdomTheme.Colors.inkDark
        case "inkmedium": return KingdomTheme.Colors.inkMedium
        case "inklight": return KingdomTheme.Colors.inkLight
        
        // Gold
        case "gold": return KingdomTheme.Colors.gold
        case "goldlight": return KingdomTheme.Colors.goldLight
        
        // Royal
        case "royalpurple": return KingdomTheme.Colors.royalPurple
        case "regalpurple": return KingdomTheme.Colors.regalPurple
        case "royalblue": return KingdomTheme.Colors.royalBlue
        case "royalemerald": return KingdomTheme.Colors.royalEmerald
        
        // Territory (aquatic colors!)
        case "territoryallied": return KingdomTheme.Colors.territoryAllied
        case "territoryneutral0": return KingdomTheme.Colors.territoryNeutral0
        case "territoryneutral1": return KingdomTheme.Colors.territoryNeutral1
        case "territoryneutral3": return KingdomTheme.Colors.territoryNeutral3
        case "territoryneutral7": return KingdomTheme.Colors.territoryNeutral7
        
        // Disabled
        case "disabled": return KingdomTheme.Colors.disabled
        
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Animated Vertical Roll Bar
// Self-contained animation for the master roll reveal

struct AnimatedVerticalRollBar: View {
    let items: [FishingDropTableItem]
    let slots: [String: Int]
    let finalValue: Int
    let markerIcon: String
    let shouldAnimate: Bool
    let onAnimationComplete: () -> Void
    
    @State private var displayValue: Int = 0
    @State private var showMarker: Bool = false
    @State private var hasStartedAnimation: Bool = false
    
    var body: some View {
        VerticalRollBar(
            items: items,
            slots: slots,
            markerValue: displayValue,
            showMarker: showMarker,
            markerIcon: markerIcon
        )
        .task(id: shouldAnimate) {
            guard shouldAnimate, !hasStartedAnimation else { return }
            hasStartedAnimation = true
            await runAnimation()
        }
        .onChange(of: shouldAnimate) { _, newValue in
            // Reset animation state when shouldAnimate becomes false
            if !newValue {
                hasStartedAnimation = false
            }
        }
        .onChange(of: finalValue) { _, newValue in
            if newValue == 0 {
                showMarker = false
                displayValue = 0
                hasStartedAnimation = false
            }
        }
    }
    
    @MainActor
    private func runAnimation() async {
        // Build animation path: sweep up, then settle to final
        var positions = Array(stride(from: 1, through: 100, by: 3))
        if finalValue < 100 {
            positions.append(contentsOf: stride(from: 97, through: max(1, finalValue), by: -3))
        }
        if positions.last != finalValue {
            positions.append(finalValue)
        }
        
        showMarker = true
        
        for pos in positions {
            displayValue = pos
            try? await Task.sleep(nanoseconds: 30_000_000)  // 30ms per step
        }
        
        displayValue = finalValue
        onAnimationComplete()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Cast bar
        VStack {
            Text("CAST").font(.caption).bold()
            VerticalRollBar(
                items: [
                    FishingDropTableItem(key: "no_bite", icon: "xmark", name: "Nothing", color: "inkMedium"),
                    FishingDropTableItem(key: "minnow", icon: "fish.fill", name: "Minnow", color: "disabled"),
                    FishingDropTableItem(key: "bass", icon: "fish.fill", name: "Bass", color: "territoryNeutral1"),
                    FishingDropTableItem(key: "salmon", icon: "fish.fill", name: "Salmon", color: "territoryAllied"),
                    FishingDropTableItem(key: "catfish", icon: "fish.fill", name: "Catfish", color: "royalBlue"),
                    FishingDropTableItem(key: "legendary_carp", icon: "fish.fill", name: "Legend", color: "gold"),
                ],
                slots: ["no_bite": 25, "minnow": 30, "bass": 25, "salmon": 12, "catfish": 6, "legendary_carp": 2],
                markerValue: 65,
                showMarker: true,
                markerIcon: "water.waves"
            )
            .frame(width: 50, height: 300)
        }
        
        // Reel bar
        VStack {
            Text("REEL").font(.caption).bold()
            VerticalRollBar(
                items: [
                    FishingDropTableItem(key: "escaped", icon: "arrow.uturn.backward", name: "Escaped", color: "buttonDanger"),
                    FishingDropTableItem(key: "caught", icon: "checkmark.circle.fill", name: "Caught!", color: "buttonSuccess"),
                ],
                slots: ["escaped": 30, "caught": 70],
                markerValue: 40,
                showMarker: true,
                markerIcon: "arrow.up"
            )
            .frame(width: 50, height: 200)
        }
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
