import SwiftUI

// MARK: - Chicken Detail Sheet (Tamagotchi Style)

struct ChickenDetailSheet: View {
    let slot: ChickenSlot
    let currentTime: Date
    let onAction: (String) -> Void
    let onCollect: () -> Void
    let onName: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    // LCD screen colors
    private let lcdBackground = Color(red: 0.68, green: 0.78, blue: 0.62)
    private let lcdDark = Color(red: 0.25, green: 0.35, blue: 0.22)
    private let deviceColor = Color(red: 0.95, green: 0.92, blue: 0.85)
    
    private func statColor(value: Int, threshold: Int) -> Color {
        value >= threshold ? Color(red: 0.3, green: 0.6, blue: 0.3) : Color(red: 0.7, green: 0.25, blue: 0.25)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            // Tamagotchi device frame
            VStack(spacing: 0) {
                // Main LCD screen area
                lcdScreen
                    .padding(.horizontal, 24)
                
                // Physical buttons below screen
                actionButtons
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                
                // Egg collection button (always visible)
                collectEggButton
                    .padding(.top, 16)
            }
            .padding(.bottom, 20)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(deviceColor.ignoresSafeArea())
    }
    
    // MARK: - LCD Screen
    
    private var lcdScreen: some View {
        ZStack {
            // Screen bezel
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.3, green: 0.3, blue: 0.32))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            
            // Inner screen
            RoundedRectangle(cornerRadius: 12)
                .fill(lcdBackground)
                .padding(6)
            
            // Screen content
            VStack(spacing: 0) {
                // Name header
                nameHeader
                    .padding(.top, 16)
                
                Spacer()
                
                // Chicken display
                chickenDisplay
                
                Spacer()
                
                // Mini stat bars
                if let stats = slot.stats {
                    miniStatBars(stats: stats)
                        .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 280)
    }
    
    // MARK: - Name Header
    
    private var nameHeader: some View {
        HStack(spacing: 8) {
            // Name should always come from backend (auto-generated on hatch)
            // Fallback to label if name is somehow nil
            let displayName = slot.name ?? slot.label
            
            Text(displayName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(lcdDark)
            
            if slot.canRename == true {
                Button {
                    onName()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(lcdDark.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Chicken Display
    
    private var chickenDisplay: some View {
        ZStack {
            // Ground shadow
            Ellipse()
                .fill(lcdDark.opacity(0.15))
                .frame(width: 90, height: 24)
                .offset(y: 55)
            
            // The animated chicken
            TamagotchiChickenView(
                isHappy: slot.isHappy,
                hasEgg: slot.canCollect,
                currentAnimation: currentAnimation
            )
            
            // Action animation overlay
            if let animation = currentAnimation {
                actionAnimationOverlay(animation: animation)
            }
        }
        .frame(height: 140)
    }
    
    @ViewBuilder
    private func actionAnimationOverlay(animation: ChickenActionAnimation) -> some View {
        switch animation {
        case .feeding:
            FeedingAnimationView()
        case .playing:
            PlayingAnimationView()
        case .cleaning:
            CleaningAnimationView()
        }
    }
    
    private func triggerAnimation(for actionId: String) {
        let animation: ChickenActionAnimation? = switch actionId {
        case "feed": .feeding
        case "play": .playing
        case "clean": .cleaning
        default: nil
        }
        
        guard let animation = animation else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentAnimation = animation
        }
        
        // Clear animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentAnimation = nil
            }
        }
    }
    
    // MARK: - Mini Stat Bars
    
    private func miniStatBars(stats: ChickenTamagotchiStats) -> some View {
        HStack(spacing: 16) {
            miniStatBar(icon: "fork.knife", value: stats.hunger, label: "Food")
            miniStatBar(icon: "heart.fill", value: stats.happiness, label: "Happy")
            miniStatBar(icon: "sparkles", value: stats.cleanliness, label: "Clean")
        }
    }
    
    private func miniStatBar(icon: String, value: Int, label: String) -> some View {
        let threshold = slot.minStatForEggs ?? 50
        let barColor = statColor(value: value, threshold: threshold)
        
        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(lcdDark)
            
            // Bar background
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(lcdDark.opacity(0.2))
                    .frame(width: 50, height: 10)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: 50 * CGFloat(value) / 100, height: 10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(lcdDark.opacity(0.4), lineWidth: 1)
            )
            
            Text("\(value)%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(lcdDark)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            if let actions = slot.actions {
                ForEach(actions) { action in
                    tamagotchiButton(action: action)
                }
            }
        }
    }
    
    private func tamagotchiButton(action: ChickenAction) -> some View {
        Button {
            triggerAnimation(for: action.actionId)
            onAction(action.actionId)
        } label: {
            VStack(spacing: 6) {
                // Physical button look
                ZStack {
                    // Button shadow/depth
                    Circle()
                        .fill(Color(red: 0.25, green: 0.25, blue: 0.28))
                        .frame(width: 56, height: 56)
                    
                    // Button face
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    buttonColor(for: action.actionId).opacity(0.9),
                                    buttonColor(for: action.actionId)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: .white.opacity(0.3), radius: 1, y: -1)
                    
                    // Icon
                    Image(systemName: action.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Label
                Text(action.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.32))
                
                // Cost - always show to keep alignment
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10))
                    Text("\(action.goldCost)")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(KingdomTheme.Colors.imperialGold)
                .opacity(action.goldCost > 0 ? 1 : 0)
            }
        }
        .buttonStyle(TamagotchiButtonStyle())
    }
    
    private func buttonColor(for actionId: String) -> Color {
        switch actionId {
        case "feed":
            return Color(red: 0.85, green: 0.55, blue: 0.25) // Orange
        case "play":
            return Color(red: 0.85, green: 0.35, blue: 0.45) // Pink
        case "clean":
            return Color(red: 0.35, green: 0.65, blue: 0.85) // Blue
        default:
            return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
    
    // MARK: - Collect Egg Button
    
    private var collectEggButton: some View {
        let eggCount = slot.eggsAvailable ?? 0
        let hasEggs = eggCount > 0
        
        return Button {
            if hasEggs {
                onCollect()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "oval.fill")
                    .font(.system(size: 16))
                Text(hasEggs ? "Collect \(eggCount) Egg\(eggCount == 1 ? "" : "s")" : "No eggs yet!")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(hasEggs ? .white : Color(red: 0.5, green: 0.5, blue: 0.5))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        hasEggs ?
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.75, blue: 0.3),
                                Color(red: 0.85, green: 0.6, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [
                                Color(red: 0.8, green: 0.78, blue: 0.75),
                                Color(red: 0.7, green: 0.68, blue: 0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            )
            .overlay(
                Capsule()
                    .stroke(hasEggs ? Color(red: 0.7, green: 0.5, blue: 0.15) : Color(red: 0.5, green: 0.48, blue: 0.45), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasEggs)
    }
}

// MARK: - Tamagotchi Button Style

struct TamagotchiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Chicken Action Animation

enum ChickenActionAnimation {
    case feeding
    case playing
    case cleaning
}

// MARK: - Feeding Animation View

struct FeedingAnimationView: View {
    @State private var seedPositions: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (-20, -30, 0.0), (0, -35, 0.1), (20, -28, 0.2),
        (-15, -20, 0.15), (10, -25, 0.25)
    ]
    @State private var showSeeds = false
    @State private var seedsFalling = false
    
    var body: some View {
        ZStack {
            ForEach(0..<seedPositions.count, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.8, green: 0.6, blue: 0.3))
                    .frame(width: 8, height: 8)
                    .offset(
                        x: seedPositions[i].x,
                        y: showSeeds ? (seedsFalling ? 40 : seedPositions[i].y) : -60
                    )
                    .opacity(showSeeds ? (seedsFalling ? 0 : 1) : 0)
                    .animation(
                        .easeOut(duration: 0.3).delay(seedPositions[i].delay),
                        value: showSeeds
                    )
                    .animation(
                        .easeIn(duration: 0.4).delay(seedPositions[i].delay + 0.3),
                        value: seedsFalling
                    )
            }
        }
        .onAppear {
            showSeeds = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                seedsFalling = true
            }
        }
    }
}

// MARK: - Playing Animation View

struct PlayingAnimationView: View {
    @State private var hearts: [(x: CGFloat, y: CGFloat, scale: CGFloat)] = [
        (-25, -40, 0.8), (25, -45, 1.0), (0, -55, 0.9)
    ]
    @State private var showHearts = false
    @State private var heartsFloating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<hearts.count, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: 20 * hearts[i].scale))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.4))
                    .offset(
                        x: hearts[i].x,
                        y: showHearts ? (heartsFloating ? hearts[i].y - 30 : hearts[i].y) : hearts[i].y + 20
                    )
                    .opacity(showHearts ? (heartsFloating ? 0 : 1) : 0)
                    .scaleEffect(showHearts ? 1 : 0.3)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.15),
                        value: showHearts
                    )
                    .animation(
                        .easeOut(duration: 0.8).delay(Double(i) * 0.1),
                        value: heartsFloating
                    )
            }
        }
        .onAppear {
            showHearts = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                heartsFloating = true
            }
        }
    }
}

// MARK: - Cleaning Animation View

struct CleaningAnimationView: View {
    @State private var bubbles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (-30, 0, 12, 0.0), (30, -10, 10, 0.1), (-15, -25, 8, 0.2),
        (20, 15, 14, 0.15), (0, -15, 11, 0.25), (-25, 20, 9, 0.3)
    ]
    @State private var showBubbles = false
    @State private var bubblesPopping = false
    
    var body: some View {
        ZStack {
            ForEach(0..<bubbles.count, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.9), Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.6)],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: bubbles[i].size
                        )
                    )
                    .frame(width: bubbles[i].size, height: bubbles[i].size)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.6, green: 0.8, blue: 1.0).opacity(0.5), lineWidth: 1)
                    )
                    .offset(
                        x: bubbles[i].x,
                        y: showBubbles ? bubbles[i].y - (bubblesPopping ? 20 : 0) : bubbles[i].y + 30
                    )
                    .opacity(showBubbles ? (bubblesPopping ? 0 : 1) : 0)
                    .scaleEffect(showBubbles ? (bubblesPopping ? 1.5 : 1) : 0.3)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6).delay(bubbles[i].delay),
                        value: showBubbles
                    )
                    .animation(
                        .easeOut(duration: 0.3).delay(bubbles[i].delay),
                        value: bubblesPopping
                    )
            }
            
            // Sparkles
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                    .offset(
                        x: CGFloat([-35, 35, -20, 25][i]),
                        y: CGFloat([-35, -30, 10, 5][i])
                    )
                    .opacity(bubblesPopping ? 1 : 0)
                    .scaleEffect(bubblesPopping ? 1 : 0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5).delay(Double(i) * 0.1),
                        value: bubblesPopping
                    )
            }
        }
        .onAppear {
            showBubbles = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                bubblesPopping = true
            }
        }
    }
}

// MARK: - Tamagotchi Chicken View

struct TamagotchiChickenView: View {
    let isHappy: Bool
    let hasEgg: Bool
    var currentAnimation: ChickenActionAnimation? = nil
    
    @State private var bounce = false
    @State private var wiggle = false
    @State private var wingFlap = false
    @State private var headBob = false
    @State private var blinkEyes = false
    
    // Action-specific animation states
    @State private var isEating = false
    @State private var isPlayJumping = false
    @State private var isShaking = false
    
    // Colors
    private let bodyColor = Color(red: 1.0, green: 0.92, blue: 0.75)
    private let bodyStroke = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let wingColor = Color(red: 0.95, green: 0.85, blue: 0.65)
    private let combColor = Color(red: 0.9, green: 0.3, blue: 0.3)
    private let eyeColor = Color(red: 0.15, green: 0.15, blue: 0.15)
    private let beakColor = Color.orange
    private let eggColor = Color(red: 1.0, green: 0.97, blue: 0.9)
    
    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            
            ZStack {
                // Egg behind chicken
                if hasEgg {
                    eggShape
                        .position(x: centerX + 40, y: centerY + 25)
                }
                
                // Main chicken group - all positioned relative to center
                Group {
                    // Body
                    chickenBody
                        .position(x: centerX, y: centerY + 5)
                    
                    // Wing
                    chickenWing
                        .position(x: centerX + 18, y: centerY + (wingFlap && isHappy ? 0 : 8))
                    
                    // Head - pecks down when eating
                    chickenHead
                        .position(x: centerX - 18, y: centerY - 30 + (headBob && isHappy ? -5 : 0) + (isEating ? 15 : 0))
                    
                    // Comb
                    chickenComb
                        .position(x: centerX - 18, y: centerY - 60 + (headBob && isHappy ? -5 : 0) + (isEating ? 15 : 0))
                    
                    // Eyes
                    chickenEyes
                        .position(x: centerX - 18, y: centerY - 32 + (headBob && isHappy ? -5 : 0) + (isEating ? 15 : 0))
                    
                    // Beak
                    chickenBeak
                        .position(x: centerX - 42, y: centerY - 25 + (headBob && isHappy ? -5 : 0) + (isEating ? 15 : 0))
                    
                    // Feet
                    chickenFeet
                        .position(x: centerX, y: centerY + 45)
                }
                .offset(y: bounce ? -6 : (isPlayJumping ? -20 : 0))
                .rotationEffect(.degrees(wiggle && isHappy ? 2 : (wiggle ? -2 : 0)))
                .rotationEffect(.degrees(isShaking ? 5 : 0))
                .animation(.easeInOut(duration: 0.1).repeatCount(isShaking ? 10 : 0, autoreverses: true), value: isShaking)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: currentAnimation) { _, newAnimation in
            handleActionAnimation(newAnimation)
        }
    }
    
    private func handleActionAnimation(_ animation: ChickenActionAnimation?) {
        guard let animation = animation else { return }
        
        switch animation {
        case .feeding:
            // Pecking animation
            peckAnimation()
        case .playing:
            // Jump animation
            jumpAnimation()
        case .cleaning:
            // Shake animation
            shakeAnimation()
        }
    }
    
    private func peckAnimation() {
        // Peck down and up repeatedly
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isEating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isEating = false
                    }
                }
            }
        }
    }
    
    private func jumpAnimation() {
        // Happy jumps
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    isPlayJumping = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        isPlayJumping = false
                    }
                }
            }
        }
    }
    
    private func shakeAnimation() {
        // Shake off the bubbles
        withAnimation {
            isShaking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isShaking = false
        }
    }
    
    // MARK: - Chicken Parts
    
    private var eggShape: some View {
        Ellipse()
            .fill(eggColor)
            .frame(width: 28, height: 34)
            .overlay(
                Ellipse()
                    .stroke(bodyStroke.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
    
    private var chickenBody: some View {
        Ellipse()
            .fill(bodyColor)
            .frame(width: 80, height: 60)
            .overlay(
                Ellipse()
                    .stroke(bodyStroke, lineWidth: 2.5)
            )
    }
    
    private var chickenWing: some View {
        Ellipse()
            .fill(wingColor)
            .frame(width: 32, height: 26)
            .overlay(
                Ellipse()
                    .stroke(bodyStroke, lineWidth: 1.5)
            )
            .rotationEffect(.degrees(wingFlap && isHappy ? -15 : 0), anchor: .leading)
    }
    
    private var chickenHead: some View {
        Circle()
            .fill(bodyColor)
            .frame(width: 48, height: 48)
            .overlay(
                Circle()
                    .stroke(bodyStroke, lineWidth: 2.5)
            )
    }
    
    private var chickenComb: some View {
        HStack(spacing: -4) {
            Circle()
                .fill(combColor)
                .frame(width: 12, height: 12)
            Circle()
                .fill(combColor)
                .frame(width: 14, height: 14)
                .offset(y: -4)
            Circle()
                .fill(combColor)
                .frame(width: 10, height: 10)
        }
        .overlay(
            HStack(spacing: -4) {
                Circle()
                    .stroke(bodyStroke.opacity(0.5), lineWidth: 1)
                    .frame(width: 12, height: 12)
                Circle()
                    .stroke(bodyStroke.opacity(0.5), lineWidth: 1)
                    .frame(width: 14, height: 14)
                    .offset(y: -4)
                Circle()
                    .stroke(bodyStroke.opacity(0.5), lineWidth: 1)
                    .frame(width: 10, height: 10)
            }
        )
    }
    
    private var chickenEyes: some View {
        HStack(spacing: 12) {
            if isHappy {
                if blinkEyes {
                    // Blinking
                    Rectangle()
                        .fill(eyeColor)
                        .frame(width: 10, height: 2)
                    Rectangle()
                        .fill(eyeColor)
                        .frame(width: 10, height: 2)
                } else {
                    // Happy ^_^ eyes
                    happyEye
                    happyEye
                }
            } else {
                // Sad eyes
                Circle()
                    .fill(eyeColor)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(eyeColor)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var happyEye: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 6))
            path.addQuadCurve(
                to: CGPoint(x: 10, y: 6),
                control: CGPoint(x: 5, y: 0)
            )
        }
        .stroke(eyeColor, lineWidth: 2.5)
        .frame(width: 10, height: 8)
    }
    
    private var chickenBeak: some View {
        Path { path in
            path.move(to: CGPoint(x: 12, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 7))
            path.addLine(to: CGPoint(x: 12, y: 14))
            path.closeSubpath()
        }
        .fill(beakColor)
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: 12, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 7))
                path.addLine(to: CGPoint(x: 12, y: 14))
                path.closeSubpath()
            }
            .stroke(bodyStroke, lineWidth: 1.5)
        )
        .frame(width: 12, height: 14)
    }
    
    private var chickenFeet: some View {
        HStack(spacing: 20) {
            chickenFoot
            chickenFoot
        }
    }
    
    private var chickenFoot: some View {
        Path { path in
            path.move(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 12))
            path.move(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: 8, y: 14))
            path.move(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: 16, y: 12))
        }
        .stroke(beakColor, lineWidth: 2.5)
        .frame(width: 16, height: 14)
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Gentle bounce for all chickens
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            bounce = true
        }
        
        // Happy chickens get extra animations
        if isHappy {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                wiggle = true
            }
            
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                wingFlap = true
            }
            
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                headBob = true
            }
            
            // Periodic blinking
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.08)) {
                    blinkEyes = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        blinkEyes = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChickenDetailSheet(
        slot: ChickenSlot(
            slotIndex: 0,
            status: "alive",
            icon: "bird.fill",
            color: "yellow",
            label: "Clucky",
            name: "Clucky",
            canRename: true,
            stats: ChickenTamagotchiStats(hunger: 75, happiness: 90, cleanliness: 60),
            overallStatus: "happy",
            needsAttention: false,
            minStatForEggs: 50,
            actions: [
                ChickenAction(actionId: "feed", label: "Feed", icon: "fork.knife", stat: "hunger", goldCost: 5, restoreAmount: 25),
                ChickenAction(actionId: "play", label: "Play", icon: "heart.fill", stat: "happiness", goldCost: 5, restoreAmount: 25),
                ChickenAction(actionId: "clean", label: "Clean", icon: "sparkles", stat: "cleanliness", goldCost: 5, restoreAmount: 25)
            ],
            eggsAvailable: 2,
            totalEggsLaid: 15,
            secondsUntilEgg: 3600,
            incubationStartedAt: nil,
            hatchTime: nil,
            secondsUntilHatch: nil,
            progressPercent: nil,
            canHatch: false,
            canName: false,
            canCollect: true
        ),
        currentTime: Date(),
        onAction: { _ in },
        onCollect: { },
        onName: { }
    )
}
