import SwiftUI

// MARK: - Bake Game

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
            Text(phaseSubtitle)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)
                .padding(.horizontal, 20)
            
            // Progress indicator (matches other steps)
            VStack(spacing: 4) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text("\(Int(ovenTemp * 450 + 50))°F")
                        .font(FontStyles.labelBold)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal, 20)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * ovenTemp)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 20)
                .padding(.horizontal, 20)
            }
            
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
            
            Spacer()
        }
        .onAppear { startBaking() }
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
                    
                    // Auto-complete after showing the done state briefly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onComplete()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct BakeCrack: Identifiable {
    let id = UUID()
    let length: CGFloat
    let angle: Double
    let offset: CGPoint
    let opacity: Double
}

#Preview {
    BakeGameView(onComplete: {})
}
