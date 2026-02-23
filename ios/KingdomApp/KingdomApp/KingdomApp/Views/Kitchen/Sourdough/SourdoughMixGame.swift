import SwiftUI

// MARK: - Mix Starter Game

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
        VStack(spacing: 0) {
            Text(ingredientsAdded.count < 3 ? "Drag each ingredient into the bowl" : "Swirl your finger through the dough!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // Progress bar (always shown)
            VStack(spacing: 4) {
                HStack {
                    Text(ingredientsAdded.count < 3 ? "Ingredients" : "Mixing")
                    Spacer()
                    Text(ingredientsAdded.count < 3 ? "\(ingredientsAdded.count)/3" : "\(Int(min(100, mixingProgress * 100)))%")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonWarning)
                            .frame(width: geo.size.width * (ingredientsAdded.count < 3 ? CGFloat(ingredientsAdded.count) / 3.0 : mixingProgress))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
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
                            HapticService.shared.mediumImpact()
                            spawnIngredientSplash(type: "flour", center: bowlCenter)
                        }
                        .position(x: 70, y: 70)
                    }
                    
                    if !ingredientsAdded.contains("water") {
                        DraggableIngredient(name: "Water", color: Color.blue.opacity(0.5), icon: "drop.fill", position: CGPoint(x: geo.size.width - 70, y: 70)) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                ingredientsAdded.insert("water")
                            }
                            HapticService.shared.mediumImpact()
                            spawnIngredientSplash(type: "water", center: bowlCenter)
                        }
                        .position(x: geo.size.width - 70, y: 70)
                    }
                    
                    if !ingredientsAdded.contains("starter") {
                        DraggableIngredient(name: "Starter", color: Color(red: 0.9, green: 0.85, blue: 0.75), icon: "bubbles.and.sparkles", position: CGPoint(x: geo.size.width / 2, y: 60)) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                ingredientsAdded.insert("starter")
                            }
                            HapticService.shared.mediumImpact()
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
            .frame(maxHeight: 450)
            
            // Ingredients status
            HStack(spacing: 20) {
                ForEach(allIngredients, id: \.self) { ingredient in
                    HStack(spacing: 4) {
                        Image(systemName: ingredientsAdded.contains(ingredient) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(ingredientsAdded.contains(ingredient) ? KingdomTheme.Colors.buttonSuccess : .gray)
                        Text(ingredient.capitalized)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            .padding(.vertical, 16)
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
            HapticService.shared.softImpact()
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

// MARK: - Supporting Types

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

#Preview {
    MixStarterGameView(onComplete: { _ in })
}
