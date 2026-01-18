import SwiftUI

/// Slot machine style popup for scout/infiltration results
/// Shows 4 spinning digits that land on 0000 for success or random for failure
struct ScoutResultPopup: View {
    let success: Bool
    let title: String
    let message: String
    @Binding var isShowing: Bool
    
    // Animation states
    @State private var digit1: Int = Int.random(in: 0...9)
    @State private var digit2: Int = Int.random(in: 0...9)
    @State private var digit3: Int = Int.random(in: 0...9)
    @State private var digit4: Int = Int.random(in: 0...9)
    @State private var isSpinning = true
    @State private var showResult = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    // Spin timers
    @State private var spinTimer: Timer?
    
    private let spinDuration: Double = 1.8
    private let spinInterval: Double = 0.08
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Header icon
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 60, height: 60)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.royalEmerald)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: "eye.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
                
                // Title
                Text("INFILTRATION")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .tracking(2)
                
                // Slot machine digits
                HStack(spacing: 12) {
                    digitBox(digit: digit1)
                    digitBox(digit: digit2)
                    digitBox(digit: digit3)
                    digitBox(digit: digit4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                // Result text (appears after spin)
                if showResult {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                            
                            Text(title)
                                .font(FontStyles.headingSmall)
                                .foregroundColor(success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                        }
                        
                        Text(message)
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                // Dismiss button (appears after spin)
                if showResult {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }) {
                        Text("Continue")
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 12)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            .padding(.horizontal, 28)
            .scaleEffect(scale)
            .opacity(opacity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            KingdomTheme.Colors.mapWarGradientDark
                .ignoresSafeArea()
        )
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            spinTimer?.invalidate()
        }
    }
    
    // MARK: - Digit Box
    
    private func digitBox(digit: Int) -> some View {
        ZStack {
            // Shadow offset
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: 48, height: 64)
                .offset(x: 2, y: 2)
            
            // Background - using theme war colors (dark smoky brown)
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            KingdomTheme.Colors.mapWarBase,
                            KingdomTheme.Colors.mapWarGradientDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 48, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 2)
                )
            
            // Digit
            Text("\(digit)")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(digitColor(digit: digit))
        }
    }
    
    private func digitColor(digit: Int) -> Color {
        if !showResult {
            return .white
        }
        return success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        // Fade in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Start spinning
        spinTimer = Timer.scheduledTimer(withTimeInterval: spinInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.05)) {
                digit1 = Int.random(in: 0...9)
                digit2 = Int.random(in: 0...9)
                digit3 = Int.random(in: 0...9)
                digit4 = Int.random(in: 0...9)
            }
        }
        
        // Stop spinning after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            spinTimer?.invalidate()
            
            // Land on final values
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if success {
                    // Success: 0 0 0 0
                    digit1 = 0
                    digit2 = 0
                    digit3 = 0
                    digit4 = 0
                } else {
                    // Failure: random non-zero combination
                    digit1 = Int.random(in: 1...9)
                    digit2 = Int.random(in: 1...9)
                    digit3 = Int.random(in: 1...9)
                    digit4 = Int.random(in: 1...9)
                }
            }
            
            // Show result text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showResult = true
                }
            }
        }
    }
}

#Preview("Success") {
    ScoutResultPopup(
        success: true,
        title: "Success!",
        message: "Gathered military intel on Kingdom of Eldoria!",
        isShowing: .constant(true)
    )
}

#Preview("Failure") {
    ScoutResultPopup(
        success: false,
        title: "Detected!",
        message: "The enemy patrol was too strong. Lost 10 reputation.",
        isShowing: .constant(true)
    )
}
