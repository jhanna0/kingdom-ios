import SwiftUI

/// Custom confirmation popup for battles (coups/invasions)
/// Shows detailed explanation and risk warning with Confirm/Cancel buttons
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
            
            ScrollView {
                VStack(spacing: 16) {
                    // Warning icon with brutalist style
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 60, height: 60)
                            .offset(x: 3, y: 3)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.buttonDanger)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Image(systemName: isInvasion ? "flag.2.crossed.fill" : "bolt.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                    
                    // Title
                    Text(title)
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                    
                    // How it works section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How It Works")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if isInvasion {
                            infoRow(icon: "clock.fill", text: "Battle scheduled 24 hours from now", color: KingdomTheme.Colors.royalBlue)
                            infoRow(icon: "person.3.fill", text: "Anyone can pledge troops to either side", color: KingdomTheme.Colors.royalBlue)
                            infoRow(icon: "dollarsign.circle.fill", text: "Pledge gold to add soldiers to your side", color: KingdomTheme.Colors.royalBlue)
                            infoRow(icon: "flag.fill", text: "Winner takes control of the territory", color: KingdomTheme.Colors.royalBlue)
                        } else {
                            infoRow(icon: "clock.fill", text: "Battle scheduled 24 hours from now", color: KingdomTheme.Colors.royalBlue)
                            infoRow(icon: "person.3.fill", text: "Citizens pledge to support or defend ruler", color: KingdomTheme.Colors.royalBlue)
                            infoRow(icon: "dollarsign.circle.fill", text: "Pledge gold to add soldiers to your side", color: KingdomTheme.Colors.royalBlue)
                            infoRow(icon: "crown.fill", text: "Winner becomes the new ruler", color: KingdomTheme.Colors.royalBlue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.royalBlue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KingdomTheme.Colors.royalBlue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // Risk warning section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Risks")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        infoRow(
                            icon: "exclamationmark.triangle.fill",
                            text: "Losers forfeit all pledged gold",
                            color: KingdomTheme.Colors.buttonDanger
                        )
                        
                        if isInvasion {
                            infoRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "Defenders lose territory if defeated",
                                color: KingdomTheme.Colors.buttonDanger
                            )
                        } else {
                            infoRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "Ruler loses crown if defeated",
                                color: KingdomTheme.Colors.buttonDanger
                            )
                        }
                        
                        infoRow(
                            icon: "checkmark.circle.fill",
                            text: "Winners split the enemy's pledged gold",
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonDanger.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KingdomTheme.Colors.buttonDanger.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
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
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
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
            .padding(.horizontal, 24)
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
    
    private func infoRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .fixedSize(horizontal: false, vertical: true)
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
