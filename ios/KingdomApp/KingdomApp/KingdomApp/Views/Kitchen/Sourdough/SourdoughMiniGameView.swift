import SwiftUI

/// Cooking Mama-style sourdough bread making mini-game!
/// Each step is a real mini-game with 20-40 seconds of gameplay
struct SourdoughMiniGameView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStep: SourdoughStep = .intro
    @State private var showStepComplete = false
    
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
                
                Text(currentStep == .intro ? "Making Bread" : currentStep.displayName)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                // Placeholder to match X button width for centering
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            progressIndicator
        }
        .padding(.bottom, 12)
        .background(Color(red: 0.85, green: 0.75, blue: 0.60))
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
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                
                Text(currentStep.completionMessage)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(KingdomTheme.Colors.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
            )
            .padding(40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    showStepComplete = false
                    advanceStep()
                }
            }
        }
    }
    
    private func completeStep(score: Int) {
        HapticService.shared.success()
        
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
        case .grindWheat: return "Fresh Flour!"
        case .mixStarter: return "Starter Mixed!"
        case .knead: return "Gluten Developed!"
        case .shape: return "Perfect Shape!"
        case .score: return "Beautifully Scored!"
        case .bake: return ""
        }
    }
    
    var displayName: String {
        switch self {
        case .intro: return "Making Bread"
        case .grindWheat: return "Grind Wheat"
        case .mixStarter: return "Mix Starter"
        case .knead: return "Knead Dough"
        case .shape: return "Shape Boule"
        case .score: return "Score Bread"
        case .bake: return "Bake"
        }
    }
    
    var next: SourdoughStep? {
        SourdoughStep(rawValue: self.rawValue + 1)
    }
}

// MARK: - Preview

#Preview {
    SourdoughMiniGameView(
        onComplete: { print("Complete!") },
        onCancel: { print("Cancelled") }
    )
}
