import SwiftUI

// MARK: - Knead Game

struct KneadGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var doughStretch: CGPoint = .zero
    @State private var isStretching = false
    @State private var foldCount: Int = 0
    @State private var glutenLevel: CGFloat = 0
    
    let targetFolds = 35
    let stretchThreshold: CGFloat = 60  // Lowered from 80 since dough moves slower now (harder to reach same distance)
    
    var body: some View {
        VStack(spacing: 0) {
            // INSTRUCTION
            Text("Pull outward, release to fold back!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // PROGRESS BAR
            VStack(spacing: 4) {
                HStack {
                    Text("Gluten Development")
                    Spacer()
                    Text("\(foldCount)/\(targetFolds) folds")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * glutenLevel)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // GAME AREA
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                
                ZStack {
                    // Work surface
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.82, green: 0.72, blue: 0.58), Color(red: 0.75, green: 0.65, blue: 0.50)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 20)
                    
                    // Flour dusting
                    ForEach(0..<20, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: CGFloat.random(in: 2...5))
                            .position(
                                x: center.x + CGFloat.random(in: -140...140),
                                y: center.y + CGFloat.random(in: -140...140)
                            )
                    }
                    
                    // Direction arrows hint
                    if foldCount < 2 {
                        ForEach([0, 90, 180, 270], id: \.self) { angle in
                            Image(systemName: "arrow.right")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .rotationEffect(.degrees(Double(angle)))
                                .offset(
                                    x: cos(CGFloat(angle) * .pi / 180) * 100,
                                    y: sin(CGFloat(angle) * .pi / 180) * 100
                                )
                                .position(center)
                        }
                    }
                    
                    // Stretchable dough
                    stretchableDough(center: center)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    handleStretch(value: value, center: center)
                                }
                                .onEnded { value in
                                    handleStretchEnd(value: value, center: center)
                                }
                        )
                }
            }
            .frame(maxHeight: 450)
            
            // BOTTOM
            Text("Pull and release to fold the dough")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private func stretchableDough(center: CGPoint) -> some View {
        let stretchAmount = hypot(doughStretch.x, doughStretch.y)
        let stretchAngle = atan2(doughStretch.y, doughStretch.x)
        
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 150 + stretchAmount * 0.3, height: 50)
                .offset(y: 70)
                .position(center)
            
            // Main dough - moves less because it's heavy
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.88, blue: 0.78),
                            Color(red: 0.88, green: 0.78, blue: 0.65)
                        ],
                        center: .center, startRadius: 0, endRadius: 80
                    )
                )
                .frame(
                    width: 130 + stretchAmount * 0.5,
                    height: 110 - stretchAmount * 0.12
                )
                .rotationEffect(.radians(Double(stretchAngle)))
                .position(
                    x: center.x + doughStretch.x * 0.15,  // Reduced from 0.3 - dough stays more centered
                    y: center.y + doughStretch.y * 0.15
                )
            
            // Stretched tail - shorter and thicker (dough doesn't stretch thin easily)
            if stretchAmount > 35 {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.85, blue: 0.73).opacity(0.9),
                                Color(red: 0.95, green: 0.88, blue: 0.78)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: stretchAmount * 0.35, height: 50 - stretchAmount * 0.08)
                    .rotationEffect(.radians(Double(stretchAngle)))
                    .position(
                        x: center.x + doughStretch.x * 0.4,
                        y: center.y + doughStretch.y * 0.4
                    )
            }
            
            // Gluten strands when stretched (fewer, thicker - dough is more cohesive)
            if glutenLevel > 0.4 && stretchAmount > 45 {
                ForEach(0..<Int(glutenLevel * 4), id: \.self) { i in
                    Capsule()
                        .fill(Color(red: 0.88, green: 0.80, blue: 0.68).opacity(0.7))
                        .frame(width: stretchAmount * 0.3, height: 3)
                        .rotationEffect(.radians(Double(stretchAngle)))
                        .offset(y: CGFloat(i - Int(glutenLevel * 2)) * 8)
                        .position(
                            x: center.x + doughStretch.x * 0.3,
                            y: center.y + doughStretch.y * 0.3
                        )
                }
            }
        }
    }
    
    private func handleStretch(value: DragGesture.Value, center: CGPoint) {
        isStretching = true
        
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        
        // Dough is HEAVY and STICKY - moves much slower
        // Scale down movement to 40% and slow spring response
        let maxStretch: CGFloat = 120
        let dist = hypot(dx, dy)
        
        // Dough resists being stretched - only moves 40% of the distance
        let resistance: CGFloat = 0.4
        let targetX = dx * resistance
        let targetY = dy * resistance
        
        // Much slower response time (was 0.08, now 0.25) and more damping
        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
            let constrainedDist = hypot(targetX, targetY)
            if constrainedDist > maxStretch {
                doughStretch = CGPoint(x: targetX * maxStretch / constrainedDist, y: targetY * maxStretch / constrainedDist)
            } else {
                doughStretch = CGPoint(x: targetX, y: targetY)
            }
        }
        
        // Haptic based on stretch
        if Int(dist) % 30 == 0 && dist > 40 {
            HapticService.shared.lightImpact()
        }
    }
    
    private func handleStretchEnd(value: DragGesture.Value, center: CGPoint) {
        let stretchDist = hypot(doughStretch.x, doughStretch.y)
        
        if stretchDist > stretchThreshold {
            // Successful fold!
            foldCount += 1
            glutenLevel = min(1.0, CGFloat(foldCount) / CGFloat(targetFolds))
            
            HapticService.shared.heavyImpact()
            
            // Check completion
            if foldCount >= targetFolds {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete(85 + Int.random(in: 0...15))
                }
            }
        }
        
        // Dough snaps back slowly and heavily
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            doughStretch = .zero
            isStretching = false
        }
    }
}

#Preview {
    KneadGameView(onComplete: { _ in })
}
