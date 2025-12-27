import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedKingdom: Kingdom?
    @State private var showCurrentKingdom: Bool = true  // Control auto-show of current kingdom
    
    var body: some View {
        ZStack {
            Map(position: $viewModel.cameraPosition) {
                // Add territory overlays
                ForEach(viewModel.kingdoms) { kingdom in
                    // Territory polygon - hand-drawn medieval style
                    MapPolygon(coordinates: kingdom.territory.boundary)
                        .foregroundStyle(
                            Color(
                                red: kingdom.color.rgba.red,
                                green: kingdom.color.rgba.green,
                                blue: kingdom.color.rgba.blue,
                                opacity: kingdom.color.rgba.alpha
                            )
                        )
                        .stroke(
                            Color(
                                red: kingdom.color.strokeRGBA.red,
                                green: kingdom.color.strokeRGBA.green,
                                blue: kingdom.color.strokeRGBA.blue,
                                opacity: kingdom.color.strokeRGBA.alpha
                            ),
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [8, 3]  // Dashed style for hand-drawn feel
                            )
                        )
                    
                    // Kingdom marker (castle icon)
                    Annotation(kingdom.name, coordinate: kingdom.territory.center) {
                        KingdomMarker(kingdom: kingdom)
                            .onTapGesture {
                                selectedKingdom = kingdom
                                showCurrentKingdom = false  // Manually selected, disable auto-show
                            }
                    }
                }
                
                // User location
                UserAnnotation()
            }
            .mapStyle(.imagery(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            
            // Loading overlay - Medieval style
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color(red: 0.5, green: 0.3, blue: 0.1))
                    
                    Text(viewModel.loadingStatus)
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                    
                    Text("Charting the kingdoms...")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
                .padding(24)
                .background(Color(red: 0.95, green: 0.87, blue: 0.70))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 10)
            }
            
            // Error overlay - Medieval style
            if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color(red: 0.7, green: 0.3, blue: 0.1))
                    
                    Text("Map Scroll Damaged")
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                    
                    Text(error)
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        viewModel.refreshKingdoms()
                    }) {
                        Label("Repair Map", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(.headline, design: .serif))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.5, green: 0.3, blue: 0.1))
                            .foregroundColor(Color(red: 0.95, green: 0.87, blue: 0.70))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.3, green: 0.2, blue: 0.1), lineWidth: 2)
                            )
                    }
                }
                .padding(24)
                .background(Color(red: 0.95, green: 0.87, blue: 0.70))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 10)
            }
            
            // Player HUD - top left
            VStack {
                HStack {
                    PlayerHUD(player: viewModel.player, currentKingdom: viewModel.currentKingdomInside)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 60)  // Below system status bar
            .padding(.leading)
            
            // Kingdom info overlay - show selected OR current kingdom you're inside
            if let kingdomId = (selectedKingdom?.id ?? (showCurrentKingdom ? viewModel.currentKingdomInside?.id : nil)),
               let kingdom = viewModel.kingdoms.first(where: { $0.id == kingdomId }) {
                VStack {
                    Spacer()
                    KingdomInfoCard(
                        kingdom: kingdom,
                        player: viewModel.player,
                        isPlayerInside: viewModel.currentKingdomInside?.id == kingdom.id,
                        onCheckIn: {
                            _ = viewModel.checkIn()
                        },
                        onClaim: {
                            _ = viewModel.claimKingdom()
                        },
                        onClose: {
                            selectedKingdom = nil
                            showCurrentKingdom = false
                        }
                    )
                    .padding()
                    .transition(.move(edge: .bottom))
                }
            }
            
            // Legend (only show when we have kingdoms) - moved below player HUD
            if !viewModel.kingdoms.isEmpty && !viewModel.isLoading {
                VStack {
                    HStack {
                        Spacer()
                        LegendView(kingdomCount: viewModel.kingdoms.count, onRefresh: {
                            viewModel.refreshKingdoms()
                        })
                    }
                    Spacer()
                }
                .padding(.top, 140)  // Below player HUD and safe area
                .padding(.trailing)
            }
        }
        .onReceive(locationManager.$currentLocation) { location in
            if let location = location {
                viewModel.updateUserLocation(location)
            }
        }
        .onChange(of: viewModel.currentKingdomInside?.id) { oldValue, newValue in
            // Show card when entering a new kingdom
            if newValue != nil && oldValue != newValue {
                showCurrentKingdom = true
            }
        }
    }
}

// Kingdom marker on map - Medieval war map style
struct KingdomMarker: View {
    let kingdom: Kingdom
    
    var body: some View {
        VStack(spacing: 3) {
            // Medieval castle icon with parchment background
            ZStack {
                // Parchment-style background
                Circle()
                    .fill(Color(red: 0.95, green: 0.87, blue: 0.70))  // Old parchment color
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(
                                    red: kingdom.color.strokeRGBA.red,
                                    green: kingdom.color.strokeRGBA.green,
                                    blue: kingdom.color.strokeRGBA.blue
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 2, y: 2)
                
                Text("🏰")
                    .font(.system(size: 22))
            }
            
            // Town name with parchment scroll style
            Text(kingdom.name)
                .font(.system(size: 11, weight: .bold, design: .serif))  // Serif for medieval feel
                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))  // Dark brown ink
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.95, green: 0.87, blue: 0.70))  // Parchment
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(
                                    Color(
                                        red: kingdom.color.strokeRGBA.red,
                                        green: kingdom.color.strokeRGBA.green,
                                        blue: kingdom.color.strokeRGBA.blue
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 1, y: 2)
        }
    }
}

// Player HUD - shows player status
struct PlayerHUD: View {
    @ObservedObject var player: Player
    let currentKingdom: Kingdom?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(player.isRuler ? "👑" : "⚔️")
                    .font(.title3)
                Text(player.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
            }
            
            HStack(spacing: 12) {
                Label("\(player.gold)g", systemImage: "dollarsign.circle.fill")
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    .font(.system(.subheadline, design: .serif))
                
                if player.isRuler {
                    Label("\(player.fiefsRuled.count)", systemImage: "crown.fill")
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
                        .font(.system(.subheadline, design: .serif))
                }
            }
            
            if let kingdom = currentKingdom {
                Text("📍 \(kingdom.name)")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            } else {
                Text("🗺️ Traveling...")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
            }
        }
        .padding(12)
        .background(Color(red: 0.95, green: 0.87, blue: 0.70))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 2, y: 3)
    }
}

// Check-in button - appears when inside a kingdom
struct CheckInButton: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    let onCheckIn: () -> Void
    let onClaim: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Show different button based on state
            if kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                // Can claim this kingdom!
                MedievalActionButton(
                    title: "👑 Claim \(kingdom.name)",
                    color: Color(red: 0.6, green: 0.4, blue: 0.1),
                    fullWidth: true
                ) {
                    onClaim()
                }
            } else if !player.isCheckedIn() || player.currentKingdom != kingdom.name {
                // Need to check in
                MedievalActionButton(
                    title: "📍 Check In to \(kingdom.name)",
                    color: Color(red: 0.2, green: 0.5, blue: 0.3),
                    fullWidth: true
                ) {
                    onCheckIn()
                }
            } else {
                // Already checked in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.3))
                    Text("Checked in to \(kingdom.name)")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                }
                .padding(12)
                .background(Color(red: 0.95, green: 0.87, blue: 0.70))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.2, green: 0.5, blue: 0.3), lineWidth: 2)
                )
            }
        }
        .padding(.horizontal)
    }
}

// Info card when kingdom is selected - Medieval scroll style with actions
struct KingdomInfoCard: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    let isPlayerInside: Bool
    let onCheckIn: () -> Void
    let onClaim: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with medieval styling
            HStack {
                Text("🏰 \(kingdom.name)")
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))  // Dark brown ink
                Spacer()
                
                if kingdom.isUnclaimed {
                    Text("⚠️ Unclaimed")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.7, green: 0.3, blue: 0.1))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.9, green: 0.8, blue: 0.6))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)
            
            if kingdom.isUnclaimed {
                Text("No ruler - claim it by checking in!")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            } else {
                HStack(spacing: 4) {
                    Text("Ruled by \(kingdom.rulerName)")
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    if kingdom.rulerId == player.playerId {
                        Text("(You)")
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    }
                }
            }
            
            // Kingdom color divider with medieval style
            Rectangle()
                .fill(
                    Color(
                        red: kingdom.color.strokeRGBA.red,
                        green: kingdom.color.strokeRGBA.green,
                        blue: kingdom.color.strokeRGBA.blue
                    )
                )
                .frame(height: 2)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(kingdom.treasuryGold)g", systemImage: "dollarsign.circle.fill")
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    Label("Walls Lv.\(kingdom.wallLevel)", systemImage: "shield.fill")
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Label("Vault Lv.\(kingdom.vaultLevel)", systemImage: "lock.fill")
                        .foregroundColor(Color(red: 0.45, green: 0.3, blue: 0.1))
                    Label("\(kingdom.checkedInPlayers) subjects", systemImage: "person.3.fill")
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.15))
                }
            }
            .font(.system(.subheadline, design: .serif))
            
            // Check-in/Claim section
            if isPlayerInside {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                        .frame(height: 2)
                        .padding(.vertical, 4)
                    
                    if kingdom.rulerId == player.playerId {
                        // You own this kingdom!
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                            Text("You rule this kingdom")
                                .font(.system(.subheadline, design: .serif))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(red: 0.95, green: 0.9, blue: 0.75))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(red: 0.6, green: 0.4, blue: 0.1), lineWidth: 2)
                        )
                    } else if kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                        // Can claim!
                        MedievalActionButton(
                            title: "👑 Claim This Kingdom",
                            color: Color(red: 0.6, green: 0.4, blue: 0.1),
                            fullWidth: true
                        ) {
                            onClaim()
                        }
                    } else if !player.isCheckedIn() || player.currentKingdom != kingdom.name {
                        // Need to enter the kingdom
                        MedievalActionButton(
                            title: "⚔️ Enter Kingdom",
                            color: Color(red: 0.2, green: 0.5, blue: 0.3),
                            fullWidth: true
                        ) {
                            onCheckIn()
                        }
                    } else {
                        // Already present but someone else rules it
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                            Text("You are here")
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(red: 0.9, green: 0.85, blue: 0.7))
                        .cornerRadius(6)
                    }
                }
            } else {
                // Not inside this kingdom
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                        .frame(height: 2)
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                        Text("You must travel here first")
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                    }
                    .padding(8)
                }
            }
            
            // Action buttons - Medieval war council style (only if kingdom has ruler)
            if !kingdom.isUnclaimed && kingdom.rulerId != player.playerId {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        MedievalActionButton(
                            title: "⚔️ Declare War",
                            color: Color(red: 0.7, green: 0.15, blue: 0.1)
                        ) {
                            // TODO: Implement declare war
                            print("Declare war on \(kingdom.name)")
                        }
                        
                        MedievalActionButton(
                            title: "🤝 Form Alliance",
                            color: Color(red: 0.2, green: 0.5, blue: 0.3)
                        ) {
                            // TODO: Implement form alliance
                            print("Form alliance with \(kingdom.name)")
                        }
                    }
                    
                    MedievalActionButton(
                        title: "🗡️ Stage Coup",
                        color: Color(red: 0.3, green: 0.15, blue: 0.4),
                        fullWidth: true
                    ) {
                        // TODO: Implement stage coup
                        print("Stage coup in \(kingdom.name)")
                    }
                }
                .padding(.top, 8)
            }
            
            Button(action: onClose) {
                HStack {
                    Spacer()
                    Text("✕ Close")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            Color(red: 0.95, green: 0.87, blue: 0.70)  // Parchment background
                .overlay(
                    // Add subtle texture
                    Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.1)
                )
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(
                        red: kingdom.color.strokeRGBA.red,
                        green: kingdom.color.strokeRGBA.green,
                        blue: kingdom.color.strokeRGBA.blue
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 2, y: 4)
    }
}

// Medieval-styled action button
struct MedievalActionButton: View {
    let title: String
    let color: Color
    var fullWidth: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.95, green: 0.87, blue: 0.70))
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 1, y: 2)
        }
    }
}

// Legend showing kingdom info - Medieval scroll style
struct LegendView: View {
    let kingdomCount: Int
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⚔️ \(kingdomCount) Kingdoms")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
                }
            }
            
            Text("Ancient territories")
                .font(.system(.caption, design: .serif))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
        }
        .padding(12)
        .background(Color(red: 0.95, green: 0.87, blue: 0.70))  // Parchment
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 2, y: 3)
    }
}

#Preview {
    MapView()
}
