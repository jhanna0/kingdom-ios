import SwiftUI

// MARK: - Streak Bonus Popup
// Full-screen celebration popup when streak bonus activates
// ALL display data comes from backend!

struct StreakBonusPopup: View {
    let title: String
    let subtitle: String
    let description: String
    let multiplier: Int
    let icon: String
    let color: String
    let dismissButton: String
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var iconScale: CGFloat = 0.5
    
    private var themeColor: Color {
        KingdomTheme.Colors.color(fromThemeName: color)
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Content card
            VStack(spacing: 16) {
                // Icon burst
                ZStack {
                    // Glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(themeColor.opacity(0.3 - Double(i) * 0.1), lineWidth: 3)
                            .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                            .scaleEffect(showContent ? 1.0 : 0.5)
                            .opacity(showContent ? 1.0 : 0.0)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.6)
                                .delay(Double(i) * 0.1),
                                value: showContent
                            )
                    }
                    
                    // Main icon
                    Image(systemName: icon)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.orange,
                                    themeColor
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(iconScale)
                        .shadow(color: themeColor.opacity(0.6), radius: 10)
                }
                .frame(height: 120)
                
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundColor(themeColor)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Bonus display
                HStack(spacing: 8) {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("\(multiplier)×")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(themeColor)
                        )
                }
                .padding(.top, 4)
                
                Button {
                    dismiss()
                } label: {
                    Text(dismissButton)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: themeColor,
                    foregroundColor: .white,
                    fullWidth: true
                ))
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 280)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 20)
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.5)
                .delay(0.2)
            ) {
                iconScale = 1.0
            }
            // Auto-pulse the icon
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
                .delay(0.5)
            ) {
                iconScale = 1.1
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Popup") {
    StreakBonusPopup(
        title: "HOT STREAK!",
        subtitle: "2x Meat",
        description: "3 catches in a row!",
        multiplier: 2,
        icon: "flame.fill",
        color: "buttonDanger",
        dismissButton: "Nice!"
    ) {
        print("Dismissed")
    }
}
