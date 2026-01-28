import SwiftUI

// MARK: - Floating Number View

private struct FloatingNumberView: View {
    let amount: Int
    let color: Color
    let onComplete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Text("+\(amount)")
            .font(FontStyles.resultMedium)
            .foregroundColor(color)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offset = -80
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete()
                }
            }
    }
}

private struct FloatingNumber: Identifiable {
    let id = UUID()
    let amount: Int
    let color: Color
    let position: CGPoint
}


// MARK: - Fading Path (for drawn trails)

private struct FadingPath: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
}

private struct FadingPathView: View {
    let points: [CGPoint]
    let color: Color
    let onComplete: () -> Void
    
    @State private var opacity: Double = 0.8
    
    var body: some View {
        Path { path in
            guard points.count > 1 else { return }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }
}

// MARK: - Tree Shape (for Wood)

private struct TreeShape: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            // Big thick center trunk
            RoundedRectangle(cornerRadius: 8)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.28, height: h)
                .position(x: w * 0.5, y: h * 0.5)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KingdomTheme.Colors.inkDark, lineWidth: 3)
                        .frame(width: w * 0.28, height: h)
                        .position(x: w * 0.5, y: h * 0.5)
                )
            
            // Branch left top
            RoundedRectangle(cornerRadius: 6)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.35, height: 20)
                .rotationEffect(.degrees(-25))
                .position(x: w * 0.22, y: h * 0.2)
            
            // Branch right top
            RoundedRectangle(cornerRadius: 6)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.35, height: 20)
                .rotationEffect(.degrees(25))
                .position(x: w * 0.78, y: h * 0.2)
            
            // Branch left middle
            RoundedRectangle(cornerRadius: 6)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.32, height: 18)
                .rotationEffect(.degrees(-20))
                .position(x: w * 0.2, y: h * 0.45)
            
            // Branch right middle
            RoundedRectangle(cornerRadius: 6)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.32, height: 18)
                .rotationEffect(.degrees(20))
                .position(x: w * 0.8, y: h * 0.45)
            
            // Branch left bottom
            RoundedRectangle(cornerRadius: 6)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.28, height: 16)
                .rotationEffect(.degrees(-15))
                .position(x: w * 0.22, y: h * 0.7)
            
            // Branch right bottom
            RoundedRectangle(cornerRadius: 6)
                .fill(KingdomTheme.Colors.buttonPrimary)
                .frame(width: w * 0.28, height: 16)
                .rotationEffect(.degrees(15))
                .position(x: w * 0.78, y: h * 0.7)
        }
    }
}

// MARK: - Rock Shape (for Iron/Mining) - Woodcut style

private struct RockShape: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            // Big rock filling the space - using theme grays/browns
            
            // Main rock body
            Path { path in
                path.move(to: CGPoint(x: w * 0.1, y: h * 0.6))
                path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.25))
                path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.05))
                path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.08))
                path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.35))
                path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.7))
                path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.95))
                path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.9))
                path.closeSubpath()
            }
            .fill(KingdomTheme.Colors.disabled)
            
            // Lighter top facet
            Path { path in
                path.move(to: CGPoint(x: w * 0.4, y: h * 0.05))
                path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.08))
                path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.4))
                path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.35))
                path.closeSubpath()
            }
            .fill(KingdomTheme.Colors.parchmentDark)
            
            // Darker bottom facet
            Path { path in
                path.move(to: CGPoint(x: w * 0.1, y: h * 0.6))
                path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.9))
                path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.95))
                path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.6))
                path.closeSubpath()
            }
            .fill(KingdomTheme.Colors.inkMedium.opacity(0.3))
            
            // Crack lines (ore veins)
            Path { path in
                path.move(to: CGPoint(x: w * 0.3, y: h * 0.4))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
                path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.45))
            }
            .stroke(KingdomTheme.Colors.inkMedium, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            
            Path { path in
                path.move(to: CGPoint(x: w * 0.35, y: h * 0.55))
                path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.65))
            }
            .stroke(KingdomTheme.Colors.inkMedium, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            
            // Rock outline
            Path { path in
                path.move(to: CGPoint(x: w * 0.1, y: h * 0.6))
                path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.25))
                path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.05))
                path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.08))
                path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.35))
                path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.7))
                path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.95))
                path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.9))
                path.closeSubpath()
            }
            .stroke(KingdomTheme.Colors.inkDark, lineWidth: 3)
        }
    }
}

// MARK: - Sweetspot Indicator (simple X mark)

private struct SweetspotView: View {
    let position: CGPoint
    let size: CGFloat
    let isHit: Bool?
    
    @State private var scale: CGFloat = 1.0
    
    private var markColor: Color {
        if let hit = isHit {
            return hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        }
        return KingdomTheme.Colors.buttonDanger
    }
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(markColor, lineWidth: 3)
                .frame(width: size, height: size)
            
            // Inner filled circle
            Circle()
                .fill(markColor)
                .frame(width: size * 0.35, height: size * 0.35)
        }
        .scaleEffect(scale)
        .position(position)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
        }
    }
}

// MARK: - Hit Effect

private struct HitEffectView: View {
    let position: CGPoint
    let isSuccess: Bool
    let onComplete: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // Burst lines
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(isSuccess ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.buttonDanger)
                    .frame(width: 4, height: 20)
                    .offset(y: -30 * scale)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            
            // Center burst
            Circle()
                .fill(isSuccess ? KingdomTheme.Colors.gold : KingdomTheme.Colors.error)
                .frame(width: 20, height: 20)
                .scaleEffect(scale)
        }
        .position(position)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 1.5
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onComplete()
            }
        }
    }
}

private struct HitEffect: Identifiable {
    let id = UUID()
    let position: CGPoint
    let isSuccess: Bool
}

// MARK: - Main Gathering View

struct GatheringView: View {
    let initialResource: String
    
    @StateObject private var viewModel = GatheringViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(initialResource: String = "wood") {
        self.initialResource = initialResource
    }
    
    // Animation state
    @State private var floatingNumbers: [FloatingNumber] = []
    @State private var hitEffects: [HitEffect] = []
    @State private var sweetspotPosition: CGPoint = CGPoint(x: 180, y: 200)
    @State private var sweetspotHit: Bool? = nil
    @State private var comboCount: Int = 0
    @State private var lastHitTime: Date? = nil
    @State private var canvasSize: CGSize = .zero
    
    // Drawing state
    @State private var currentPath: [CGPoint] = []
    @State private var fadingPaths: [FadingPath] = []
    @State private var hasHitThisStroke: Bool = false
    
    // Sweetspot config
    private let sweetspotSize: CGFloat = 50
    private let hitRadius: CGFloat = 25
    private let comboTimeout: TimeInterval = 2.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    navBar
                    
                    // Stats row
                    statsRow
                        .padding(.top, KingdomTheme.Spacing.large)
                        .padding(.horizontal, KingdomTheme.Spacing.medium)
                    
                    Spacer()
                }
                
                // Main canvas - the whole middle area
                canvas
                    .padding(.top, 140) // Below nav + stats
                    .padding(.bottom, 60) // Above instruction
                
                // Instruction at bottom
                VStack {
                    Spacer()
                    instructionText
                        .padding(.bottom, 30)
                }
            }
            .onAppear {
                canvasSize = geo.size
            }
            .onChange(of: geo.size) { newSize in
                canvasSize = newSize
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.selectResource(initialResource)
            await viewModel.loadConfig()
        }
        .alert("Resources Exhausted", isPresented: $viewModel.isExhausted) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(viewModel.exhaustedMessage)
        }
    }
    
    // MARK: - Nav Bar
    
    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(FontStyles.iconTiny)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(width: 36, height: 36)
                    .background(KingdomTheme.Colors.parchmentDark.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(viewModel.selectedResource == "wood" ? "Chop Wood" : "Mine Ore")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, KingdomTheme.Spacing.medium)
        .padding(.vertical, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Session gathered
            HStack(spacing: 8) {
                Image(systemName: viewModel.resourceIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(resourceColor)
                
                Text("\(viewModel.sessionGathered)")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .monospacedDigit()
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            .brutalistBadge(
                backgroundColor: KingdomTheme.Colors.parchmentLight,
                cornerRadius: 12,
                borderWidth: 2
            )
            
            Spacer()
            
            // Combo counter
            if comboCount > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    
                    Text("\(comboCount)x")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, KingdomTheme.Spacing.medium)
                .padding(.vertical, KingdomTheme.Spacing.small)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.imperialGold.opacity(0.3),
                    cornerRadius: 10,
                    borderWidth: 2
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: comboCount)
    }
    
    // MARK: - Canvas (drawing area)
    
    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                // Resource shape fills the canvas
                resourceShape
                
                // Sweetspot target
                SweetspotView(
                    position: sweetspotPosition,
                    size: sweetspotSize,
                    isHit: sweetspotHit
                )
                
                // Fading paths (completed strokes)
                ForEach(fadingPaths) { fadingPath in
                    FadingPathView(points: fadingPath.points, color: fadingPath.color) {
                        fadingPaths.removeAll { $0.id == fadingPath.id }
                    }
                }
                
                // Current drawing path
                if currentPath.count > 1 {
                    Path { path in
                        path.move(to: currentPath[0])
                        for point in currentPath.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        hasHitThisStroke ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.inkMedium,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                }
                
                // Hit effects
                ForEach(hitEffects) { effect in
                    HitEffectView(position: effect.position, isSuccess: effect.isSuccess) {
                        hitEffects.removeAll { $0.id == effect.id }
                    }
                }
                
                // Floating numbers
                ForEach(floatingNumbers) { floating in
                    FloatingNumberView(amount: floating.amount, color: floating.color) {
                        floatingNumbers.removeAll { $0.id == floating.id }
                    }
                    .position(floating.position)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        handleDrawing(at: value.location, in: geo.size)
                    }
                    .onEnded { value in
                        handleDrawingEnd(in: geo.size)
                    }
            )
            .onAppear {
                if geo.size.width > 0 && geo.size.height > 0 {
                    randomizeSweetspot(in: geo.size)
                }
            }
            .onChange(of: geo.size) { newSize in
                // If size was zero before, initialize now
                if newSize.width > 0 && newSize.height > 0 && sweetspotPosition.x == 180 {
                    randomizeSweetspot(in: newSize)
                }
            }
        }
    }
    
    @ViewBuilder
    private var resourceShape: some View {
        if viewModel.selectedResource == "wood" {
            TreeShape()
        } else {
            RockShape()
        }
    }
    
    // MARK: - Instruction Text
    
    private var instructionText: some View {
        Text(viewModel.selectedResource == "wood" ? "Slash through the target!" : "Strike the ore!")
            .font(FontStyles.bodySmall)
            .foregroundColor(KingdomTheme.Colors.inkLight)
    }
    
    // MARK: - Helpers
    
    private var resourceColor: Color {
        switch viewModel.selectedResource {
        case "wood":
            return KingdomTheme.Colors.buttonPrimary
        case "iron":
            return Color(red: 0.5, green: 0.48, blue: 0.45)
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
    
    private func randomizeSweetspot(in size: CGSize) {
        let w = size.width
        let h = size.height
        
        if viewModel.selectedResource == "wood" {
            // Pick a random point along one of the branches
            // Branches defined as (start, end) matching TreeShape
            // Positions on trunk and branches
            let spots: [CGPoint] = [
                // Trunk (multiple spots along it)
                CGPoint(x: w * 0.5, y: h * 0.15),
                CGPoint(x: w * 0.5, y: h * 0.35),
                CGPoint(x: w * 0.5, y: h * 0.55),
                CGPoint(x: w * 0.5, y: h * 0.75),
                // Left branches
                CGPoint(x: w * 0.22, y: h * 0.2),
                CGPoint(x: w * 0.2, y: h * 0.45),
                CGPoint(x: w * 0.22, y: h * 0.7),
                // Right branches
                CGPoint(x: w * 0.78, y: h * 0.2),
                CGPoint(x: w * 0.8, y: h * 0.45),
                CGPoint(x: w * 0.78, y: h * 0.7),
            ]
            
            sweetspotPosition = spots.randomElement()!
        } else {
            // On the rock - spread across the rock area
            let x = w * CGFloat.random(in: 0.2...0.8)
            let y = h * CGFloat.random(in: 0.15...0.8)
            sweetspotPosition = CGPoint(x: x, y: y)
        }
        sweetspotHit = nil
    }
    
    private func handleDrawing(at point: CGPoint, in size: CGSize) {
        currentPath.append(point)
        
        // Check if we hit the sweetspot
        guard !hasHitThisStroke else { return }
        
        let distance = hypot(point.x - sweetspotPosition.x, point.y - sweetspotPosition.y)
        if distance <= hitRadius {
            // HIT!
            hasHitThisStroke = true
            sweetspotHit = true
            
            // Haptic
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
            // Hit effect
            hitEffects.append(HitEffect(position: sweetspotPosition, isSuccess: true))
            
            // Update combo
            let now = Date()
            if let lastHit = lastHitTime, now.timeIntervalSince(lastHit) < comboTimeout {
                comboCount += 1
            } else {
                comboCount = 1
            }
            lastHitTime = now
            
            // Gather
            Task {
                await performGather(atPosition: sweetspotPosition)
            }
            
            // Move sweetspot after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                randomizeSweetspot(in: size)
            }
        }
    }
    
    private func handleDrawingEnd(in size: CGSize) {
        // Save the path as a fading trail
        if currentPath.count > 1 {
            let color = hasHitThisStroke ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.inkLight
            fadingPaths.append(FadingPath(points: currentPath, color: color))
        }
        
        // If we didn't hit anything this stroke
        if !hasHitThisStroke && currentPath.count > 5 {
            // Miss feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Reset combo
            comboCount = 0
            lastHitTime = nil
            
            // Show miss
            if let midPoint = currentPath[safe: currentPath.count / 2] {
                floatingNumbers.append(FloatingNumber(amount: 0, color: KingdomTheme.Colors.inkLight, position: midPoint))
            }
        }
        
        // Reset for next stroke
        currentPath = []
        hasHitThisStroke = false
    }
    
    private func performGather(atPosition position: CGPoint) async {
        await viewModel.gather()
        
        guard let result = viewModel.lastResult else { return }
        
        floatingNumbers.append(FloatingNumber(
            amount: result.amount,
            color: result.tierColor,
            position: position
        ))
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("Wood") {
    NavigationStack {
        GatheringView(initialResource: "wood")
    }
}

#Preview("Iron") {
    NavigationStack {
        GatheringView(initialResource: "iron")
    }
}
