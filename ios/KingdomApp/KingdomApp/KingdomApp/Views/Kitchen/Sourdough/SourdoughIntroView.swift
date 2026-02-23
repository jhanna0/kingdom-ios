import SwiftUI

// MARK: - Intro Step View

struct IntroStepView: View {
    let onStart: () -> Void
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Cute bread animation
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.orange.opacity(0.3), Color.clear], center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animate ? 1.1 : 1.0)
                
                BreadLoafShape()
                    .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.65, blue: 0.35), Color(red: 0.7, green: 0.5, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 110, height: 75)
                    .overlay(
                        VStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule()
                                    .fill(Color(red: 0.55, green: 0.35, blue: 0.15))
                                    .frame(width: 60, height: 5)
                                    .rotationEffect(.degrees(-15))
                            }
                        }
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .rotationEffect(.degrees(animate ? 3 : -3))
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
            
            Spacer()
            
            // Simple prompt
            VStack(spacing: 16) {
                Text("Would you like to start\nmaking some bread?")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    HapticService.shared.mediumImpact()
                    onStart()
                } label: {
                    Text("Let's Bake")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color.black).offset(x: 4, y: 4)
                        RoundedRectangle(cornerRadius: 14).fill(KingdomTheme.Colors.buttonWarning)
                        RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 3)
                    }
                )
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .onAppear { animate = true }
    }
}

// MARK: - Bread Loaf Shape

struct BreadLoafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h * 0.7))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h * 0.7), control: CGPoint(x: w, y: 0))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h), control: CGPoint(x: w, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h * 0.7), control: CGPoint(x: 0, y: h))
        
        return path
    }
}

#Preview {
    IntroStepView(onStart: {})
}
