import SwiftUI

/// Beautiful aged parchment background with visible texture
struct ParchmentBackground: View {
    // Texture configuration
    private enum Texture {
        static let horizontalLineSpacing: CGFloat = 4
        static let horizontalLineWidth: CGFloat = 1.2
        static let horizontalLineOpacity: Double = 0.35
        
        static let verticalLineSpacing: CGFloat = 6
        static let verticalLineWidth: CGFloat = 1.0
        static let verticalLineOpacity: Double = 0.25
        
        static let speckleSpacing: Int = 10
        static let speckleSize: CGFloat = 2.5
        static let speckleOpacity: Double = 0.4
    }
    
    // Color configuration
    private enum Colors {
        static let base = Color(red: 0.85, green: 0.77, blue: 0.63)
        static let gradientLight = Color(red: 0.88, green: 0.80, blue: 0.66)
        static let gradientDark = Color(red: 0.80, green: 0.72, blue: 0.58)
        static let textureColor = Color.brown
    }
    
    var body: some View {
        ZStack {
            // Base tan color
            Colors.base
            
            // Paper texture overlay
            textureCanvas
            
            // Color variation gradient
            colorGradient
            
            // Vignette effect
            vignetteOverlay
        }
        .ignoresSafeArea()
    }
    
    private var textureCanvas: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawHorizontalGrain(context: context, size: size)
                drawVerticalFibers(context: context, size: size)
                drawSpeckles(context: context, size: size)
            }
        }
    }
    
    private func drawHorizontalGrain(context: GraphicsContext, size: CGSize) {
        var y: CGFloat = 0
        while y < size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                path,
                with: .color(Colors.textureColor.opacity(Texture.horizontalLineOpacity)),
                lineWidth: Texture.horizontalLineWidth
            )
            y += Texture.horizontalLineSpacing
        }
    }
    
    private func drawVerticalFibers(context: GraphicsContext, size: CGSize) {
        var x: CGFloat = 0
        while x < size.width {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
                path,
                with: .color(Colors.textureColor.opacity(Texture.verticalLineOpacity)),
                lineWidth: Texture.verticalLineWidth
            )
            x += Texture.verticalLineSpacing
        }
    }
    
    private func drawSpeckles(context: GraphicsContext, size: CGSize) {
        for gridY in stride(from: 0, to: Int(size.height), by: Texture.speckleSpacing) {
            for gridX in stride(from: 0, to: Int(size.width), by: Texture.speckleSpacing) {
                let rect = CGRect(
                    x: CGFloat(gridX),
                    y: CGFloat(gridY),
                    width: Texture.speckleSize,
                    height: Texture.speckleSize
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Colors.textureColor.opacity(Texture.speckleOpacity))
                )
            }
        }
    }
    
    private var colorGradient: some View {
        LinearGradient(
            colors: [
                Colors.gradientLight.opacity(0.3),
                Colors.gradientDark.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var vignetteOverlay: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.2)
                    ],
                    center: .center,
                    startRadius: 150,
                    endRadius: 500
                )
            )
    }
}

#Preview {
    ParchmentBackground()
}

