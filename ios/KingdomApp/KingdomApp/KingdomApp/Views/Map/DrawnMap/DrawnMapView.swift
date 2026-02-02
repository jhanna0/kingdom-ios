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
    
    @State private var visibleOrder: [String] = []  // Order markers were added
    @State private var lastZoom: CGFloat = 0.3
    
    /// Pixels per degree of lat/lon for coordinate conversion
    private let baseScale: CGFloat = 6000.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ParchmentBackground(isWarMode: viewModel.isInWarState)
                
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
        let visibleIds = getVisibleKingdomIds(in: geometry)
        
        return ForEach(viewModel.kingdoms) { kingdom in
            if let position = coordinateToPoint(kingdom.territory.center) {
                let isVisible = visibleIds.contains(kingdom.id)
                KingdomMarkerWithActivity(
                    kingdom: kingdom,
                    homeKingdomId: viewModel.player.hometownKingdomId,
                    playerId: viewModel.player.playerId,
                    markerScale: KingdomMarker.calculateScale(for: kingdom.territory.radiusMeters)
                )
                    .opacity(isVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.25), value: isVisible)
                    .allowsHitTesting(isVisible)
                    .position(
                        x: geometry.size.width / 2 + position.x * transform.scale + transform.offset.width,
                        y: geometry.size.height / 2 + position.y * transform.scale + transform.offset.height
                    )
                    .onTapGesture {
                        guard isVisible, !transform.isGestureActive else { return }
                        
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
    
    /// Get IDs of kingdoms that should be visible (not overlapping on screen)
    private func getVisibleKingdomIds(in geometry: GeometryProxy) -> Set<String> {
        let zoomingOut = transform.scale < lastZoom - 0.01
        
        // Helper to get screen position
        func screenPos(for id: String) -> CGPoint? {
            guard let kingdom = viewModel.kingdoms.first(where: { $0.id == id }),
                  let mapPos = coordinateToPoint(kingdom.territory.center) else { return nil }
            return CGPoint(
                x: geometry.size.width / 2 + mapPos.x * transform.scale + transform.offset.width,
                y: geometry.size.height / 2 + mapPos.y * transform.scale + transform.offset.height
            )
        }
        
        // Check if position overlaps any in list
        func overlaps(_ pos: CGPoint, _ positions: [CGPoint]) -> Bool {
            positions.contains { hypot(pos.x - $0.x, pos.y - $0.y) < 60 }
        }
        
        var newOrder = visibleOrder
        
        if zoomingOut {
            // ZOOMING OUT: Pop from end until no overlaps
            while newOrder.count > 1 {
                // Check if last item overlaps any earlier item
                guard let lastPos = screenPos(for: newOrder.last!) else {
                    newOrder.removeLast()
                    continue
                }
                
                let earlierPositions = newOrder.dropLast().compactMap { screenPos(for: $0) }
                if overlaps(lastPos, earlierPositions) {
                    newOrder.removeLast()  // Pop it
                } else {
                    break  // No overlap, stop popping
                }
            }
        } else {
            // ZOOMING IN or STABLE: Keep existing, try to add new ones
            // Sorted: largest first, home always first
            let sorted = viewModel.kingdoms.sorted { k1, k2 in
                let isHome1 = k1.id == viewModel.player.hometownKingdomId
                let isHome2 = k2.id == viewModel.player.hometownKingdomId
                if isHome1 != isHome2 { return isHome1 }
                return k1.territory.radiusMeters > k2.territory.radiusMeters
            }
            
            for kingdom in sorted {
                guard !newOrder.contains(kingdom.id) else { continue }
                guard let pos = screenPos(for: kingdom.id) else { continue }
                
                let existingPositions = newOrder.compactMap { screenPos(for: $0) }
                if !overlaps(pos, existingPositions) {
                    newOrder.append(kingdom.id)  // Add to end
                }
            }
        }
        
        // Update state
        DispatchQueue.main.async {
            self.visibleOrder = newOrder
            self.lastZoom = self.transform.scale
        }
        
        return Set(newOrder)
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
        let isHomeKingdom = kingdom.id == viewModel.player.hometownKingdomId
        return KingdomTheme.Colors.territoryColor(
            kingdomId: kingdom.id,
            isPlayer: isHomeKingdom,
            isEnemy: kingdom.isEnemy,
            isAllied: kingdom.isAllied,
            isAtWar: isHomeKingdom && kingdom.isAtWar,
            isPartOfEmpire: kingdom.isEmpire
        )
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

