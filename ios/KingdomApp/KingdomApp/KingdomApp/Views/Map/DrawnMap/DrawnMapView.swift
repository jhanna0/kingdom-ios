import SwiftUI
import CoreLocation

/// Custom drawn map view - no Apple Maps, just illustrated kingdoms
struct DrawnMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var kingdomForInfoSheet: Kingdom?
    
    @State private var transform = MapTransformState()
    
    /// Pixels per degree of lat/lon for coordinate conversion
    private let baseScale: CGFloat = 6000.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ParchmentBackground()
                
                ZStack {
                    mapCanvas
                    kingdomMarkers(in: geometry)
                }
                .panZoomable(transform: $transform)
            }
        }
    }
    
    // MARK: - Map Content
    
    private var mapCanvas: some View {
        Canvas { context, size in
            // Apply transform for pan and zoom
            context.translateBy(
                x: size.width / 2 + transform.offset.width,
                y: size.height / 2 + transform.offset.height
            )
            context.scaleBy(x: transform.scale, y: transform.scale)
            
            // Draw kingdom boundaries
            for kingdom in viewModel.kingdoms {
                drawKingdom(context: context, kingdom: kingdom)
            }
            
            // Draw user location at center (0, 0)
            if viewModel.userLocation != nil {
                drawUserLocation(context: context)
            }
        }
    }
    
    private func kingdomMarkers(in geometry: GeometryProxy) -> some View {
        ForEach(viewModel.kingdoms) { kingdom in
            if let position = coordinateToPoint(kingdom.territory.center) {
                KingdomMarker(kingdom: kingdom)
                    .position(
                        x: geometry.size.width / 2 + position.x * transform.scale + transform.offset.width,
                        y: geometry.size.height / 2 + position.y * transform.scale + transform.offset.height
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
    
    // MARK: - Drawing Functions
    
    private func drawKingdom(context: GraphicsContext, kingdom: Kingdom) {
        guard kingdom.hasBoundaryCached else { return }
        
        let points = kingdom.territory.boundary.compactMap { coordinateToPoint($0) }
        guard points.count >= 3 else { return }
        
        // Build path from boundary points
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        
        let fillColor = kingdomFillColor(for: kingdom)
        
        // Fill territory (semi-transparent so texture shows through)
        context.fill(path, with: .color(fillColor.opacity(0.3)))
        
        // Brutalist style: thick solid black border
        context.stroke(
            path,
            with: .color(.black),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func kingdomFillColor(for kingdom: Kingdom) -> Color {
        if kingdom.rulerId == viewModel.player.playerId {
            // YOUR KINGDOM - bright gold
            return Color(red: 1.0, green: 0.85, blue: 0.0)
        } else if kingdom.isEnemy {
            // AT WAR - dangerous red
            return Color(red: 0.90, green: 0.25, blue: 0.20)
        } else if kingdom.isAllied {
            // ALLIED - friendly green
            return Color(red: 0.30, green: 0.75, blue: 0.40)
        } else {
            // NEUTRAL - use default kingdom color
            return Color(
                red: kingdom.color.rgba.red,
                green: kingdom.color.rgba.green,
                blue: kingdom.color.rgba.blue
            )
        }
    }
    
    private func drawUserLocation(context: GraphicsContext) {
        let point = CGPoint.zero  // User is always at center
        let radius: CGFloat = 14
        let shadowOffset: CGFloat = 3
        
        // Brutalist shadow
        let shadowRect = CGRect(
            x: point.x - radius + shadowOffset,
            y: point.y - radius + shadowOffset,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(.black))
        
        // Main circle
        let mainRect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let mainCircle = Path(ellipseIn: mainRect)
        context.fill(mainCircle, with: .color(.blue))
        context.stroke(mainCircle, with: .color(.black), lineWidth: 3)
        
        // Center dot
        let dotRadius: CGFloat = 5
        let dotRect = CGRect(
            x: point.x - dotRadius,
            y: point.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )
        context.fill(Path(ellipseIn: dotRect), with: .color(.white))
    }
    
    // MARK: - Coordinate Conversion
    
    private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D) -> CGPoint? {
        guard let userLoc = viewModel.userLocation else { return nil }
        
        let latDiff = coordinate.latitude - userLoc.latitude
        let lonDiff = coordinate.longitude - userLoc.longitude
        
        // Convert degrees to screen points (user is at 0,0)
        let x = CGFloat(lonDiff) * baseScale
        let y = -CGFloat(latDiff) * baseScale  // Negative because screen Y is inverted
        
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    DrawnMapView(viewModel: MapViewModel(), kingdomForInfoSheet: .constant(nil))
}

