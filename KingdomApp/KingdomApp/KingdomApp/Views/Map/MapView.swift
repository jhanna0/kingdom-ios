import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedKingdom: Kingdom?
    @State private var showCurrentKingdom: Bool = false
    @State private var showMyKingdoms = false
    @State private var showContracts = false
    @State private var showCharacterSheet = false
    @State private var showActivityFeed = false
    @State private var hasShownInitialKingdom = false
    @State private var mapOpacity: Double = 0.0
    
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
                                opacity: kingdom.color.rgba.alpha * mapOpacity
                            )
                        )
                        .stroke(
                            Color(
                                red: kingdom.color.strokeRGBA.red,
                                green: kingdom.color.strokeRGBA.green,
                                blue: kingdom.color.strokeRGBA.blue,
                                opacity: kingdom.color.strokeRGBA.alpha * mapOpacity
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
                            .opacity(mapOpacity)
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
                MapCompass()
                MapScaleView()
            }
            
            // Loading overlay - Medieval style
            if viewModel.isLoading {
                MedievalLoadingView(status: viewModel.loadingStatus)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.isLoading)
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
            
            // Clean top HUD
            VStack {
                VStack(spacing: 8) {
                    // Top row - player and location
                    HStack(spacing: 10) {
                        // Player badge
                        HStack(spacing: 6) {
                            Text(viewModel.player.isRuler ? "👑" : "⚔️")
                                .font(.system(size: 16))
                            Text(viewModel.player.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Spacer()
                        
                        // Location badge
                        HStack(spacing: 4) {
                            if let kingdom = viewModel.currentKingdomInside {
                                Text("📍")
                                    .font(.system(size: 12))
                                Text(kingdom.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .lineLimit(1)
                            } else {
                                Text("🗺️")
                                    .font(.system(size: 12))
                                Text("Traveling")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                            }
                        }
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(KingdomTheme.Colors.inkLight.opacity(0.2))
                        .frame(height: 1)
                    
                    // Bottom row - actions
                    HStack(spacing: 12) {
                        // Character button (shows level + gold)
                        Button(action: {
                            showCharacterSheet = true
                        }) {
                            HStack(spacing: 6) {
                                // Level badge
                                ZStack {
                                    Circle()
                                        .fill(KingdomTheme.Colors.gold)
                                        .frame(width: 24, height: 24)
                                    Text("\(viewModel.player.level)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                // Gold
                                HStack(spacing: 2) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                        .font(.system(size: 14))
                                    Text("\(viewModel.player.gold)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // My Kingdoms (always show if player has kingdoms)
                        if viewModel.player.isRuler || !viewModel.player.fiefsRuled.isEmpty {
                            Button(action: {
                                showMyKingdoms = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 14))
                                    Text("\(viewModel.player.fiefsRuled.count)")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(KingdomTheme.Colors.buttonPrimary)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Contracts
                        Button(action: {
                            showContracts = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 14))
                                Text("Contracts")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(KingdomTheme.Colors.buttonWarning)
                            .cornerRadius(8)
                        }
                        
                        // World Activity Feed
                        ActivityBadge(worldSimulator: viewModel.worldSimulator) {
                            showActivityFeed = true
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KingdomTheme.Colors.parchment)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 12)
                
                Spacer()
            }
            .padding(.top, 60)
            
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
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedKingdom = nil
                                showCurrentKingdom = false
                            }
                        }
                    )
                    .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.5), value: showCurrentKingdom)
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
                // Add smooth delay for initial presentation
                if !hasShownInitialKingdom {
                    hasShownInitialKingdom = true
                    // Wait for map to fade in, then show sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showCurrentKingdom = true
                        }
                    }
                } else {
                    // Subsequent kingdom changes show with animation
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showCurrentKingdom = true
                    }
                }
            }
        }
        .onChange(of: viewModel.isLoading) { oldValue, newValue in
            // When loading completes, fade in the map smoothly
            if !newValue && oldValue && viewModel.kingdoms.count > 0 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    mapOpacity = 1.0
                }
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
        .sheet(isPresented: $showContracts) {
            ContractsListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCharacterSheet) {
            CharacterSheetView(player: viewModel.player)
        }
        .sheet(isPresented: $showActivityFeed) {
            WorldActivityFeed(
                worldSimulator: viewModel.worldSimulator,
                isPresented: $showActivityFeed
            )
        }
    }
}

#Preview {
    MapView()
}
