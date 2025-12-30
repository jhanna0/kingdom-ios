import SwiftUI

/// Celebratory popup shown when a player successfully claims a kingdom
struct KingdomClaimCelebration: View {
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
                // Animated crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .rotationEffect(.degrees(crownRotation))
                    .shadow(color: KingdomTheme.Colors.gold.opacity(0.5), radius: 20)
                
                // Main message
                VStack(spacing: 8) {
                    Text("Hail!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("Ruler of")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text(kingdomName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Decorative divider
                Divider()
                    .background(KingdomTheme.Colors.divider)
                    .padding(.horizontal, 40)
                
                // Flavor text
                Text("Your reign begins")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .italic()
                
                // Dismiss button
                Button(action: {
                    dismissWithAnimation()
                }) {
                    Text("Long Live the Ruler!")
                        .font(KingdomTheme.Typography.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KingdomTheme.Colors.buttonPrimary)
                        .cornerRadius(KingdomTheme.CornerRadius.medium)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(KingdomTheme.Colors.parchment)
                    .shadow(color: .black.opacity(0.3), radius: 20)
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
            kingdomName: "San Francisco",
            onDismiss: {}
        )
    }
}

