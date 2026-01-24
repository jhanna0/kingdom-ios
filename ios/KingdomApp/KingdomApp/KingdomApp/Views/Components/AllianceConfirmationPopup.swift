import SwiftUI

/// Custom confirmation popup for proposing alliances
/// Shows detailed explanation of alliance benefits with Confirm/Cancel buttons
struct AllianceConfirmationPopup: View {
    let targetKingdomName: String
    @Binding var isShowing: Bool
    let onConfirm: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Alliance icon with brutalist style
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 60, height: 60)
                            .offset(x: 3, y: 3)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                    
                    // Title
                    Text("Propose Alliance")
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                    
                    Text("with \(targetKingdomName)")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // How it works section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How Alliances Work")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        infoRow(icon: "envelope.fill", text: "Target ruler must accept your proposal", color: KingdomTheme.Colors.royalBlue)
                        infoRow(icon: "calendar", text: "Alliance lasts 30 days once accepted", color: KingdomTheme.Colors.royalBlue)
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
                    
                    // Benefits section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alliance Benefits")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        infoRow(
                            icon: "shield.fill",
                            text: "Help defend allies during invasions",
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                        infoRow(
                            icon: "flag.fill",
                            text: "Join allies in attacking other kingdoms. Share the spoils of war",
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                        infoRow(
                            icon: "building.2.fill",
                            text: "Use buildings in allied territories",
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                        infoRow(
                            icon: "bell.fill",
                            text: "Receive alerts when allies are attacked",
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.buttonSuccess.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KingdomTheme.Colors.buttonSuccess.opacity(0.3), lineWidth: 1)
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
                            Text("Send Proposal")
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
                                    .fill(KingdomTheme.Colors.buttonSuccess)
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
            .frame(maxHeight: 520)
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

#Preview {
    AllianceConfirmationPopup(
        targetKingdomName: "Henniker",
        isShowing: .constant(true),
        onConfirm: {}
    )
}
