import SwiftUI

/// Specialized success popup for property fortification
/// Shows a clean table layout for Gain, Start, and Finish percentages
struct FortifyResultPopup: View {
    let result: PropertyAPI.FortifyResponse
    let title: String
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                // Success Seal Icon
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 70, height: 70)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.buttonSuccess)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, options: .speed(0.5))
                }
                .padding(.top, 8)
                
                // Title & Item Message
                VStack(spacing: 8) {
                    Text(title)
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("\(result.item_consumed) converted successfully.")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                // Stats Table (Gain, Start, Finish)
                HStack(spacing: 0) {
                    statColumn(label: "GAIN", value: "+\(result.fortification_gain)%", color: KingdomTheme.Colors.buttonSuccess)
                    
                    divider
                    
                    statColumn(label: "START", value: "\(result.fortification_before)%", color: KingdomTheme.Colors.inkMedium)
                    
                    divider
                    
                    statColumn(label: "FINISH", value: "\(result.fortification_after)%", color: KingdomTheme.Colors.royalBlue)
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KingdomTheme.Colors.parchment.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KingdomTheme.Colors.border.opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                
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
    
    private var divider: some View {
        Rectangle()
            .fill(KingdomTheme.Colors.divider.opacity(0.3))
            .frame(width: 1, height: 40)
    }
    
    private func statColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text(value)
                .font(FontStyles.statLarge)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}
