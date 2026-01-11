import SwiftUI

/// Beautiful aged parchment background with visible texture
/// Supports war/charred mode for coup/invasion states
struct ParchmentBackground: View {
    /// When true, displays charred/on-fire appearance for coup/invasion
    var isWarMode: Bool = false
    
    // Texture configuration - Subtle texture
    private enum Texture {
        static let horizontalLineSpacing: CGFloat = 8
        static let horizontalLineWidth: CGFloat = 1.0
        static let horizontalLineOpacity: Double = 0.15
        
        static let verticalLineSpacing: CGFloat = 12
        static let verticalLineWidth: CGFloat = 0.8
        static let verticalLineOpacity: Double = 0.12
        
        static let speckleSpacing: Int = 20
        static let speckleSize: CGFloat = 2.0
        static let speckleOpacity: Double = 0.2
    }
    
    // Dynamic colors based on war mode
    private var baseColor: Color {
        isWarMode ? KingdomTheme.Colors.mapWarBase : KingdomTheme.Colors.mapPeaceBase
    }
    
    private var gradientLightColor: Color {
        isWarMode ? KingdomTheme.Colors.mapWarGradientLight : KingdomTheme.Colors.mapPeaceGradientLight
    }
    
    private var gradientDarkColor: Color {
        isWarMode ? KingdomTheme.Colors.mapWarGradientDark : KingdomTheme.Colors.mapPeaceGradientDark
    }
    
    private var textureColor: Color {
        isWarMode ? KingdomTheme.Colors.mapWarTexture : KingdomTheme.Colors.mapPeaceTexture
    }
    
    // War mode has a stronger vignette for more ominous feel
    private var vignetteOpacity: Double {
        isWarMode ? 0.4 : 0.2
    }
    
    var body: some View {
        ZStack {
            // Base color
            baseColor
            
            // Paper texture overlay
            textureCanvas
            
            // Color variation gradient
            colorGradient
            
            // Vignette effect
            vignetteOverlay
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: isWarMode)
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
                with: .color(textureColor.opacity(Texture.horizontalLineOpacity)),
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
                with: .color(textureColor.opacity(Texture.verticalLineOpacity)),
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
                    with: .color(textureColor.opacity(Texture.speckleOpacity))
                )
            }
        }
    }
    
    private var colorGradient: some View {
        LinearGradient(
            colors: [
                gradientLightColor.opacity(0.2),
                gradientDarkColor.opacity(0.2)
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
                        Color.black.opacity(vignetteOpacity)
                    ],
                    center: .center,
                    startRadius: 150,
                    endRadius: 500
                )
            )
    }
}

#Preview("Peaceful") {
    ParchmentBackground(isWarMode: false)
}

#Preview("War Mode") {
    ParchmentBackground(isWarMode: true)
}

