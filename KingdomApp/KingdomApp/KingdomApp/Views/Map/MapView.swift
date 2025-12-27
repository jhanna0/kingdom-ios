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
                MedievalLoadingView(status: viewModel.loadingStatus)
            }
            
            // Error overlay - Medieval style
            if let error = viewModel.errorMessage {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.largeTitle)
                        .foregroundColor(KingdomTheme.Colors.error)
                    
                    Text("Map Scroll Damaged")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(error)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        viewModel.refreshKingdoms()
                    }) {
                        Label("Repair Map", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonPrimary))
                }
                .padding(KingdomTheme.Spacing.xxLarge)
                .parchmentCard(cornerRadius: KingdomTheme.CornerRadius.xxLarge)
                .shadow(color: KingdomTheme.Shadows.overlay.color, radius: KingdomTheme.Shadows.overlay.radius)
            }
            
            // Player HUD - top left
            VStack {
                HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
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
                                    .font(KingdomTheme.Typography.subheadline())
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, KingdomTheme.Spacing.medium)
                            .padding(.vertical, 8)
                            .background(KingdomTheme.Colors.buttonPrimary)
                            .cornerRadius(KingdomTheme.CornerRadius.large)
                            .shadow(
                                color: KingdomTheme.Shadows.card.color,
                                radius: KingdomTheme.Shadows.card.radius,
                                x: KingdomTheme.Shadows.card.x,
                                y: KingdomTheme.Shadows.card.y
                            )
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
