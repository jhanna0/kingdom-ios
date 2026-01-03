import SwiftUI
import MapKit

// MARK: - DEPRECATED
// This file is deprecated and no longer used in the app.
// The app now uses DrawnMapView.swift which provides a custom hand-drawn
// parchment-style map instead of Apple Maps.
// See: Views/Map/DrawnMap/DrawnMapView.swift

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
    @State private var mapOpacity: Double = 1.0
    @State private var showActivity = false
    @State private var showNotifications = false
    @State private var notificationBadgeCount = 0
    @State private var showTravelFeeToast = false
    @State private var travelFeeMessage = ""
    @State private var travelFeeIcon = ""
    
    var body: some View {
        ZStack {
            // Simple map view (not used - DrawnMapView is used instead)
            mapContent
            overlayContent
            
            // Error overlay - Brutalist style
            if let error = viewModel.errorMessage {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Error icon with brutalist badge
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 64, height: 64)
                            .offset(x: 3, y: 3)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.buttonDanger)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                    }
                    
                    Text("Map Scroll Damaged")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        viewModel.refreshKingdoms()
                    }) {
                        Label("Repair Map", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
                }
                .padding(KingdomTheme.Spacing.xxLarge)
                .brutalistCard(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
            }
            
            // Travel fee toast notification (at the very top, above sheets) - brutalist style
            if showTravelFeeToast {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: travelFeeIcon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        Text(travelFeeMessage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            // Brutalist offset shadow
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                .fill(Color.black)
                                .offset(x: 3, y: 3)
                            
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                .fill(KingdomTheme.Colors.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
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
                    playerName: viewModel.player.name,
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
                showActions: $showActions,
                showProperties: $showProperties,
                showActivity: $showActivity,
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
                    travelFeeMessage = "Paid \(event.travel_fee_paid) to enter \(event.kingdom_name)"
                    travelFeeIcon = "g.circle.fill"
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
            // Map is always visible
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
                },
                onViewAllKingdoms: {
                    kingdomForInfoSheet = nil
                    showMyKingdoms = true
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
    
    // MARK: - View Components
    
    private var mapContent: some View {
        Map(position: $viewModel.cameraPosition) {
            ForEach(viewModel.kingdoms) { kingdom in
                if kingdom.hasBoundaryCached {
                    MapPolygon(coordinates: kingdom.territory.boundary)
                        .stroke(Color.black, lineWidth: 5)
                        .foregroundStyle(
                            Color(
                                red: kingdom.color.rgba.red,
                                green: kingdom.color.rgba.green,
                                blue: kingdom.color.rgba.blue,
                                opacity: 0.3
                            )
                        )
                }
                
                Annotation(kingdom.name, coordinate: kingdom.territory.center) {
                    KingdomMarker(kingdom: kingdom, homeKingdomId: viewModel.player.homeKingdomId, playerId: viewModel.player.playerId)
                        .onTapGesture {
                            kingdomForInfoSheet = kingdom
                        }
                }
            }
            
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
    }
    
    private var overlayContent: some View {
        VStack {
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
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
