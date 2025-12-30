import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var viewModel: MapViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var kingdomForInfoSheet: Kingdom?
    @State private var showMyKingdoms = false
    @State private var showActions = false
    @State private var showCharacterSheet = false
    @State private var showProperties = false
    @State private var kingdomToShow: Kingdom?
    @State private var hasShownInitialKingdom = false
    @State private var mapOpacity: Double = 0.0
    @State private var showAPIDebug = false
    @State private var showActivity = false
    @State private var notificationBadgeCount = 0
    @State private var showTravelFeeToast = false
    @State private var travelFeeMessage = ""
    @State private var travelFeeIcon = ""
    
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
                                kingdomForInfoSheet = kingdom
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
            
            // Travel fee toast notification (at the very top, above sheets)
            if showTravelFeeToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: travelFeeIcon)
                            .foregroundColor(.white)
                        Text(travelFeeMessage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 8)
                    )
                    .padding(.top, 70)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showTravelFeeToast)
                .zIndex(999)
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
                        
                        // API Status Indicator
                        Button {
                            showAPIDebug = true
                        } label: {
                            Circle()
                                .fill(viewModel.apiService.isConnected ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(KingdomTheme.Colors.inkLight.opacity(0.2))
                        .frame(height: 1)
                    
                    // Bottom row - actions
                    HStack(spacing: 8) {
                        // Character button (shows level + gold)
                        Button(action: {
                            showCharacterSheet = true
                        }) {
                            HStack(spacing: 4) {
                                // Level badge
                                ZStack {
                                    Circle()
                                        .fill(KingdomTheme.Colors.gold)
                                        .frame(width: 22, height: 22)
                                    Text("\(viewModel.player.level)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                // Gold
                                Text("\(viewModel.player.gold)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                        
                        Spacer()
                        
                        // My Kingdoms (icon only, always show if player has kingdoms)
                        if viewModel.player.isRuler || !viewModel.player.fiefsRuled.isEmpty {
                            Button(action: {
                                showMyKingdoms = true
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(KingdomTheme.Colors.buttonPrimary)
                                        .cornerRadius(6)
                                    
                                    if viewModel.player.fiefsRuled.count > 0 {
                                        Text("\(viewModel.player.fiefsRuled.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(3)
                                            .background(Circle().fill(Color.red))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                        
                        // Actions (icon only)
                        Button(action: {
                            showActions = true
                        }) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(KingdomTheme.Colors.buttonSuccess)
                                .cornerRadius(6)
                        }
                        
                        // Properties (icon only)
                        Button(action: {
                            showProperties = true
                        }) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(KingdomTheme.Colors.buttonSuccess)
                                .cornerRadius(6)
                        }
                        
                        // Activity (icon only)
                        Button(action: {
                            showActivity = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(KingdomTheme.Colors.buttonSuccess)
                                    .cornerRadius(6)
                                
                                if notificationBadgeCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Text("\(notificationBadgeCount)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 6, y: -6)
                                }
                            }
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
        }
        .onReceive(locationManager.$currentLocation) { location in
            if let location = location {
                viewModel.updateUserLocation(location)
            }
        }
        .onChange(of: viewModel.latestTravelEvent) { oldValue, newValue in
            // Show travel notification based on what the BACKEND tells us
            if let event = newValue, event.entered_kingdom {
                // Backend told us we entered a kingdom - display appropriate message
                if let reason = event.free_travel_reason {
                    // Free travel
                    switch reason {
                    case "ruler":
                        travelFeeMessage = "Free Travel - You rule \(event.kingdom_name)"
                        travelFeeIcon = "crown.fill"
                    case "property_owner":
                        travelFeeMessage = "Free Travel - You own property in \(event.kingdom_name)"
                        travelFeeIcon = "house.fill"
                    case "allied":
                        travelFeeMessage = "Free Travel - Allied kingdom"
                        travelFeeIcon = "handshake.fill"
                    default:
                        travelFeeMessage = "Free Travel to \(event.kingdom_name)"
                        travelFeeIcon = "checkmark.circle.fill"
                    }
                    showTravelFeeToast = true
                } else if event.travel_fee_paid > 0 {
                    // Paid travel fee
                    travelFeeMessage = "Paid \(event.travel_fee_paid)g to enter \(event.kingdom_name)"
                    travelFeeIcon = "dollarsign.circle.fill"
                    showTravelFeeToast = true
                }
                
                // Hide toast after 3 seconds
                if showTravelFeeToast {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showTravelFeeToast = false
                    }
                }
                
                // Don't auto-show info sheet when entering a kingdom
                // Let user see the travel fee toast instead
                // They can tap the kingdom marker to open the sheet
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
        .sheet(isPresented: $showActions) {
            NavigationStack {
                ActionsView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showProperties) {
            MyPropertiesView(player: viewModel.player, currentKingdom: viewModel.currentKingdomInside)
        }
        .sheet(isPresented: $showCharacterSheet) {
            NavigationStack {
                CharacterSheetView(player: viewModel.player)
            }
        }
        .sheet(item: $kingdomForInfoSheet) { kingdom in
            KingdomInfoSheetView(
                kingdom: kingdom,
                player: viewModel.player,
                viewModel: viewModel,
                isPlayerInside: viewModel.currentKingdomInside?.id == kingdom.id,
                onViewKingdom: {
                    kingdomForInfoSheet = nil
                    kingdomToShow = kingdom
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $kingdomToShow) { kingdom in
            NavigationStack {
                KingdomDetailView(
                    kingdomId: kingdom.id,
                    player: viewModel.player,
                    viewModel: viewModel
                )
                .navigationTitle(kingdom.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            kingdomToShow = nil
                        }
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.semibold)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAPIDebug) {
            APIDebugView()
        }
        .sheet(isPresented: $showActivity) {
            ActivityView()
        }
        .task {
            await loadNotificationBadge()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await loadNotificationBadge()
            }
        }
    }
    
    private func loadNotificationBadge() async {
        do {
            let summary = try await viewModel.apiService.notifications.getSummary()
            await MainActor.run {
                notificationBadgeCount = summary.unreadNotifications
            }
        } catch {
            print("❌ Failed to load notification badge: \(error)")
        }
    }
}

#Preview {
    MapView(viewModel: MapViewModel())
}
