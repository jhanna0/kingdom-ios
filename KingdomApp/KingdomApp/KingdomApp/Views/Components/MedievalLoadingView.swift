import SwiftUI

struct MedievalLoadingView: View {
    let status: String
    
    @State private var compassRotation: Double = 0
    @State private var quillBounce: CGFloat = 0
    @State private var dotPhase: Int = 0
    @State private var currentQuote: String = ""
    
    private let medievalQuotes = [
        "By quill and compass...",
        "The scribes work diligently...",
        "Mapping uncharted lands...",
        "Consulting the ancient tomes...",
        "The kingdom awaits..."
    ]
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            // Animated compass/scroll icon
            ZStack {
                // Compass rose background - rotating
                Image(systemName: "safari")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(KingdomTheme.Colors.inkLight.opacity(0.3))
                    .rotationEffect(.degrees(compassRotation))
                
                // Quill writing animation - bouncing
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    .offset(y: quillBounce)
            }
            .frame(height: 60)
            
            // Status text with medieval styling
            Text(status)
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .multilineTextAlignment(.center)
            
            // Rotating medieval quote
            Text(currentQuote)
                .font(KingdomTheme.Typography.caption())
                .italic()
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .transition(.opacity)
                .id(currentQuote)
            
            // Medieval-style progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(KingdomTheme.Colors.buttonPrimary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotPhase == index ? 1.5 : 1.0)
                        .opacity(dotPhase == index ? 1.0 : 0.5)
                }
            }
        }
        .padding(.horizontal, KingdomTheme.Spacing.xxLarge)
        .padding(.vertical, KingdomTheme.Spacing.xLarge)
        .parchmentCard(cornerRadius: KingdomTheme.CornerRadius.xxLarge)
        .shadow(color: KingdomTheme.Shadows.overlay.color, radius: KingdomTheme.Shadows.overlay.radius)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Set initial quote
        currentQuote = medievalQuotes.randomElement() ?? medievalQuotes[0]
        
        // Gentle compass rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            compassRotation = 360
        }
        
        // Quill bouncing motion
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            quillBounce = -8
        }
        
        // Animated dots
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotPhase = (dotPhase + 1) % 3
            }
        }
        
        // Rotating quotes
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentQuote = medievalQuotes.randomElement() ?? medievalQuotes[0]
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        MedievalLoadingView(status: "Unrolling ancient scrolls...")
    }
}

