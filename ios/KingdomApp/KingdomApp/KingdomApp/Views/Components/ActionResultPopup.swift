import SwiftUI

/// Generic themed popup for action results (success or failure)
/// Replaces boring .alert() with Kingdom-styled brutalist popup
struct ActionResultPopup: View {
    let success: Bool
    let title: String
    let message: String
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Icon with brutalist style
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 70, height: 70)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: success ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, options: .speed(0.5))
                }
                .padding(.top, 8)
                
                // Title
                Text(title)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                
                // Message
                Text(message)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Dismiss button
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
}

#Preview("Success") {
    ActionResultPopup(
        success: true,
        title: "Operation Successful!",
        message: "Infiltration in progress...",
        isShowing: .constant(true)
    )
}

#Preview("Failure") {
    ActionResultPopup(
        success: false,
        title: "Operation Failed",
        message: "Enemy patrols (3) were too vigilant.",
        isShowing: .constant(true)
    )
}
