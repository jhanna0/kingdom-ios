import SwiftUI

// MARK: - Intro Step View

struct IntroStepView: View {
    let onStart: () -> Void
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.orange.opacity(0.3), Color.clear], center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                    .scaleEffect(animate ? 1.1 : 1.0)
                
                // Bread loaf
                BreadLoafShape()
                    .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.65, blue: 0.35), Color(red: 0.7, green: 0.5, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 90, height: 60)
                    .overlay(
                        // Score marks
                        VStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule()
                                    .fill(Color(red: 0.55, green: 0.35, blue: 0.15))
                                    .frame(width: 50, height: 4)
                                    .rotationEffect(.degrees(-15))
                            }
                        }
                    )
                    .rotationEffect(.degrees(animate ? 3 : -3))
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
            
            Text("Let's Make Sourdough!")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("A real baker's journey awaits.")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            VStack(alignment: .leading, spacing: 10) {
                stepRow(num: "1", text: "Grind wheat into flour", icon: "gearshape.2.fill")
                stepRow(num: "2", text: "Mix the sourdough starter", icon: "plus.circle.fill")
                stepRow(num: "3", text: "Knead & develop gluten", icon: "hand.raised.fill")
                stepRow(num: "4", text: "Shape into a boule", icon: "circle.fill")
                stepRow(num: "5", text: "Score the top", icon: "pencil.tip")
                stepRow(num: "6", text: "Bake to perfection", icon: "flame.fill")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2))
            )
            .padding(.horizontal, 30)
            
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onStart()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Baking!")
                        .font(FontStyles.headingSmall)
                }
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
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .onAppear { animate = true }
    }
    
    private func stepRow(num: String, text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(KingdomTheme.Colors.buttonWarning))
            
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 20)
            
            Text(text)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
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
