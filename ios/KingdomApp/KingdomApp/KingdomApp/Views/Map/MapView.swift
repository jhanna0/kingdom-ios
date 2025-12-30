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
    @State private var showNotifications = false
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
            
            // Kingdom claim celebration popup
            if viewModel.showClaimCelebration,
               let kingdomName = viewModel.claimCelebrationKingdom {
                KingdomClaimCelebration(
                    kingdomName: kingdomName,
                    onDismiss: {
                        viewModel.showClaimCelebration = false
                        viewModel.claimCelebrationKingdom = nil
                    }
                )
                .zIndex(1000)
            }
            
            // Modern medieval-themed HUD overlay
            MapHUD(
                viewModel: viewModel,
                showCharacterSheet: $showCharacterSheet,
                showMyKingdoms: $showMyKingdoms,
                showActions: $showActions,
                showProperties: $showProperties,
                showActivity: $showActivity,
                showAPIDebug: $showAPIDebug,
                notificationBadgeCount: notificationBadgeCount
            )
            
            // Floating notifications button (bottom right)
            FloatingNotificationsButton(
                showNotifications: $showNotifications,
                badgeCount: notificationBadgeCount
            )
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
        .onChange(of: viewModel.currentKingdomInside) { oldValue, newValue in
            // Automatically show kingdom info sheet on initial map load if player is inside a kingdom
            if !hasShownInitialKingdom && !viewModel.isLoading && newValue != nil {
                // Delay slightly to ensure map has fully loaded and animated in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let kingdom = viewModel.currentKingdomInside {
                        kingdomForInfoSheet = kingdom
                        hasShownInitialKingdom = true
                    }
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
            FriendsView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet()
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
