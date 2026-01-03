import SwiftUI

/// Celebratory popup shown when a player successfully claims a kingdom
struct KingdomClaimCelebration: View {
    let playerName: String
    let kingdomName: String
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var crownRotation: Double = -20
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }
            
            VStack(spacing: 24) {
                // Animated crown icon with brutalist badge
                ZStack {
                    // Crown background badge
                    Circle()
                        .fill(Color.black)
                        .frame(width: 110, height: 110)
                        .offset(x: 4, y: 4)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.error)
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(crownRotation))
                }
                
                // Main message
                VStack(spacing: 8) {
                    Text("HAIL \(playerName)!")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.black)
                        .tracking(2)
                        .multilineTextAlignment(.center)
                    
                    Text("Ruler of")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                    
                    Text(kingdomName)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Decorative divider - thick black
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal, 40)
                
                // Flavor text
                Text("Your reign begins")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.5))
                    .italic()
                
                // Dismiss button - brutalist style
                Button(action: {
                    dismissWithAnimation()
                }) {
                    ZStack {
                        // Button shadow
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                            .fill(Color.black)
                            .offset(x: 4, y: 4)
                        
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                            .fill(KingdomTheme.Colors.buttonPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Text("Long Live the Ruler!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                    }
                    .frame(height: 52)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                ZStack {
                    // Brutalist offset shadow
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusLarge)
                        .fill(Color.black)
                        .offset(x: 6, y: 6)
                    
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusLarge)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusLarge)
                                .stroke(Color.black, lineWidth: 4)
                        )
                }
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 24)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Crown wiggle animation
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                crownRotation = 20
            }
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.9
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Preview

struct KingdomClaimCelebration_Previews: PreviewProvider {
    static var previews: some View {
        KingdomClaimCelebration(
            playerName: "Gerard",
            kingdomName: "San Francisco",
            onDismiss: {}
        )
    }
}

