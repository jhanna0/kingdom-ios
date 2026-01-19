import SwiftUI

/// Custom confirmation popup for battles (coups/invasions)
/// Shows risk warning with Confirm/Cancel buttons
struct BattleConfirmationPopup: View {
    let title: String
    let isInvasion: Bool
    @Binding var isShowing: Bool
    let onConfirm: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Warning icon with brutalist style
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 70, height: 70)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.buttonDanger)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: isInvasion ? "flag.2.crossed.fill" : "bolt.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
                
                // Title
                Text(title)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                
                // Risk warning
                VStack(alignment: .leading, spacing: 12) {
                    riskRow(
                        icon: "exclamationmark.triangle.fill",
                        text: "Attackers risk losing their money",
                        color: KingdomTheme.Colors.imperialGold
                    )
                    
                    riskRow(
                        icon: "exclamationmark.triangle.fill", 
                        text: "Defenders risk losing their land and money",
                        color: KingdomTheme.Colors.buttonDanger
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KingdomTheme.Colors.parchmentMuted)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KingdomTheme.Colors.inkLight, lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                
                // Tutorial hint
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    Text("Read the tutorial for full details")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    // Cancel button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }) {
                        Text("Cancel")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black)
                                .offset(x: 2, y: 2)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(KingdomTheme.Colors.parchmentLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                    )
                    
                    // Confirm button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                        onConfirm()
                    }) {
                        Text("Confirm")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black)
                                .offset(x: 2, y: 2)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(KingdomTheme.Colors.buttonDanger)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 28)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
            .shadow(
                color: KingdomTheme.Shadows.brutalistSoft.color,
                radius: KingdomTheme.Shadows.brutalistSoft.radius,
                x: KingdomTheme.Shadows.brutalistSoft.x,
                y: KingdomTheme.Shadows.brutalistSoft.y
            )
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .opacity(opacity)
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func riskRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(text)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}

#Preview("Invasion") {
    BattleConfirmationPopup(
        title: "Declare Invasion",
        isInvasion: true,
        isShowing: .constant(true),
        onConfirm: {}
    )
}

#Preview("Coup") {
    BattleConfirmationPopup(
        title: "Stage Coup",
        isInvasion: false,
        isShowing: .constant(true),
        onConfirm: {}
    )
}
