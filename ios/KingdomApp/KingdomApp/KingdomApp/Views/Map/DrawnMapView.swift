import SwiftUI
import CoreLocation

/// Custom drawn map view - no Apple Maps, just illustrated kingdoms
struct DrawnMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var kingdomForInfoSheet: Kingdom?
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var zoomAnchor: CGPoint = .zero
    
    // Scale for coordinate conversion (pixels per degree of lat/lon)
    private let baseScale: CGFloat = 6000.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Parchment background with texture
                ParchmentBackground()
                
                ZStack {
                    // Canvas with boundaries and user location
                    Canvas { context, size in
                        // Apply transform for pan and zoom
                        context.translateBy(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
                        context.scaleBy(x: scale, y: scale)
                        
                        // Draw kingdoms (just boundaries)
                        for kingdom in viewModel.kingdoms {
                            drawKingdom(context: context, kingdom: kingdom)
                        }
                        
                        // Draw user location at center (0, 0)
                        if viewModel.userLocation != nil {
                            drawUserLocation(context: context)
                        }
                    }
                    
                    // Kingdom markers - positioned in screen space with the canvas
                    ForEach(viewModel.kingdoms) { kingdom in
                        if let position = coordinateToPoint(kingdom.territory.center) {
                            KingdomMarker(kingdom: kingdom)
                                .position(
                                    x: geometry.size.width / 2 + position.x * scale + offset.width,
                                    y: geometry.size.height / 2 + position.y * scale + offset.height
                                )
                                .onTapGesture {
                                    kingdomForInfoSheet = kingdom
                                    if !kingdom.hasBoundaryCached {
                                        Task {
                                            await viewModel.loadKingdomBoundary(kingdomId: kingdom.id)
                                        }
                                    }
                                }
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // Calculate new scale
                            let newScale = lastScale * value
                            let clampedScale = min(max(newScale, 0.2), 5.0)
                            
                            // Calculate how much the scale changed from the start of the gesture
                            let scaleRatio = clampedScale / lastScale
                            
                            // Adjust offset proportionally to keep user centered
                            offset = CGSize(
                                width: lastOffset.width * scaleRatio,
                                height: lastOffset.height * scaleRatio
                            )
                            
                            scale = clampedScale
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        }
                )
            }
        }
    }
    
    // MARK: - Drawing Functions
    
    private func drawKingdom(context: GraphicsContext, kingdom: Kingdom) {
        guard kingdom.hasBoundaryCached else { return }
        
        // Convert boundary coordinates to screen points relative to user
        let points = kingdom.territory.boundary.compactMap { coord in
            coordinateToPoint(coord)
        }
        
        guard points.count >= 3 else { return }
        
        // Create path
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        
        // Use relationship colors from backend
        let fillColor: Color
        
        if kingdom.rulerId == viewModel.player.playerId {
            // YOUR KINGDOM - bright gold
            fillColor = Color(red: 1.0, green: 0.85, blue: 0.0)
        } else if kingdom.isEnemy {
            // AT WAR - dangerous red
            fillColor = Color(red: 0.90, green: 0.25, blue: 0.20)
        } else if kingdom.isAllied {
            // ALLIED - friendly green
            fillColor = Color(red: 0.30, green: 0.75, blue: 0.40)
        } else {
            // NEUTRAL - use default kingdom color
            fillColor = Color(
                red: kingdom.color.rgba.red,
                green: kingdom.color.rgba.green,
                blue: kingdom.color.rgba.blue
            )
        }
        
        // Fill territory (semi-transparent so texture shows through)
        context.fill(
            path,
            with: .color(fillColor.opacity(0.3))
        )
        
        // Brutalist style: thick solid black border
        context.stroke(
            path,
            with: .color(.black),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawUserLocation(context: GraphicsContext) {
        // User is at 0,0 (center of coordinate system)
        let point = CGPoint.zero
        
        // Brutalist style: offset shadow
        let shadowCircle = Path(ellipseIn: CGRect(x: point.x - 14 + 3, y: point.y - 14 + 3, width: 28, height: 28))
        context.fill(shadowCircle, with: .color(.black))
        
        // Main circle - blue fill
        let mainCircle = Path(ellipseIn: CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28))
        context.fill(mainCircle, with: .color(.blue))
        
        // Black border
        context.stroke(mainCircle, with: .color(.black), lineWidth: 3)
        
        // Center dot
        let centerDot = Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
        context.fill(centerDot, with: .color(.white))
    }
    
    // MARK: - Coordinate Conversion
    
    private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D) -> CGPoint? {
        guard let userLoc = viewModel.userLocation else { return nil }
        
        // Calculate offset in degrees from user location (user is at 0,0)
        let latDiff = coordinate.latitude - userLoc.latitude
        let lonDiff = coordinate.longitude - userLoc.longitude
        
        // Convert degrees to points on screen
        // At this latitude, 1 degree ≈ 111km, scale it to screen coordinates
        let x = CGFloat(lonDiff) * baseScale
        let y = -CGFloat(latDiff) * baseScale // negative because screen Y is inverted
        
        return CGPoint(x: x, y: y)
    }
}

/// Beautiful aged parchment background WITH TEXTURE
struct ParchmentBackground: View {
    var body: some View {
        ZStack {
            // Base tan color
            Color(red: 0.85, green: 0.77, blue: 0.63)
            
            // STRONG VISIBLE TEXTURE
            GeometryReader { geometry in
                Canvas { context, size in
                    // THICK horizontal lines (paper grain) - VERY VISIBLE
                    var y: CGFloat = 0
                    while y < size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(Color.brown.opacity(0.35)), lineWidth: 1.2)
                        y += 4
                    }
                    
                    // THICK vertical lines (paper fiber) - VERY VISIBLE
                    var x: CGFloat = 0
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(Color.brown.opacity(0.25)), lineWidth: 1.0)
                        x += 6
                    }
                    
                    // BIG DARK dots (paper speckles) - VERY VISIBLE
                    for gridY in stride(from: 0, to: Int(size.height), by: 10) {
                        for gridX in stride(from: 0, to: Int(size.width), by: 10) {
                            let dotSize: CGFloat = 2.5
                            context.fill(
                                Path(ellipseIn: CGRect(x: CGFloat(gridX), y: CGFloat(gridY), width: dotSize, height: dotSize)),
                                with: .color(Color.brown.opacity(0.4))
                            )
                        }
                    }
                }
            }
            
            // Color variation overlay
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.80, blue: 0.66).opacity(0.3),
                    Color(red: 0.80, green: 0.72, blue: 0.58).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Stronger vignette
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
        .ignoresSafeArea()
    }
}

#Preview {
    DrawnMapView(viewModel: MapViewModel(), kingdomForInfoSheet: .constant(nil))
}

