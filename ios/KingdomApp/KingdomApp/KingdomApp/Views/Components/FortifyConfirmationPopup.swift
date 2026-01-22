import SwiftUI

/// Custom confirmation popup for property fortification (gear sacrifice)
/// Shows item details and gain range with themed Confirm/Cancel buttons
struct FortifyConfirmationPopup: View {
    let item: PropertyAPI.FortifyOptionItem
    let explanation: PropertyAPI.FortificationExplanation
    @Binding var isShowing: Bool
    let onConfirm: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon with brutalist style
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(item.type == "weapon" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
                
                // Title & Description
                VStack(spacing: 8) {
                    Text(explanation.ui.confirmation_title)
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    let itemName = item.count > 1 ? "one of your \(item.display_name)s" : "your \(item.display_name)"
                    Text("Sacrifice \(itemName) to strengthen your property's defenses.")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Stats Card
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EQUIPMENT")
                            .font(FontStyles.labelTiny)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text("Tier \(item.tier)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.divider.opacity(0.3))
                        .frame(width: 1, height: 40)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ESTIMATED GAIN")
                            .font(FontStyles.labelTiny)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text(item.gainRange)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KingdomTheme.Colors.parchment.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KingdomTheme.Colors.border.opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                
                // Warning text
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        .font(.system(size: 14))
                    
                    Text("This item will be permanently consumed.")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                        onConfirm()
                    }) {
                        Text(explanation.ui.confirmation_confirm_label)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonDanger, fullWidth: true))
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }) {
                        Text(explanation.ui.confirmation_cancel_label)
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.top, 4)
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
}
