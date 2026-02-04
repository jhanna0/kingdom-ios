import SwiftUI

// MARK: - Grind Wheat Game

struct GrindWheatGameView: View {
    let onComplete: (Int) -> Void
    
    // Wheat grains to tap and collect
    @State private var wheatStalks: [WheatStalk] = []
    @State private var looseGrains: [LooseGrain] = []
    @State private var grainsInMill: Int = 0
    @State private var flourAmount: CGFloat = 0
    @State private var millRotation: Double = 0
    @State private var lastDragAngle: CGFloat = 0
    @State private var totalRotations: CGFloat = 0
    @State private var gamePhase: GrindPhase = .harvest
    @State private var grindingParticles: [GrindParticle] = []
    
    let flourNeeded: CGFloat = 100
    let grainsPerStalk = 5  // 12 stalks total = 60 grains for 4 loaves
    
    enum GrindPhase {
        case harvest  // Tap wheat to get grains
        case grind    // Rotate mill to make flour
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Instructions
            Text(gamePhase == .harvest ? "Tap wheat stalks to collect grains" : "Spin the millstone clockwise!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)
                .padding(.horizontal, 20)
            
            // Progress bar
            VStack(spacing: 4) {
                HStack {
                    Text("Flour")
                        .font(FontStyles.labelSmall)
                    Spacer()
                    Text("\(Int(flourAmount))%")
                        .font(FontStyles.labelBold)
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal, 20)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                            .frame(width: geo.size.width * min(1, flourAmount / flourNeeded))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
                .padding(.horizontal, 20)
            }
            
            // Game area
            GeometryReader { geo in
                ZStack {
                    // Background - wheat field or mill area
                    if gamePhase == .harvest {
                        // Wheat field
                        wheatFieldView(geo: geo)
                    } else {
                        // Mill grinding area
                        millGrindingView(geo: geo)
                    }
                }
            }
            .frame(maxHeight: 450)
            
            // Bottom status
            HStack(spacing: 20) {
                // Grains collected
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.7, blue: 0.4))
                        .frame(width: 20, height: 20)
                    Text("\(grainsInMill) grains")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                )
                
                if gamePhase == .harvest && grainsInMill >= 15 {
                    Button {
                        withAnimation(.spring()) {
                            gamePhase = .grind
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Start Grinding!")
                        }
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(
                        Capsule()
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            setupGame()
        }
    }
    
    // MARK: - Wheat Field View
    
    private func wheatFieldView(geo: GeometryProxy) -> some View {
        ZStack {
            // Field background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.6, green: 0.75, blue: 0.4), Color(red: 0.5, green: 0.65, blue: 0.3)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
                .padding(.horizontal, 20)
            
            // Wheat stalks
            ForEach(wheatStalks) { stalk in
                WheatStalkView(stalk: stalk, onTap: {
                    harvestStalk(stalk, geo: geo)
                })
                .position(stalk.position)
            }
            
            // Loose grains falling
            ForEach(looseGrains) { grain in
                Circle()
                    .fill(Color(red: 0.85, green: 0.7, blue: 0.4))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(red: 0.6, green: 0.5, blue: 0.3), lineWidth: 1))
                    .position(grain.position)
                    .opacity(grain.opacity)
            }
            
            // Collection basket at bottom
            VStack(spacing: 0) {
                Spacer()
                
                ZStack {
                    // Basket
                    Ellipse()
                        .fill(Color(red: 0.6, green: 0.45, blue: 0.3))
                        .frame(width: 120, height: 50)
                    
                    // Grains in basket
                    ForEach(0..<min(grainsInMill, 20), id: \.self) { i in
                        Circle()
                            .fill(Color(red: 0.85, green: 0.7, blue: 0.4))
                            .frame(width: 8, height: 8)
                            .offset(
                                x: CGFloat.random(in: -40...40),
                                y: CGFloat.random(in: -10...10)
                            )
                    }
                    
                    Ellipse()
                        .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 4)
                        .frame(width: 120, height: 50)
                }
                .offset(y: -30)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Mill Grinding View
    
    private func millGrindingView(geo: GeometryProxy) -> some View {
        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - 20)
        
        return ZStack {
            // Mill background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.75, green: 0.68, blue: 0.58))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
                .padding(.horizontal, 20)
            
            // Flour bowl below
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.7, green: 0.65, blue: 0.58))
                    .frame(width: 150, height: 60)
                
                // Flour in bowl
                Ellipse()
                    .fill(Color(white: 0.95))
                    .frame(
                        width: 130 * min(1, flourAmount / flourNeeded),
                        height: 45 * min(1, flourAmount / flourNeeded)
                    )
                
                Ellipse()
                    .stroke(Color(red: 0.5, green: 0.45, blue: 0.4), lineWidth: 4)
                    .frame(width: 150, height: 60)
            }
            .position(x: center.x, y: center.y + 130)
            
            // Grinding particles
            ForEach(grindingParticles) { particle in
                Circle()
                    .fill(Color(white: 0.95).opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
            }
            
            // Mill stones
            ZStack {
                // Base stone (stationary)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.55, green: 0.5, blue: 0.45), Color(red: 0.4, green: 0.35, blue: 0.3)],
                            center: .center, startRadius: 0, endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                
                // Grains on the stone
                ForEach(0..<min(grainsInMill, 30), id: \.self) { i in
                    let angle = Double(i) * 0.5 + millRotation * 0.01
                    let radius = 30 + CGFloat(i % 5) * 12
                    Circle()
                        .fill(Color(red: 0.85, green: 0.7, blue: 0.4))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                        .opacity(grainsInMill > 0 ? 1 : 0)
                }
                
                // Top stone (rotating)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.65, green: 0.6, blue: 0.55), Color(red: 0.5, green: 0.45, blue: 0.4)],
                                center: .center, startRadius: 0, endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                    
                    // Grinding grooves
                    ForEach(0..<8, id: \.self) { i in
                        Rectangle()
                            .fill(Color(red: 0.4, green: 0.35, blue: 0.3))
                            .frame(width: 55, height: 4)
                            .offset(x: 30)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                    
                    // Handle
                    ZStack {
                        // Handle base
                        Circle()
                            .fill(Color(red: 0.45, green: 0.35, blue: 0.25))
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        
                        // Handle grip
                        Capsule()
                            .fill(Color(red: 0.55, green: 0.4, blue: 0.25))
                            .frame(width: 20, height: 45)
                            .offset(y: -30)
                            .overlay(
                                Capsule()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 20, height: 45)
                                    .offset(y: -30)
                            )
                    }
                }
                .rotationEffect(.degrees(millRotation))
            }
            .position(center)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleMillRotation(value: value, center: center)
                    }
            )
            
            // Instructions
            Text("Spin clockwise!")
                .font(FontStyles.labelBold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .position(x: center.x, y: 50)
        }
    }
    
    // MARK: - Game Logic
    
    private func setupGame() {
        // Create wheat stalks - 12 stalks for 4 loaves
        let positions: [CGPoint] = [
            CGPoint(x: 80, y: 100),
            CGPoint(x: 180, y: 80),
            CGPoint(x: 280, y: 110),
            CGPoint(x: 120, y: 200),
            CGPoint(x: 220, y: 180),
            CGPoint(x: 320, y: 200),
            CGPoint(x: 70, y: 300),
            CGPoint(x: 170, y: 280),
            CGPoint(x: 270, y: 310),
            CGPoint(x: 350, y: 280),
            CGPoint(x: 130, y: 140),
            CGPoint(x: 310, y: 160),
        ]
        
        wheatStalks = positions.enumerated().map { i, pos in
            WheatStalk(id: UUID(), position: pos, grains: grainsPerStalk, isHarvested: false, swayPhase: Double(i) * 0.5)
        }
    }
    
    private func harvestStalk(_ stalk: WheatStalk, geo: GeometryProxy) {
        guard !stalk.isHarvested else { return }
        
        // Mark as harvested
        if let index = wheatStalks.firstIndex(where: { $0.id == stalk.id }) {
            wheatStalks[index].isHarvested = true
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Spawn grains that fall to basket
        for i in 0..<grainsPerStalk {
            let grain = LooseGrain(
                id: UUID(),
                position: stalk.position,
                velocity: CGPoint(x: CGFloat.random(in: -50...50), y: 0),
                opacity: 1.0
            )
            looseGrains.append(grain)
            
            // Animate grain falling
            let delay = Double(i) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateGrainFall(grain: grain, targetY: geo.size.height - 60)
            }
        }
    }
    
    private func animateGrainFall(grain: LooseGrain, targetY: CGFloat) {
        guard let index = looseGrains.firstIndex(where: { $0.id == grain.id }) else { return }
        
        // Animate to basket
        withAnimation(.easeIn(duration: 0.5)) {
            looseGrains[index].position = CGPoint(
                x: UIScreen.main.bounds.width / 2 + CGFloat.random(in: -40...40),
                y: targetY
            )
        }
        
        // Add to mill after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            grainsInMill += 1
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            
            // Remove grain visual
            if let idx = looseGrains.firstIndex(where: { $0.id == grain.id }) {
                looseGrains.remove(at: idx)
            }
        }
    }
    
    private func handleMillRotation(value: DragGesture.Value, center: CGPoint) {
        guard grainsInMill > 0 else { return }
        
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let angle = atan2(dy, dx)
        
        var delta = angle - lastDragAngle
        lastDragAngle = angle
        
        // Normalize
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        
        // Only count clockwise rotation (positive in this coordinate system)
        if delta > 0 {
            let rotationAmount = delta * 180 / .pi
            millRotation += rotationAmount
            totalRotations += rotationAmount
            
            // MUCH SLOWER flour gain - need ~20-25 seconds of continuous grinding
            // Reduced from 0.05 to 0.008 (over 6x slower)
            let flourGained = rotationAmount * 0.008 * (Double(grainsInMill) / 20.0)
            flourAmount += flourGained
            
            // Consume grains MUCH more slowly - was every 180 degrees, now every 720 degrees (2 full rotations)
            if Int(totalRotations) % 720 == 0 && grainsInMill > 0 {
                grainsInMill = max(0, grainsInMill - 1)
            }
            
            // Spawn flour particles
            if Int(millRotation) % 10 == 0 {
                spawnGrindParticle(near: center)
            }
            
            // Haptic
            if Int(millRotation) % 30 == 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            // Check win
            if flourAmount >= flourNeeded {
                finishGame()
            }
        }
    }
    
    private func spawnGrindParticle(near center: CGPoint) {
        let particle = GrindParticle(
            id: UUID(),
            position: CGPoint(
                x: center.x + CGFloat.random(in: -30...30),
                y: center.y + 80
            ),
            size: CGFloat.random(in: 3...8),
            opacity: 1.0
        )
        grindingParticles.append(particle)
        
        // Animate particle falling
        if let index = grindingParticles.firstIndex(where: { $0.id == particle.id }) {
            withAnimation(.easeIn(duration: 0.6)) {
                grindingParticles[index].position.y += 60
                grindingParticles[index].opacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                grindingParticles.removeAll { $0.id == particle.id }
            }
        }
    }
    
    private func finishGame() {
        let score = Int(min(100, flourAmount))
        onComplete(score)
    }
}

// MARK: - Supporting Types

struct WheatStalk: Identifiable {
    let id: UUID
    var position: CGPoint
    var grains: Int
    var isHarvested: Bool
    var swayPhase: Double
}

struct WheatStalkView: View {
    let stalk: WheatStalk
    let onTap: () -> Void
    
    @State private var sway: Double = 0
    
    var body: some View {
        ZStack {
            if !stalk.isHarvested {
                // Stalk
                Capsule()
                    .fill(Color(red: 0.7, green: 0.6, blue: 0.3))
                    .frame(width: 4, height: 60)
                    .offset(y: 15)
                
                // Wheat head
                VStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Ellipse()
                            .fill(Color(red: 0.85, green: 0.7, blue: 0.4))
                            .frame(width: 12 - CGFloat(i) * 1.5, height: 8)
                            .offset(x: CGFloat(i % 2 == 0 ? -3 : 3))
                    }
                }
                .offset(y: -20)
            } else {
                // Harvested stalk (just stem)
                Capsule()
                    .fill(Color(red: 0.6, green: 0.5, blue: 0.3))
                    .frame(width: 3, height: 40)
                    .offset(y: 25)
            }
        }
        .rotationEffect(.degrees(sin(sway + stalk.swayPhase) * 5))
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                sway = .pi * 2
            }
        }
        .onTapGesture {
            if !stalk.isHarvested {
                onTap()
            }
        }
    }
}

struct LooseGrain: Identifiable {
    let id: UUID
    var position: CGPoint
    var velocity: CGPoint
    var opacity: Double
}

struct GrindParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

#Preview {
    GrindWheatGameView(onComplete: { _ in })
}
