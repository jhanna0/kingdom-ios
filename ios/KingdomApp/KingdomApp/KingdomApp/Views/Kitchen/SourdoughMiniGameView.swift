import SwiftUI

/// Cooking Mama-style sourdough bread making mini-game!
/// Each step is a real mini-game with 20-40 seconds of gameplay
struct SourdoughMiniGameView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStep: SourdoughStep = .intro
    @State private var showStepComplete = false
    @State private var starRating: Int = 0
    @State private var totalScore: Int = 0
    
    var body: some View {
        ZStack {
            // Warm kitchen background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.90, blue: 0.80),
                    Color(red: 0.90, green: 0.82, blue: 0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                gameHeader
                gameContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if showStepComplete {
                stepCompleteOverlay
            }
        }
    }
    
    // MARK: - Header
    
    private var gameHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        )
                }
                
                Spacer()
                
                Text("Sourdough Time!")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(KingdomTheme.Colors.goldLight)
                    Text("\(totalScore)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            progressIndicator
        }
        .padding(.bottom, 12)
        .background(
            Color(red: 0.85, green: 0.75, blue: 0.60)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(SourdoughStep.allGameSteps, id: \.self) { step in
                VStack(spacing: 2) {
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .overlay(stepIcon(for: step))
                    
                    Text(step.shortName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                if step != .bake {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? KingdomTheme.Colors.buttonSuccess : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 16)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func stepColor(for step: SourdoughStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return KingdomTheme.Colors.buttonSuccess
        } else if step == currentStep {
            return KingdomTheme.Colors.buttonWarning
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    @ViewBuilder
    private func stepIcon(for step: SourdoughStep) -> some View {
        if step.rawValue < currentStep.rawValue {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        } else {
            Image(systemName: step.iconName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(step == currentStep ? .white : .gray)
        }
    }
    
    // MARK: - Game Content
    
    @ViewBuilder
    private var gameContent: some View {
        switch currentStep {
        case .intro:
            IntroStepView(onStart: { advanceStep() })
        case .grindWheat:
            GrindWheatGameView(onComplete: { score in completeStep(score: score) })
        case .mixStarter:
            MixStarterGameView(onComplete: { score in completeStep(score: score) })
        case .knead:
            KneadGameView(onComplete: { score in completeStep(score: score) })
        case .shape:
            ShapeGameView(onComplete: { score in completeStep(score: score) })
        case .score:
            ScoreGameView(onComplete: { score in completeStep(score: score) })
        case .bake:
            BakeGameView(onComplete: { onComplete() })
        }
    }
    
    // MARK: - Step Complete Overlay
    
    private var stepCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { star in
                        Image(systemName: star <= starRating ? "star.fill" : "star")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                            .scaleEffect(star <= starRating ? 1.2 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(star) * 0.15), value: starRating)
                    }
                }
                
                Text(starRating == 3 ? "Perfect!" : starRating == 2 ? "Great!" : "Good!")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(currentStep.completionMessage)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(KingdomTheme.Colors.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
            )
            .padding(40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showStepComplete = false
                    advanceStep()
                }
            }
        }
    }
    
    private func completeStep(score: Int) {
        let stars = score >= 90 ? 3 : score >= 70 ? 2 : 1
        starRating = stars
        totalScore += score
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showStepComplete = true
        }
    }
    
    private func advanceStep() {
        if let nextStep = currentStep.next {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
        }
    }
}

// MARK: - Steps Enum

enum SourdoughStep: Int, CaseIterable {
    case intro = 0
    case grindWheat = 1
    case mixStarter = 2
    case knead = 3
    case shape = 4
    case score = 5
    case bake = 6
    
    static var allGameSteps: [SourdoughStep] {
        [.grindWheat, .mixStarter, .knead, .shape, .score, .bake]
    }
    
    var shortName: String {
        switch self {
        case .intro: return ""
        case .grindWheat: return "Grind"
        case .mixStarter: return "Mix"
        case .knead: return "Knead"
        case .shape: return "Shape"
        case .score: return "Score"
        case .bake: return "Bake"
        }
    }
    
    var iconName: String {
        switch self {
        case .intro: return "play.fill"
        case .grindWheat: return "gearshape.2"
        case .mixStarter: return "plus"
        case .knead: return "hand.raised"
        case .shape: return "circle"
        case .score: return "line.diagonal"
        case .bake: return "flame"
        }
    }
    
    var completionMessage: String {
        switch self {
        case .intro: return ""
        case .grindWheat: return "Fresh flour from the mill!"
        case .mixStarter: return "The starter is bubbling!"
        case .knead: return "Gluten is well developed!"
        case .shape: return "Beautiful boule shape!"
        case .score: return "Perfect scoring pattern!"
        case .bake: return ""
        }
    }
    
    var next: SourdoughStep? {
        SourdoughStep(rawValue: self.rawValue + 1)
    }
}

// MARK: - Intro

struct IntroStepView: View {
    let onStart: () -> Void
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.orange.opacity(0.3), Color.clear], center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                    .scaleEffect(animate ? 1.1 : 1.0)
                
                // Bread loaf
                BreadLoafShape()
                    .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.65, blue: 0.35), Color(red: 0.7, green: 0.5, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 90, height: 60)
                    .overlay(
                        // Score marks
                        VStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule()
                                    .fill(Color(red: 0.55, green: 0.35, blue: 0.15))
                                    .frame(width: 50, height: 4)
                                    .rotationEffect(.degrees(-15))
                            }
                        }
                    )
                    .rotationEffect(.degrees(animate ? 3 : -3))
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
            
            Text("Let's Make Sourdough!")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("A real baker's journey awaits.")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            VStack(alignment: .leading, spacing: 10) {
                stepRow(num: "1", text: "Grind wheat into flour", icon: "gearshape.2.fill")
                stepRow(num: "2", text: "Mix the sourdough starter", icon: "plus.circle.fill")
                stepRow(num: "3", text: "Knead & develop gluten", icon: "hand.raised.fill")
                stepRow(num: "4", text: "Shape into a boule", icon: "circle.fill")
                stepRow(num: "5", text: "Score the top", icon: "pencil.tip")
                stepRow(num: "6", text: "Bake to perfection", icon: "flame.fill")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2))
            )
            .padding(.horizontal, 30)
            
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onStart()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Baking!")
                        .font(FontStyles.headingSmall)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.black).offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 14).fill(KingdomTheme.Colors.buttonWarning)
                    RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 3)
                }
            )
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .onAppear { animate = true }
    }
    
    private func stepRow(num: String, text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(KingdomTheme.Colors.buttonWarning))
            
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 20)
            
            Text(text)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}

struct BreadLoafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h * 0.7))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h * 0.7), control: CGPoint(x: w, y: 0))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h), control: CGPoint(x: w, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h * 0.7), control: CGPoint(x: 0, y: h))
        
        return path
    }
}

// MARK: - GRIND WHEAT GAME

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
    let grainsPerStalk = 5
    
    enum GrindPhase {
        case harvest  // Tap wheat to get grains
        case grind    // Rotate mill to make flour
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Instructions
            VStack(alignment: .leading, spacing: 2) {
                Text(gamePhase == .harvest ? "Harvest the Wheat!" : "Grind the Flour!")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(gamePhase == .harvest ? "Tap wheat stalks to collect grains" : "Spin the millstone clockwise!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // Bottom status
            HStack(spacing: 20) {
                // Grains collected
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.7, blue: 0.4))
                        .frame(width: 20, height: 20)
                    Text("\(grainsInMill) grains")
                        .font(FontStyles.labelMedium)
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
        // Create wheat stalks
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

// MARK: - Wheat Stalk View

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

// MARK: - MIX STARTER GAME

struct MixStarterGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var ingredientsAdded: Set<String> = []
    @State private var mixingProgress: CGFloat = 0
    @State private var doughPosition: CGPoint = .zero
    @State private var doughVelocity: CGPoint = .zero
    @State private var bubbles: [MixBubble] = []
    @State private var isDragging = false
    @State private var lastDragPosition: CGPoint = .zero
    @State private var totalMixMovement: CGFloat = 0
    @State private var doughColor: Color = Color(white: 0.95)
    @State private var splashParticles: [SplashParticle] = []
    
    let requiredMixMovement: CGFloat = 3000
    let allIngredients = ["flour", "water", "starter"]
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredientsAdded.count < 3 ? "Add Ingredients!" : "Mix the Dough!")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(ingredientsAdded.count < 3 ? "Drag each ingredient into the bowl" : "Swirl your finger through the dough!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            // Progress bar (only shown during mixing)
            if ingredientsAdded.count >= 3 {
                VStack(spacing: 4) {
                    HStack {
                        Text("Mixing")
                        Spacer()
                        Text("\(Int(min(100, mixingProgress * 100)))%")
                            .font(FontStyles.labelBold)
                    }
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal, 20)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.buttonWarning)
                                .frame(width: geo.size.width * mixingProgress)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    }
                    .frame(height: 20)
                    .padding(.horizontal, 20)
                }
            }
            
            // Game area
            GeometryReader { geo in
                let bowlCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 30)
                
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.85, green: 0.78, blue: 0.68))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 20)
                    
                    // Ingredients to drag (if not added)
                    if !ingredientsAdded.contains("flour") {
                        DraggableIngredient(name: "Flour", color: Color(white: 0.95), icon: "circle.fill", position: CGPoint(x: 70, y: 70)) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                ingredientsAdded.insert("flour")
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            spawnIngredientSplash(type: "flour", center: bowlCenter)
                        }
                        .position(x: 70, y: 70)
                    }
                    
                    if !ingredientsAdded.contains("water") {
                        DraggableIngredient(name: "Water", color: Color.blue.opacity(0.5), icon: "drop.fill", position: CGPoint(x: geo.size.width - 70, y: 70)) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                ingredientsAdded.insert("water")
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            spawnIngredientSplash(type: "water", center: bowlCenter)
                        }
                        .position(x: geo.size.width - 70, y: 70)
                    }
                    
                    if !ingredientsAdded.contains("starter") {
                        DraggableIngredient(name: "Starter", color: Color(red: 0.9, green: 0.85, blue: 0.75), icon: "bubbles.and.sparkles", position: CGPoint(x: geo.size.width / 2, y: 60)) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                ingredientsAdded.insert("starter")
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            spawnIngredientSplash(type: "starter", center: bowlCenter)
                        }
                        .position(x: geo.size.width / 2, y: 60)
                    }
                    
                    // Splash particles
                    ForEach(splashParticles) { particle in
                        Circle()
                            .fill(particle.color.opacity(particle.opacity))
                            .frame(width: particle.size, height: particle.size)
                            .position(particle.position)
                    }
                    
                    // Mixing bowl
                    ZStack {
                        // Bowl shadow
                        Ellipse()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 220, height: 70)
                            .offset(y: 70)
                        
                        // Bowl body
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.75, green: 0.7, blue: 0.63), Color(red: 0.6, green: 0.55, blue: 0.48)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 200, height: 130)
                        
                        // Bowl contents
                        ZStack {
                            // Show different layers/colors based on ingredients added
                            if ingredientsAdded.isEmpty {
                                // Empty bowl interior
                                Ellipse()
                                    .fill(Color(red: 0.68, green: 0.63, blue: 0.56).opacity(0.3))
                                    .frame(width: 170, height: 100)
                            } else {
                                // Layered ingredients
                                ZStack {
                                    // Water layer (bottom if added)
                                    if ingredientsAdded.contains("water") {
                                        Ellipse()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.blue.opacity(0.3),
                                                        Color.blue.opacity(0.4)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 160, height: 85)
                                            .offset(y: 5)
                                        
                                        // Water ripples
                                        ForEach(0..<3, id: \.self) { i in
                                            Ellipse()
                                                .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                                .frame(width: CGFloat(120 - i * 20), height: CGFloat(65 - i * 15))
                                                .offset(y: 5)
                                        }
                                    }
                                    
                                    // Flour layer (white powder)
                                    if ingredientsAdded.contains("flour") {
                                        ZStack {
                                            // Main flour pile
                                            Ellipse()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [
                                                            Color(white: 0.98),
                                                            Color(white: 0.92)
                                                        ],
                                                        center: .center,
                                                        startRadius: 0,
                                                        endRadius: 70
                                                    )
                                                )
                                                .frame(width: 140, height: 75)
                                            
                                            // Flour texture (lumpy)
                                            ForEach(0..<8, id: \.self) { i in
                                                Circle()
                                                    .fill(Color(white: 0.95).opacity(0.6))
                                                    .frame(width: CGFloat.random(in: 12...20), height: CGFloat.random(in: 8...15))
                                                    .offset(
                                                        x: CGFloat.random(in: -40...40),
                                                        y: CGFloat.random(in: -20...20)
                                                    )
                                            }
                                        }
                                    }
                                    
                                    // Starter layer (bubbly beige)
                                    if ingredientsAdded.contains("starter") {
                                        ZStack {
                                            // Starter blob
                                            Ellipse()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.92, green: 0.88, blue: 0.78),
                                                            Color(red: 0.88, green: 0.82, blue: 0.70)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .frame(width: 100, height: 60)
                                                .offset(y: -5)
                                            
                                            // Starter bubbles
                                            ForEach(0..<5, id: \.self) { i in
                                                Circle()
                                                    .fill(Color.white.opacity(0.5))
                                                    .frame(width: CGFloat.random(in: 4...8))
                                                    .offset(
                                                        x: CGFloat.random(in: -35...35),
                                                        y: CGFloat.random(in: -20...10)
                                                    )
                                            }
                                        }
                                    }
                                }
                                
                                // Mixed dough blob (only when all 3 added and mixing)
                                if ingredientsAdded.count >= 3 {
                                    Ellipse()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color(red: 0.95, green: 0.90, blue: 0.82),
                                                    Color(red: 0.88, green: 0.82, blue: 0.72)
                                                ],
                                                center: .center, startRadius: 0, endRadius: 40
                                            )
                                        )
                                        .frame(width: 80 + mixingProgress * 30, height: 60 + mixingProgress * 20)
                                        .offset(x: doughPosition.x, y: doughPosition.y)
                                        .scaleEffect(isDragging ? 1.1 : 1.0)
                                        .opacity(mixingProgress > 0.1 ? 1.0 : 0.0)
                                    
                                    // Mixing bubbles
                                    ForEach(bubbles) { bubble in
                                        Circle()
                                            .fill(Color.white.opacity(0.7))
                                            .frame(width: bubble.size, height: bubble.size)
                                            .offset(x: bubble.position.x, y: bubble.position.y)
                                            .scaleEffect(bubble.scale)
                                    }
                                }
                            }
                        }
                        .clipShape(Ellipse())
                        
                        // Bowl rim
                        Ellipse()
                            .stroke(Color(red: 0.5, green: 0.45, blue: 0.38), lineWidth: 8)
                            .frame(width: 200, height: 130)
                    }
                    .position(bowlCenter)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleMixDrag(value: value, center: bowlCenter)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
            }
            
            // Ingredients status
            HStack(spacing: 20) {
                ForEach(allIngredients, id: \.self) { ingredient in
                    HStack(spacing: 4) {
                        Image(systemName: ingredientsAdded.contains(ingredient) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(ingredientsAdded.contains(ingredient) ? KingdomTheme.Colors.buttonSuccess : .gray)
                        Text(ingredient.capitalized)
                            .font(FontStyles.labelSmall)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private func handleMixDrag(value: DragGesture.Value, center: CGPoint) {
        guard ingredientsAdded.count >= 3 else { return }
        
        isDragging = true
        
        // Calculate movement
        let dx = value.location.x - lastDragPosition.x
        let dy = value.location.y - lastDragPosition.y
        let movement = hypot(dx, dy)
        lastDragPosition = value.location
        
        totalMixMovement += movement
        mixingProgress = min(1.0, totalMixMovement / requiredMixMovement)
        
        // Move dough toward finger (constrained)
        let targetX = (value.location.x - center.x) * 0.3
        let targetY = (value.location.y - center.y) * 0.3
        let maxOffset: CGFloat = 40
        
        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.7)) {
            doughPosition = CGPoint(
                x: max(-maxOffset, min(maxOffset, targetX)),
                y: max(-maxOffset, min(maxOffset, targetY))
            )
        }
        
        // Update dough color (gets more uniform)
        doughColor = Color(
            red: 0.95 - mixingProgress * 0.07,
            green: 0.90 - mixingProgress * 0.08,
            blue: 0.82 - mixingProgress * 0.07
        )
        
        // Add bubbles
        if movement > 10 && Int.random(in: 0...3) == 0 {
            addBubble()
        }
        
        // Haptic
        if Int(mixingProgress * 100) % 5 == 0 {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        
        // Check completion
        if mixingProgress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onComplete(95)
            }
        }
    }
    
    private func addBubble() {
        let bubble = MixBubble(
            id: UUID(),
            position: CGPoint(x: CGFloat.random(in: -60...60), y: CGFloat.random(in: -40...40)),
            size: CGFloat.random(in: 6...14),
            scale: 0
        )
        bubbles.append(bubble)
        
        if let index = bubbles.firstIndex(where: { $0.id == bubble.id }) {
            withAnimation(.easeOut(duration: 0.3)) {
                bubbles[index].scale = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeIn(duration: 0.2)) {
                    if let idx = bubbles.firstIndex(where: { $0.id == bubble.id }) {
                        bubbles[idx].scale = 0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    bubbles.removeAll { $0.id == bubble.id }
                }
            }
        }
    }
    
    private func spawnIngredientSplash(type: String, center: CGPoint) {
        let particleColor: Color
        let particleCount: Int
        
        switch type {
        case "flour":
            particleColor = Color(white: 0.95)
            particleCount = 15
        case "water":
            particleColor = Color.blue.opacity(0.6)
            particleCount = 20
        case "starter":
            particleColor = Color(red: 0.9, green: 0.85, blue: 0.75)
            particleCount = 12
        default:
            return
        }
        
        // Spawn particles in a splash pattern
        for i in 0..<particleCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(particleCount))
            let speed = CGFloat.random(in: 30...80)
            let particle = SplashParticle(
                id: UUID(),
                position: center,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed - 20 // Bias upward
                ),
                color: particleColor,
                size: CGFloat.random(in: 3...8),
                opacity: 1.0
            )
            splashParticles.append(particle)
            
            // Animate particle
            animateSplashParticle(particle)
        }
    }
    
    private func animateSplashParticle(_ particle: SplashParticle) {
        guard let index = splashParticles.firstIndex(where: { $0.id == particle.id }) else { return }
        
        // Animate over 0.8 seconds
        let duration = 0.8
        let steps = 20
        
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(step)) {
                guard let idx = self.splashParticles.firstIndex(where: { $0.id == particle.id }) else { return }
                
                // Physics simulation
                let t = Double(step) / Double(steps)
                self.splashParticles[idx].position.x += self.splashParticles[idx].velocity.x * 0.05
                self.splashParticles[idx].position.y += self.splashParticles[idx].velocity.y * 0.05
                self.splashParticles[idx].velocity.y += 3 // Gravity
                self.splashParticles[idx].velocity.x *= 0.95 // Air resistance
                self.splashParticles[idx].velocity.y *= 0.95
                self.splashParticles[idx].opacity = 1.0 - CGFloat(t)
                
                if step == steps {
                    self.splashParticles.removeAll { $0.id == particle.id }
                }
            }
        }
    }
}

struct DraggableIngredient: View {
    let name: String
    let color: Color
    let icon: String
    let position: CGPoint
    let onDrop: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 55, height: 55)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(icon == "drop.fill" ? .blue : (icon == "bubbles.and.sparkles" ? .orange : .gray))
                )
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                .shadow(color: .black.opacity(isDragging ? 0.3 : 0), radius: 8, y: 4)
            
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .offset(offset)
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    offset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    // Check if dropped in bowl area (roughly center of screen)
                    let dropPoint = CGPoint(
                        x: position.x + value.translation.width,
                        y: position.y + value.translation.height
                    )
                    let screenCenter = CGPoint(x: UIScreen.main.bounds.width / 2, y: 280)
                    let distance = hypot(dropPoint.x - screenCenter.x, dropPoint.y - screenCenter.y)
                    
                    if distance < 120 {
                        onDrop()
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
                }
        )
    }
}

struct MixBubble: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGFloat
    var scale: CGFloat
}

struct SplashParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: CGFloat
}

// MARK: - KNEAD GAME

struct KneadGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var doughStretch: CGPoint = .zero
    @State private var isStretching = false
    @State private var foldCount: Int = 0
    @State private var glutenLevel: CGFloat = 0
    @State private var showFoldText = false
    
    let targetFolds = 35
    let stretchThreshold: CGFloat = 60  // Lowered from 80 since dough moves slower now (harder to reach same distance)
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("Stretch & Fold!")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Pull outward, release to fold back!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            // Progress
            VStack(spacing: 4) {
                HStack {
                    Text("Gluten Development")
                    Spacer()
                    Text("\(foldCount)/\(targetFolds) folds")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal, 20)
                
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
                .padding(.horizontal, 20)
            }
            
            // Game area
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
                    
                    // Fold text
                    if showFoldText {
                        Text("FOLD!")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                            .position(center)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            Text("Stretch slowly - the dough is heavy and sticky!")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.bottom, 20)
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: min(1, dist / 120))
        }
    }
    
    private func handleStretchEnd(value: DragGesture.Value, center: CGPoint) {
        let stretchDist = hypot(doughStretch.x, doughStretch.y)
        
        if stretchDist > stretchThreshold {
            // Successful fold!
            foldCount += 1
            glutenLevel = min(1.0, CGFloat(foldCount) / CGFloat(targetFolds))
            
            // Show fold animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showFoldText = true
            }
            
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { showFoldText = false }
            }
            
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

// MARK: - SHAPE GAME

struct ShapeGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var doughPoints: [DoughPoint] = []
    @State private var roundness: CGFloat = 0.3
    @State private var shapeProgress: CGFloat = 0
    @State private var isTouching = false
    @State private var touchPosition: CGPoint = .zero
    @State private var rotationAngle: CGFloat = 0
    @State private var lastAngle: CGFloat = 0
    @State private var totalRotation: CGFloat = 0
    @State private var tensionLines: [TensionLine] = []
    
    let targetRotation: CGFloat = 4000 // Multiple full rotations
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shape the Boule!")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Rotate around the dough to shape it round!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            VStack(spacing: 4) {
                HStack {
                    Text("Roundness")
                    Spacer()
                    Text("\(Int(shapeProgress * 100))%")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal, 20)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: geo.size.width * shapeProgress)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
                .padding(.horizontal, 20)
            }
            
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                
                ZStack {
                    // Work surface
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.82, green: 0.72, blue: 0.58), Color(red: 0.72, green: 0.62, blue: 0.48)],
                                center: .center, startRadius: 0, endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .overlay(Circle().stroke(Color.black, lineWidth: 3))
                        .position(center)
                    
                    // Guide circle
                    Circle()
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, dash: [10, 10]))
                        .frame(width: 180, height: 180)
                        .position(center)
                    
                    // Rotation arrow hint
                    if shapeProgress < 0.2 {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.4))
                            .position(center)
                    }
                    
                    // Dough
                    morphingDough(center: center)
                        .position(center)
                    
                    // Touch indicator (hands)
                    if isTouching {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .position(touchPosition)
                        
                        // Opposite hand
                        let oppositeX = 2 * center.x - touchPosition.x
                        let oppositeY = 2 * center.y - touchPosition.y
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .position(x: oppositeX, y: oppositeY)
                    }
                    
                    // Tension lines
                    ForEach(tensionLines) { line in
                        Capsule()
                            .fill(Color(red: 0.85, green: 0.75, blue: 0.62).opacity(line.opacity))
                            .frame(width: line.length, height: 2)
                            .rotationEffect(.degrees(line.angle))
                            .position(center)
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleShapeDrag(value: value, center: center)
                        }
                        .onEnded { _ in
                            isTouching = false
                        }
                )
            }
            
            Text("Create surface tension for a perfect rise!")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func morphingDough(center: CGPoint) -> some View {
        let blobAmount = 1.0 - roundness
        
        Canvas { context, size in
            var path = Path()
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius: CGFloat = 60
            
            for i in 0..<72 {
                let angle = CGFloat(i) * .pi * 2 / 72
                let wobble1 = sin(angle * 3 + rotationAngle * 0.02) * 20 * blobAmount
                let wobble2 = sin(angle * 5 + rotationAngle * 0.03) * 10 * blobAmount
                let wobble3 = sin(angle * 7) * 5 * blobAmount
                let r = baseRadius + wobble1 + wobble2 + wobble3
                
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r * 0.85
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
            
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.95, green: 0.88, blue: 0.76),
                        Color(red: 0.88, green: 0.78, blue: 0.65)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            
            context.stroke(path, with: .color(Color(red: 0.75, green: 0.65, blue: 0.50)), lineWidth: 2)
        }
        .frame(width: 160, height: 140)
        .scaleEffect(isTouching ? 1.03 : 1.0)
    }
    
    private func handleShapeDrag(value: DragGesture.Value, center: CGPoint) {
        isTouching = true
        touchPosition = value.location
        
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let currentAngle = atan2(dy, dx)
        
        var delta = currentAngle - lastAngle
        lastAngle = currentAngle
        
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        
        let rotationAmount = abs(delta * 180 / .pi)
        totalRotation += rotationAmount
        rotationAngle += delta * 50
        
        shapeProgress = min(1.0, totalRotation / targetRotation)
        roundness = 0.3 + shapeProgress * 0.7
        
        // Add tension lines as it gets rounder
        if shapeProgress > 0.5 && Int(totalRotation) % 100 == 0 {
            addTensionLine()
        }
        
        if Int(totalRotation) % 50 == 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        if shapeProgress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onComplete(95)
            }
        }
    }
    
    private func addTensionLine() {
        let line = TensionLine(
            id: UUID(),
            length: CGFloat.random(in: 25...45),
            angle: Double.random(in: 0...360),
            opacity: 0.6
        )
        tensionLines.append(line)
        
        if tensionLines.count > 8 {
            tensionLines.removeFirst()
        }
    }
}

struct DoughPoint: Identifiable {
    let id = UUID()
    var position: CGPoint
    var radius: CGFloat
}

struct TensionLine: Identifiable {
    let id: UUID
    var length: CGFloat
    var angle: Double
    var opacity: Double
}

// MARK: - SCORE GAME

struct ScoreGameView: View {
    let onComplete: (Int) -> Void
    
    @State private var allPaths: [[CGPoint]] = []
    @State private var currentPath: [CGPoint] = []
    @State private var totalDrawnLength: CGFloat = 0
    let requiredLength: CGFloat = 400
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Score the Bread!")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Draw patterns on the dough with your finger")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [KingdomTheme.Colors.buttonSuccess, Color.green.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1.0, totalDrawnLength / requiredLength), height: 8)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 8)
            
            // Scoring area
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                
                ZStack {
                    // Baking tray
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.3, green: 0.3, blue: 0.35))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 3))
                        .padding(.horizontal, 20)
                    
                    // Parchment
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.88, blue: 0.80))
                        .padding(35)
                    
                    // Bread loaf
                    ZStack {
                        // Shadow
                        Ellipse()
                            .fill(Color.black.opacity(0.15))
                            .frame(width: 200, height: 60)
                            .position(x: center.x, y: center.y + 65)
                        
                        // Loaf
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.90, blue: 0.78),
                                        Color(red: 0.88, green: 0.80, blue: 0.65)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 180, height: 130)
                            .overlay(
                                Ellipse()
                                    .stroke(Color(red: 0.78, green: 0.68, blue: 0.52), lineWidth: 2)
                            )
                            .position(center)
                        
                        // Completed paths
                        ForEach(allPaths.indices, id: \.self) { pathIndex in
                            if allPaths[pathIndex].count >= 2 {
                                Path { path in
                                    let first = CGPoint(x: center.x + allPaths[pathIndex][0].x, y: center.y + allPaths[pathIndex][0].y)
                                    path.move(to: first)
                                    for point in allPaths[pathIndex].dropFirst() {
                                        let p = CGPoint(x: center.x + point.x, y: center.y + point.y)
                                        path.addLine(to: p)
                                    }
                                }
                                .stroke(
                                    Color(red: 0.65, green: 0.50, blue: 0.35),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                                )
                                
                                // Inner lighter line
                                Path { path in
                                    let first = CGPoint(x: center.x + allPaths[pathIndex][0].x, y: center.y + allPaths[pathIndex][0].y)
                                    path.move(to: first)
                                    for point in allPaths[pathIndex].dropFirst() {
                                        let p = CGPoint(x: center.x + point.x, y: center.y + point.y)
                                        path.addLine(to: p)
                                    }
                                }
                                .stroke(
                                    Color(red: 0.85, green: 0.75, blue: 0.60),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                        
                        // Current slash being drawn
                        if currentPath.count >= 2 {
                            Path { path in
                                let first = CGPoint(x: center.x + currentPath.first!.x, y: center.y + currentPath.first!.y)
                                path.move(to: first)
                                for point in currentPath.dropFirst() {
                                    let p = CGPoint(x: center.x + point.x, y: center.y + point.y)
                                    path.addLine(to: p)
                                }
                            }
                            .stroke(Color.red.opacity(0.7), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                let localPoint = CGPoint(
                                    x: value.location.x - center.x,
                                    y: value.location.y - center.y
                                )
                                if abs(localPoint.x) < 90 && abs(localPoint.y) < 65 {
                                    currentPath.append(localPoint)
                                    
                                    if currentPath.count % 5 == 0 {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.3)
                                    }
                                }
                            }
                            .onEnded { _ in
                                finishPath()
                            }
                    )
                    
                    // Lame (blade) icon
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 32))
                            .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.45))
                        Text("Lame")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .position(x: geo.size.width - 50, y: 60)
                }
            }
            .frame(height: 450)
            
            Text("A sharp blade scores the dough for a beautiful bloom!")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.bottom, 20)
        }
    }
    
    private func finishPath() {
        guard currentPath.count >= 5 else {
            currentPath = []
            return
        }
        
        // Calculate path length
        var pathLength: CGFloat = 0
        for i in 1..<currentPath.count {
            let prev = currentPath[i-1]
            let curr = currentPath[i]
            pathLength += hypot(curr.x - prev.x, curr.y - prev.y)
        }
        
        if pathLength > 20 {
            allPaths.append(currentPath)
            totalDrawnLength += pathLength
            
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            if totalDrawnLength >= requiredLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete(90 + Int.random(in: 0...10))
                }
            }
        }
        
        currentPath = []
    }
}

// MARK: - BAKE GAME

struct BakeGameView: View {
    let onComplete: () -> Void
    
    @State private var ovenTemp: CGFloat = 0
    @State private var breadRise: CGFloat = 0.8
    @State private var crustColor: CGFloat = 0
    @State private var steamAmount: CGFloat = 0
    @State private var scoreBloom: CGFloat = 0
    @State private var isComplete = false
    @State private var bakePhase: BakePhase = .preheat
    @State private var crackLines: [BakeCrack] = []
    
    enum BakePhase {
        case preheat
        case steam
        case bake
        case done
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseTitle)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(phaseSubtitle)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                // Temp display
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.high")
                    Text("\(Int(ovenTemp * 450 + 50))°F")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(ovenTemp > 0.8 ? .red : KingdomTheme.Colors.inkDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.8)).overlay(Capsule().stroke(Color.black, lineWidth: 2)))
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Oven view
            ZStack {
                // Oven body
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.2, blue: 0.18), Color(red: 0.18, green: 0.13, blue: 0.1)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 300, height: 240)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
                
                // Oven interior (glowing)
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        Color(
                            red: 0.3 + ovenTemp * 0.5,
                            green: 0.15 + ovenTemp * 0.15,
                            blue: 0.1
                        )
                    )
                    .frame(width: 260, height: 200)
                
                // Heat coils at bottom
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 1, green: 0.3 + ovenTemp * 0.4, blue: 0.1).opacity(ovenTemp))
                            .frame(width: 40, height: 8)
                    }
                }
                .offset(y: 85)
                
                // Heat waves
                if ovenTemp > 0.5 {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundColor(.orange.opacity(0.4 * ovenTemp))
                            .offset(y: CGFloat(50 + i * 12))
                    }
                }
                
                // Steam
                if steamAmount > 0 {
                    ForEach(0..<Int(steamAmount * 10), id: \.self) { i in
                        Image(systemName: "cloud.fill")
                            .font(.system(size: CGFloat.random(in: 12...20)))
                            .foregroundColor(.white.opacity(0.5 * steamAmount))
                            .offset(
                                x: CGFloat.random(in: -80...80),
                                y: CGFloat.random(in: -70...(-30))
                            )
                    }
                }
                
                // Bread
                bakedBreadView
            }
            
            Spacer()
            
            // Complete button
            if isComplete {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onComplete()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Your Sourdough is Ready!")
                            .font(FontStyles.headingSmall)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color.black).offset(x: 4, y: 4)
                        RoundedRectangle(cornerRadius: 14).fill(KingdomTheme.Colors.buttonSuccess)
                        RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 3)
                    }
                )
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
        }
        .onAppear { startBaking() }
    }
    
    private var phaseTitle: String {
        switch bakePhase {
        case .preheat: return "Preheating Oven..."
        case .steam: return "Adding Steam!"
        case .bake: return "Baking..."
        case .done: return "Perfectly Baked!"
        }
    }
    
    private var phaseSubtitle: String {
        switch bakePhase {
        case .preheat: return "Getting the oven nice and hot"
        case .steam: return "Steam helps the crust form"
        case .bake: return "Watch the magic happen"
        case .done: return "A beautiful golden loaf!"
        }
    }
    
    @ViewBuilder
    private var bakedBreadView: some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: 130, height: 35)
                .offset(y: 50)
            
            // Bread loaf
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(
                                red: 0.95 - crustColor * 0.2,
                                green: 0.88 - crustColor * 0.28,
                                blue: 0.75 - crustColor * 0.45
                            ),
                            Color(
                                red: 0.88 - crustColor * 0.18,
                                green: 0.78 - crustColor * 0.28,
                                blue: 0.60 - crustColor * 0.40
                            )
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 110, height: 80 * breadRise)
                .overlay(
                    // Score marks blooming open
                    VStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            ZStack {
                                // Outer (darker)
                                Capsule()
                                    .fill(Color(red: 0.55 - crustColor * 0.1, green: 0.38, blue: 0.18))
                                    .frame(width: 55, height: 4 + scoreBloom * 8)
                                
                                // Inner (lighter - the "ear")
                                Capsule()
                                    .fill(Color(red: 0.92 - crustColor * 0.15, green: 0.82 - crustColor * 0.2, blue: 0.65 - crustColor * 0.25))
                                    .frame(width: 50, height: 2 + scoreBloom * 4)
                                    .offset(y: -scoreBloom * 2)
                            }
                            .rotationEffect(.degrees(-20))
                        }
                    }
                    .offset(y: -5)
                )
            
            // Crust cracks
            ForEach(crackLines) { crack in
                Capsule()
                    .fill(Color(red: 0.6 - crustColor * 0.1, green: 0.45, blue: 0.25).opacity(crack.opacity))
                    .frame(width: crack.length, height: 2)
                    .rotationEffect(.degrees(crack.angle))
                    .offset(x: crack.offset.x, y: crack.offset.y)
            }
        }
        .offset(y: -20)
    }
    
    private func startBaking() {
        // Phase 1: Preheat
        withAnimation(.easeInOut(duration: 1.5)) {
            ovenTemp = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            bakePhase = .steam
            
            // Phase 2: Steam
            withAnimation(.easeInOut(duration: 1.0)) {
                steamAmount = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                bakePhase = .bake
                
                // Phase 3: Bake - bread rises, crust forms
                withAnimation(.easeInOut(duration: 2.0)) {
                    breadRise = 1.2
                    scoreBloom = 1.0
                }
                
                withAnimation(.easeInOut(duration: 2.5)) {
                    crustColor = 1.0
                    steamAmount = 0.3
                }
                
                // Add cracks over time
                for i in 0..<5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 0.3) {
                        crackLines.append(BakeCrack(
                            length: CGFloat.random(in: 15...30),
                            angle: Double.random(in: -50...50),
                            offset: CGPoint(x: CGFloat.random(in: -35...35), y: CGFloat.random(in: -25...25)),
                            opacity: 0.7
                        ))
                    }
                }
                
                // Complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    bakePhase = .done
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isComplete = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}

struct BakeCrack: Identifiable {
    let id = UUID()
    let length: CGFloat
    let angle: Double
    let offset: CGPoint
    let opacity: Double
}

// MARK: - Preview

#Preview {
    SourdoughMiniGameView(
        onComplete: { print("Complete!") },
        onCancel: { print("Cancelled") }
    )
}
