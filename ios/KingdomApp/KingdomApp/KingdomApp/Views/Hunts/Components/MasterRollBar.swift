import SwiftUI

/// Self-contained master roll bar with built-in animation
struct MasterRollBar: View {
    let items: [DropTableItemConfig]
    let slots: [String: Int]
    let finalValue: Int
    let markerIcon: String
    let shouldAnimate: Bool
    let onAnimationComplete: () -> Void
    
    @State private var displayValue: Int = 0
    @State private var showMarker: Bool = false
    @State private var hasStartedAnimation: Bool = false
    
    private var total: Int {
        slots.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(showMarker ? "ROLLING" : "ODDS")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geo in
                ZStack {
                    // Segments
                    HStack(spacing: 0) {
                        ForEach(items, id: \.key) { item in
                            let count = slots[item.key] ?? 0
                            let frac = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                            if frac > 0.01 {
                                Rectangle()
                                    .fill(Color(hex: item.color) ?? KingdomTheme.Colors.inkMedium)
                                    .frame(width: geo.size.width * frac)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                    
                    // Marker - only show during/after animation
                    if showMarker {
                        let markerX = geo.size.width * CGFloat(max(1, displayValue)) / 100.0
                        
                        Image(systemName: markerIcon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                            .position(x: markerX, y: 10)
                    }
                }
            }
            .frame(height: 20)
        }
        .task(id: shouldAnimate) {
            print("[MasterRollBar] .task fired - shouldAnimate=\(shouldAnimate), hasStartedAnimation=\(hasStartedAnimation), finalValue=\(finalValue)")
            guard shouldAnimate, !hasStartedAnimation else {
                print("[MasterRollBar] .task guard failed, not starting animation")
                return
            }
            hasStartedAnimation = true
            print("[MasterRollBar] Starting animation now")
            await runAnimation()
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
        print("[MasterRollBar] Starting animation, finalValue=\(finalValue)")
        
        // Build positions: 1→100 then back to finalValue
        var positions = Array(stride(from: 1, through: 100, by: 2))
        if finalValue < 100 {
            positions.append(contentsOf: stride(from: 98, through: max(1, finalValue), by: -2))
        }
        if positions.last != finalValue {
            positions.append(finalValue)
        }
        
        showMarker = true
        
        for pos in positions {
            displayValue = pos
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        
        displayValue = finalValue
        print("[MasterRollBar] Animation complete, calling onAnimationComplete")
        onAnimationComplete()
    }
}
