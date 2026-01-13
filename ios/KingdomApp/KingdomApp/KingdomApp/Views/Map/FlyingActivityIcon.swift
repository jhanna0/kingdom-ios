import SwiftUI

/// A single activity icon that flies outward from the kingdom marker and fades out
struct FlyingActivityIcon: View {
    let icon: String
    let color: Color
    let angle: Double  // Direction in degrees (0 = right, 90 = up)
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    // Animation parameters
    private let flyDistance: CGFloat = 60
    private let duration: Double = 1.6
    
    private var offset: CGSize {
        let radians = angle * .pi / 180
        let x = cos(radians) * flyDistance * progress
        let y = -sin(radians) * flyDistance * progress  // Negative for screen coords
        return CGSize(width: x, height: y)
    }
    
    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(Color.black)
                .frame(width: 22, height: 22)
                .offset(x: 2, y: 2)
            
            // Icon background
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                )
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .offset(offset)
        .scaleEffect(1.0 + progress * 0.3)  // Grow slightly as it flies
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: duration)) {
                progress = 1.0
            }
            withAnimation(.easeIn(duration: duration * 0.8).delay(duration * 0.2)) {
                opacity = 0
            }
            
            // Cleanup after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                onComplete()
            }
        }
    }
}

// MARK: - Flying Icon Data Model

struct FlyingIconData: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let angle: Double
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        
        // Sample flying icons
        FlyingActivityIcon(
            icon: "hammer.fill",
            color: .blue,
            angle: 45,
            onComplete: {}
        )
        
        FlyingActivityIcon(
            icon: "eye.fill",
            color: .yellow,
            angle: 135,
            onComplete: {}
        )
    }
}

