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
    
    @State private var animatedMarkerValue: Int = 0
    
    private var total: Int {
        slots.values.reduce(0, +)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background - soft water color
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                KingdomTheme.Colors.territoryNeutral7.opacity(0.6),
                                KingdomTheme.Colors.territoryNeutral7
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Segments (bottom to top = common to rare)
                VStack(spacing: 0) {
                    ForEach(items.reversed(), id: \.key) { item in
                        let count = slots[item.key] ?? 0
                        let frac = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                        
                        Rectangle()
                            .fill(themeColor(item.color))
                            .frame(height: max(0, geo.size.height * frac))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 3)
                )
                
                // Marker
                if showMarker {
                    let markerY = geo.size.height * (1 - CGFloat(animatedMarkerValue) / 100.0)
                    
                    HStack(spacing: 0) {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 20, height: 5)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        Image(systemName: markerIcon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 1)
                    }
                    .position(x: geo.size.width / 2 + 14, y: markerY)
                }
            }
        }
        .onChange(of: markerValue) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) {
                animatedMarkerValue = newValue
            }
        }
        .onAppear {
            animatedMarkerValue = markerValue
        }
    }
    
    private func themeColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "territoryallied": return KingdomTheme.Colors.territoryAllied
        case "territoryneutral0": return KingdomTheme.Colors.territoryNeutral0
        case "territoryneutral1": return KingdomTheme.Colors.territoryNeutral1
        case "territoryneutral3": return KingdomTheme.Colors.territoryNeutral3
        case "territoryneutral7": return KingdomTheme.Colors.territoryNeutral7
        case "inkmedium": return KingdomTheme.Colors.inkMedium
        case "inklight": return KingdomTheme.Colors.inkLight
        case "disabled": return KingdomTheme.Colors.disabled
        case "royalblue": return KingdomTheme.Colors.royalBlue
        case "gold": return KingdomTheme.Colors.gold
        case "buttonsuccess": return KingdomTheme.Colors.buttonSuccess
        case "buttondanger": return KingdomTheme.Colors.buttonDanger
        default:
            return KingdomTheme.Colors.color(fromThemeName: name)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
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
