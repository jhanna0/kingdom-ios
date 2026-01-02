import SwiftUI
import CoreLocation

/// Custom drawn map view - no Apple Maps, just illustrated kingdoms
struct DrawnMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var kingdomForInfoSheet: Kingdom?
    
    @State private var transform: MapTransformState = {
        var state = MapTransformState()
        state.scale = 0.3  // Start zoomed out for better overview
        state.lastScale = 0.3
        return state
    }()
    
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
                
                // Error overlay
                if let error = viewModel.errorMessage {
                    BlockingErrorView(
                        title: "Map Scroll Damaged",
                        message: error,
                        primaryAction: .init(
                            label: "Repair Map",
                            icon: "arrow.triangle.2.circlepath",
                            color: KingdomTheme.Colors.buttonPrimary,
                            action: { viewModel.refreshKingdoms() }
                        ),
                        secondaryAction: nil
                    )
                }
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
        
        // Fill territory (higher opacity for better visibility)
        context.fill(path, with: .color(fillColor.opacity(0.55)))
        
        // Brutalist style: thick solid black border
        context.stroke(
            path,
            with: .color(.black),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func kingdomFillColor(for kingdom: Kingdom) -> Color {
        if kingdom.rulerId == viewModel.player.playerId {
            // YOUR KINGDOM - warm amber/bronze (like illuminated manuscripts)
            return Color(red: 0.85, green: 0.65, blue: 0.30)
        } else if kingdom.isEnemy {
            // AT WAR - deep muted red (medieval vermillion)
            return Color(red: 0.75, green: 0.30, blue: 0.25)
        } else if kingdom.isAllied {
            // ALLIED - map blue-green (like cartographer's seas)
            return Color(red: 0.35, green: 0.60, blue: 0.65)
        } else {
            // NEUTRAL - Nice varied map colors based on kingdom ID
            // Use hash of kingdom ID to get consistent but varied colors
            let hash = abs(kingdom.id.hashValue)
            let colorIndex = hash % 12
            
            // Array of beautiful map colors - blues, greens, earth tones
            switch colorIndex {
            case 0:
                return Color(red: 0.40, green: 0.55, blue: 0.75) // Ocean blue
            case 1:
                return Color(red: 0.45, green: 0.68, blue: 0.50) // Forest green
            case 2:
                return Color(red: 0.70, green: 0.52, blue: 0.42) // Terracotta
            case 3:
                return Color(red: 0.38, green: 0.65, blue: 0.70) // Teal
            case 4:
                return Color(red: 0.55, green: 0.60, blue: 0.45) // Sage green
            case 5:
                return Color(red: 0.50, green: 0.45, blue: 0.65) // Dusty purple
            case 6:
                return Color(red: 0.65, green: 0.58, blue: 0.45) // Sandy brown
            case 7:
                return Color(red: 0.42, green: 0.58, blue: 0.60) // Steel blue
            case 8:
                return Color(red: 0.58, green: 0.65, blue: 0.42) // Olive green
            case 9:
                return Color(red: 0.68, green: 0.50, blue: 0.52) // Dusty rose
            case 10:
                return Color(red: 0.45, green: 0.52, blue: 0.58) // Slate blue
            case 11:
                return Color(red: 0.60, green: 0.55, blue: 0.48) // Warm taupe
            default:
                return Color(red: 0.50, green: 0.55, blue: 0.60) // Default grey-blue
            }
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

