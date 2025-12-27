import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedKingdom: Kingdom?
    @State private var showCurrentKingdom: Bool = true
    @State private var showMyKingdoms = false
    
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
                HStack(alignment: .top, spacing: 12) {
                    PlayerHUD(player: viewModel.player, currentKingdom: viewModel.currentKingdomInside)
                    
                    Spacer()
                    
                    // My Kingdoms button
                    if viewModel.player.isRuler {
                        Button(action: {
                            showMyKingdoms = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14))
                                Text("\(viewModel.player.fiefsRuled.count)")
                                    .font(.system(.subheadline, design: .serif))
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.5, green: 0.3, blue: 0.1))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 2, y: 3)
                        }
                    }
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal)
            
            // Bottom sheet for kingdom details
            if let kingdomId = (selectedKingdom?.id ?? (showCurrentKingdom ? viewModel.currentKingdomInside?.id : nil)),
               let kingdom = viewModel.kingdoms.first(where: { $0.id == kingdomId }) {
                VStack {
                    Spacer()
                    KingdomInfoCard(
                        kingdom: kingdom,
                        player: viewModel.player,
                        viewModel: viewModel,
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
        .sheet(isPresented: $showMyKingdoms) {
            MyKingdomsSheet(
                player: viewModel.player,
                viewModel: viewModel,
                onDismiss: {
                    showMyKingdoms = false
                }
            )
        }
    }
}

#Preview {
    MapView()
}

