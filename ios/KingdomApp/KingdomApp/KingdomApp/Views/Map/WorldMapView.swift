import SwiftUI
import CoreLocation

/// World map showing all kingdoms the player has visited
struct WorldMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var worldMapData: WorldMapResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var transform: MapTransformState = {
        var state = MapTransformState()
        state.scale = 0.15
        state.lastScale = 0.15
        return state
    }()
    
    private let baseScale: CGFloat = 6000.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Parchment background
                KingdomTheme.Colors.parchment.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let data = worldMapData {
                    if data.kingdoms.isEmpty {
                        emptyStateView
                    } else {
                        GeometryReader { geometry in
                            ZStack {
                                ParchmentBackground(isWarMode: false)
                                
                                ZStack {
                                    mapCanvas(data: data, geometry: geometry)
                                    kingdomMarkers(data: data, geometry: geometry)
                                }
                                .panZoomable(transform: $transform)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My World Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let data = worldMapData, !data.kingdoms.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(data.total_kingdoms_visited)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                                .offset(x: 2, y: 2)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.parchmentLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                    )
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
        }
        .task {
            await loadWorldMap()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(KingdomTheme.Colors.buttonPrimary)
            
            Text("Unrolling your map scroll...")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .italic()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 72, height: 72)
                    .offset(x: 3, y: 3)
                
                Circle()
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 3)
                    )
                
                Image(systemName: "map.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Text("Map Scroll Damaged")
                .font(KingdomTheme.Typography.title3())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(error)
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task { await loadWorldMap() }
            }
            .buttonStyle(BrutalistButtonStyle(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 88, height: 88)
                    .offset(x: 4, y: 4)
                
                Circle()
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 3)
                    )
                
                Image(systemName: "map.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Text("Your World Awaits")
                .font(KingdomTheme.Typography.title2())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Visit kingdoms to add them to your world map. Each kingdom you enter will appear here.")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Map Canvas
    
    private func mapCanvas(data: WorldMapResponse, geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            guard let refPoint = data.reference_point else { return }
            
            context.translateBy(
                x: size.width / 2 + transform.offset.width,
                y: size.height / 2 + transform.offset.height
            )
            context.scaleBy(x: transform.scale, y: transform.scale)
            
            for kingdom in data.kingdoms {
                drawKingdom(context: context, kingdom: kingdom, refPoint: refPoint)
            }
        }
    }
    
    private func drawKingdom(context: GraphicsContext, kingdom: WorldMapKingdom, refPoint: WorldMapReferencePoint) {
        let points = kingdom.boundary.compactMap { coord -> CGPoint? in
            guard coord.count >= 2 else { return nil }
            return coordinateToPoint(lat: coord[0], lon: coord[1], refPoint: refPoint)
        }
        
        guard points.count >= 3 else { return }
        
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        
        let fillColor = kingdomFillColor(for: kingdom)
        
        context.fill(path, with: .color(fillColor.opacity(0.55)))
        context.stroke(
            path,
            with: .color(.black),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func kingdomFillColor(for kingdom: WorldMapKingdom) -> Color {
        if kingdom.is_hometown {
            return KingdomTheme.Colors.territoryPlayer
        } else if kingdom.is_ruled {
            return KingdomTheme.Colors.territoryPlayer
        } else {
            return KingdomTheme.Colors.territoryColor(
                kingdomId: kingdom.id,
                isPlayer: false,
                isEnemy: false,
                isAllied: false,
                isAtWar: false,
                isPartOfEmpire: false
            )
        }
    }
    
    // MARK: - Kingdom Markers
    
    private func kingdomMarkers(data: WorldMapResponse, geometry: GeometryProxy) -> some View {
        ForEach(data.kingdoms) { kingdom in
            if let refPoint = data.reference_point {
                let position = coordinateToPoint(lat: kingdom.center_lat, lon: kingdom.center_lon, refPoint: refPoint)
                WorldMapMarker(kingdom: kingdom)
                    .position(
                        x: geometry.size.width / 2 + position.x * transform.scale + transform.offset.width,
                        y: geometry.size.height / 2 + position.y * transform.scale + transform.offset.height
                    )
            }
        }
    }
    
    // MARK: - Coordinate Conversion
    
    private func coordinateToPoint(lat: Double, lon: Double, refPoint: WorldMapReferencePoint) -> CGPoint {
        let latDiff = lat - refPoint.lat
        let lonDiff = lon - refPoint.lon
        
        let x = CGFloat(lonDiff) * baseScale
        let y = -CGFloat(latDiff) * baseScale
        
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Data Loading
    
    private func loadWorldMap() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await PlayerAPI().getWorldMap()
            await MainActor.run {
                worldMapData = data
                isLoading = false
                
                if !data.kingdoms.isEmpty {
                    autoFitToKingdoms(data)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load world map"
                isLoading = false
            }
        }
    }
    
    private func autoFitToKingdoms(_ data: WorldMapResponse) {
        guard let refPoint = data.reference_point, !data.kingdoms.isEmpty else { return }
        
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity
        
        for kingdom in data.kingdoms {
            let point = coordinateToPoint(lat: kingdom.center_lat, lon: kingdom.center_lon, refPoint: refPoint)
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        let width = maxX - minX
        let height = maxY - minY
        let maxDimension = max(width, height)
        
        if maxDimension > 0 {
            let targetScale = min(0.5, 300 / maxDimension)
            transform.scale = max(0.05, targetScale)
            transform.lastScale = transform.scale
        }
    }
}

// MARK: - World Map Marker (matches KingdomMarker style)

struct WorldMapMarker: View {
    let kingdom: WorldMapKingdom
    
    // Fixed scale for world map (smaller than main map)
    private let markerScale: CGFloat = 0.65
    
    // Scaled dimensions (matching KingdomMarker)
    private var mainSize: CGFloat { 56 * markerScale }
    private var cornerRadius: CGFloat { 14 * markerScale }
    private var shadowOffset: CGFloat { 3 * markerScale }
    private var iconSize: CGFloat { 28 * markerScale }
    private var borderWidth: CGFloat { max(2, 3 * markerScale) }
    private var nameFontSize: CGFloat { max(10, 12 * markerScale) }
    private var namePaddingH: CGFloat { 10 * markerScale }
    private var namePaddingV: CGFloat { 5 * markerScale }
    
    // Status badge for home/current
    private var statusBadgeSize: CGFloat { 20 * markerScale }
    private var statusIconSize: CGFloat { 10 * markerScale }
    private var statusBadgeOffset: CGFloat { 22 * markerScale }
    
    private var markerBackgroundColor: Color {
        if kingdom.is_hometown || kingdom.is_ruled {
            return KingdomTheme.Colors.territoryPlayer
        } else {
            return KingdomTheme.Colors.territoryColor(
                kingdomId: kingdom.id,
                isPlayer: false,
                isEnemy: false,
                isAllied: false,
                isAtWar: false,
                isPartOfEmpire: false
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 6 * markerScale) {
            // Main castle marker - brutalist style (matching KingdomMarker)
            ZStack {
                // Offset shadow
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black)
                    .frame(width: mainSize, height: mainSize)
                    .offset(x: shadowOffset, y: shadowOffset)
                
                // Main marker - colored background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(markerBackgroundColor)
                    .frame(width: mainSize, height: mainSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.black, lineWidth: borderWidth)
                    )
                
                // Kingdom icon - white on colored background
                Image(systemName: "building.columns.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.white)
                
                // Status badge: Home or Current location
                if kingdom.is_hometown {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .offset(x: 1 * markerScale, y: 1 * markerScale)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.imperialGold)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                        
                        Image(systemName: "house.fill")
                            .font(.system(size: statusIconSize, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -statusBadgeOffset, y: -statusBadgeOffset)
                } else if kingdom.is_current {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .offset(x: 1 * markerScale, y: 1 * markerScale)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.royalBlue)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                        
                        Image(systemName: "location.fill")
                            .font(.system(size: statusIconSize, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -statusBadgeOffset, y: -statusBadgeOffset)
                } else if kingdom.is_ruled {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .offset(x: 1 * markerScale, y: 1 * markerScale)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.imperialGold)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: statusIconSize, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -statusBadgeOffset, y: -statusBadgeOffset)
                }
            }
            
            // Kingdom name banner - brutalist style
            Text(kingdom.name)
                .font(.system(size: nameFontSize, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.horizontal, namePaddingH)
                .padding(.vertical, namePaddingV)
                .background(
                    ZStack {
                        // Banner shadow
                        RoundedRectangle(cornerRadius: 8 * markerScale)
                            .fill(Color.black)
                            .offset(x: 2 * markerScale, y: 2 * markerScale)
                        
                        // Banner background
                        RoundedRectangle(cornerRadius: 8 * markerScale)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8 * markerScale)
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                    }
                )
        }
    }
}

#Preview {
    WorldMapView()
}
