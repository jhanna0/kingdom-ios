//
//  KingdomAppApp.swift
//  KingdomApp
//
//  Created by Jad Hanna on 12/27/25.
//

import SwiftUI

@main
struct KingdomAppApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var appInit = AppInitService()
    @StateObject private var musicService = MusicService.shared
    @StateObject private var globalLocationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // PRIORITY 1: Location check - app cannot function without location
                if !globalLocationManager.isLocationAuthorized {
                    LocationRequiredView(locationManager: globalLocationManager)
                }
                // PRIORITY 2: Authentication and onboarding flow
                else if authManager.isAuthenticated {
                    AuthenticatedView()
                        .environmentObject(authManager)
                        .environmentObject(appInit)
                        .environmentObject(musicService)
                } else if authManager.needsOnboarding {
                    OnboardingView()
                        .environmentObject(authManager)
                        .environmentObject(musicService)
                } else if !authManager.isCheckingAuth {
                    AuthView()
                        .environmentObject(authManager)
                        .environmentObject(musicService)
                }
                
                // BLOCKING error overlay for critical auth failures
                if authManager.hasCriticalError && globalLocationManager.isLocationAuthorized {
                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()
                        BlockingErrorView(
                            title: "Authentication Failed",
                            message: authManager.criticalErrorMessage ?? "Unknown error",
                            primaryAction: .init(
                                label: "Retry",
                                icon: "arrow.triangle.2.circlepath",
                                color: KingdomTheme.Colors.buttonPrimary,
                                action: {
                                    Task {
                                        await authManager.retryAuth()
                                    }
                                }
                            ),
                            secondaryAction: .init(
                                label: "Sign Out",
                                icon: "rectangle.portrait.and.arrow.right",
                                color: KingdomTheme.Colors.buttonDanger,
                                action: { authManager.logout() }
                            )
                        )
                    }
                }
            }
            .onAppear {
                // Start background music when app launches
                musicService.playBackgroundMusic(filename: "ambient_background_full.mp3", volume: 0.25)
                
                // Request notification permission for action cooldowns
                Task {
                    _ = await NotificationManager.shared.requestPermission()
                }
                
                // Initialize in-app notification manager (sets itself as UNUserNotificationCenter delegate)
                // This intercepts notifications when app is in foreground and shows stylish toast instead
                _ = InAppNotificationManager.shared
            }
            // API errors use BlockingErrorWindow which is a UIKit window overlay
            // that appears above ALL content including sheets - handled by APIClient directly
        }
    }
}

// MARK: - Location Required View (Blocking)

struct LocationRequiredView: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                Spacer()
                
                // Icon
                Image(systemName: locationManager.isLocationDenied ? "location.slash.fill" : "location.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .brutalistBadge(
                        backgroundColor: locationManager.isLocationDenied ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.buttonWarning,
                        cornerRadius: 24,
                        shadowOffset: 6,
                        borderWidth: 4
                    )
                
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Text("Location Required")
                        .font(FontStyles.displayLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("This is critical for gameplay")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                // Explanation Card
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.large) {
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        Image(systemName: "map.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.inkMedium,
                                cornerRadius: 8
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Why Location?")
                                .font(FontStyles.headingSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("This is a location-based game. You must be physically present in a city to rule it!")
                                .font(FontStyles.bodySmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    
                    if locationManager.isLocationDenied {
                        Text("Location access is required for this game. You can enable it in Settings.")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else {
                        Text("Grant location access to begin your journey.")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    // Privacy notice
                    HStack(spacing: KingdomTheme.Spacing.small) {
                        Image(systemName: "lock.shield.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        Text("Your precise location is NEVER stored. We only use it to determine which city you're in.")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
                .padding(KingdomTheme.Spacing.large)
                .brutalistCard(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 20
                )
                .padding(.horizontal, KingdomTheme.Spacing.large)
                
                Spacer()
                
                // Action Button
                Button(action: {
                    locationManager.requestPermissions()
                }) {
                    HStack {
                        Text(locationManager.isLocationDenied ? "Open Settings" : "Continue")
                            .font(FontStyles.bodyLargeBold)
                        Image(systemName: locationManager.isLocationDenied ? "gear" : "location.fill")
                            .font(FontStyles.iconSmall)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KingdomTheme.Spacing.large)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .fill(Color.black)
                                .offset(x: 4, y: 4)
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .fill(KingdomTheme.Colors.inkMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                        .stroke(Color.black, lineWidth: 3)
                                )
                        }
                    )
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.bottom, KingdomTheme.Spacing.xxLarge)
            }
        }
    }
}

struct AuthenticatedView: View {
    @EnvironmentObject var appInit: AppInitService
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var hasLoadedInitially = false
    @State private var kingdomForInfoSheet: Kingdom?
    @State private var showMyKingdoms = false
    @State private var showActions = false
    @State private var showCharacterSheet = false
    @State private var showProperties = false
    @State private var kingdomToShow: Kingdom?
    @State private var showActivity = false
    @State private var showNotifications = false
    @State private var hasUnreadNotifications = false
    @State private var pendingFriendRequestCount: Int = 0
    @State private var pendingAllianceRequestCount: Int = 0
    @State private var pendingTradeRequestCount: Int = 0
    @State private var hasShownInitialKingdom = false
    @State private var showTravelNotification = false
    @State private var displayedTravelEvent: TravelEvent?
    @State private var showWeatherToast = false
    @State private var currentWeather: WeatherData?
    @State private var showCoupView = false
    
    var body: some View {
        mainContent
            .onReceive(locationManager.$currentLocation) { location in
                if let location = location {
                    viewModel.updateUserLocation(location)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await appInit.refresh()
                    await loadNotificationBadge()
                    NotificationManager.shared.clearDeliveredNotifications()
                }
            }
            .modifier(SheetModifiers(
                showMyKingdoms: $showMyKingdoms,
                showActions: $showActions,
                showProperties: $showProperties,
                showCharacterSheet: $showCharacterSheet,
                showActivity: $showActivity,
                showNotifications: $showNotifications,
                kingdomForInfoSheet: $kingdomForInfoSheet,
                kingdomToShow: $kingdomToShow,
                showCoupView: $showCoupView,
                viewModel: viewModel
            ))
            .modifier(EventHandlers(
                appInit: appInit,
                viewModel: viewModel,
                hasLoadedInitially: $hasLoadedInitially,
                hasShownInitialKingdom: $hasShownInitialKingdom,
                kingdomForInfoSheet: $kingdomForInfoSheet,
                hasUnreadNotifications: $hasUnreadNotifications,
                showTravelNotification: $showTravelNotification,
                displayedTravelEvent: $displayedTravelEvent,
                showWeatherToast: $showWeatherToast,
                currentWeather: $currentWeather,
                syncRuledKingdomsToPlayer: syncRuledKingdomsToPlayer,
                loadNotificationBadge: loadNotificationBadge,
                loadWeatherForKingdom: loadWeatherForKingdom
            ))
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            mapLayer
            loadingLayer
            hudLayer
            overlaysLayer
        }
    }
    
    @ViewBuilder
    private var mapLayer: some View {
        DrawnMapView(viewModel: viewModel, kingdomForInfoSheet: $kingdomForInfoSheet)
            .ignoresSafeArea()
            .opacity(hasLoadedInitially ? 1 : 0)
    }
    
    @ViewBuilder
    private var loadingLayer: some View {
        if !hasLoadedInitially {
            ZStack {
                Color.black.ignoresSafeArea()
                MedievalLoadingView(status: "Loading your kingdom...")
            }
        }
    }
    
    @ViewBuilder
    private var hudLayer: some View {
        if hasLoadedInitially {
            MapHUD(
                viewModel: viewModel,
                showCharacterSheet: $showCharacterSheet,
                showActions: $showActions,
                showProperties: $showProperties,
                showActivity: $showActivity,
                pendingFriendRequests: pendingFriendRequestCount + pendingAllianceRequestCount + pendingTradeRequestCount
            )
            
            coupBadgeOverlay
            
            FloatingNotificationsButton(
                showNotifications: $showNotifications,
                hasUnread: hasUnreadNotifications
            )
        }
    }
    
    @ViewBuilder
    private var coupBadgeOverlay: some View {
        // Show badge for battles in CURRENT kingdom (where you're standing) OR home kingdom
        // Priority: current kingdom first (since you're physically there)
        if let battle = viewModel.activeBattleInCurrentKingdom ?? viewModel.activeCoupInHomeKingdom {
            VStack {
                Spacer().frame(height: 152)
                HStack {
                    Spacer()
                    BattleMapBadgeView(
                        battleType: battle.isInvasion ? .invasion : .coup,
                        status: battle.status,
                        timeRemaining: battle.timeRemainingFormatted,
                        attackerCount: battle.attacker_count,
                        defenderCount: battle.defender_count,
                        onTap: { showCoupView = true }
                    )
                }
                .padding(.horizontal, 12)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var overlaysLayer: some View {
        claimCelebrationOverlay
        popupNotificationOverlay
        travelNotificationOverlay
        weatherToastOverlay
        // In-app notifications use UIWindow overlay (InAppNotificationManager)
        // so they appear above sheets and all other content
    }
    
    @ViewBuilder
    private var claimCelebrationOverlay: some View {
        if viewModel.showClaimCelebration, let kingdomName = viewModel.claimCelebrationKingdom {
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
    }
    
    @ViewBuilder
    private var popupNotificationOverlay: some View {
        if let popup = appInit.popupNotification {
            NotificationPopup(
                notification: popup,
                playerName: viewModel.player.name,
                onDismiss: { appInit.popupNotification = nil }
            )
            .zIndex(1001)
        }
    }
    
    @ViewBuilder
    private var travelNotificationOverlay: some View {
        if showTravelNotification, let travelEvent = displayedTravelEvent {
            VStack {
                TravelNotificationToast(
                    travelEvent: travelEvent,
                    onDismiss: {
                        withAnimation {
                            showTravelNotification = false
                            displayedTravelEvent = nil
                        }
                        viewModel.latestTravelEvent = nil
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 60)
                Spacer()
            }
            .zIndex(999)
        }
    }
    
    @ViewBuilder
    private var weatherToastOverlay: some View {
        if showWeatherToast, let weather = currentWeather {
            VStack {
                HStack {
                    WeatherToast(
                        weather: weather,
                        onDismiss: {
                            showWeatherToast = false
                            currentWeather = nil
                        }
                    )
                    .padding(.leading, 16)
                    Spacer()
                }
                .padding(.top, 155)
                Spacer()
            }
            .transition(.opacity)
            .zIndex(998)
        }
    }
    
    private func loadNotificationBadge() async {
        do {
            let summary = try await viewModel.apiService.notifications.getSummary()
            await MainActor.run {
                hasUnreadNotifications = summary.hasUnread
                pendingFriendRequestCount = summary.pendingFriendRequests
                pendingAllianceRequestCount = summary.pendingAllianceRequests
                pendingTradeRequestCount = summary.pendingTradeRequests
            }
        } catch {
            print("❌ Failed to load notification badge: \(error)")
        }
    }
    
    /// Sync ruled kingdoms from AppInitService to player (backend is SOURCE OF TRUTH)
    private func syncRuledKingdomsToPlayer() {
        let kingdoms = appInit.ruledKingdoms.map { (id: $0.id, name: $0.name) }
        viewModel.player.updateRuledKingdoms(kingdoms: kingdoms)
        
        // Also update isRuler based on whether there are any ruled kingdoms
        // Note: is_ruler from /player/state is the primary source, but this ensures consistency
        if !kingdoms.isEmpty && !viewModel.player.isRuler {
            print("⚠️ Ruled kingdoms found but isRuler is false - backend should have set is_ruler=true")
        }
    }
    
    private func loadWeatherForKingdom(_ kingdomId: String) async {
        do {
            let response = try await KingdomAPIService.shared.weather.getKingdomWeather(kingdomId: kingdomId)
            await MainActor.run {
                currentWeather = response.weather
                withAnimation(.easeIn(duration: 0.3)) {
                    showWeatherToast = true
                }
            }
        } catch {
            print("⚠️ Weather error: \(error)")
        }
    }
}

// MARK: - Sheet Modifiers (broken out to help compiler)

private struct SheetModifiers: ViewModifier {
    @Binding var showMyKingdoms: Bool
    @Binding var showActions: Bool
    @Binding var showProperties: Bool
    @Binding var showCharacterSheet: Bool
    @Binding var showActivity: Bool
    @Binding var showNotifications: Bool
    @Binding var kingdomForInfoSheet: Kingdom?
    @Binding var kingdomToShow: Kingdom?
    @Binding var showCoupView: Bool
    @ObservedObject var viewModel: MapViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showMyKingdoms) {
                MyKingdomsSheet(
                    player: viewModel.player,
                    viewModel: viewModel,
                    onDismiss: { showMyKingdoms = false }
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
                            Button("Done") { kingdomToShow = nil }
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
            .fullScreenCover(isPresented: $showCoupView) {
                // Show battle from current kingdom first, then home kingdom
                if let battle = viewModel.activeBattleInCurrentKingdom ?? viewModel.activeCoupInHomeKingdom {
                    BattleView(battleId: battle.id, onDismiss: { showCoupView = false })
                }
            }
    }
}

// MARK: - Event Handlers (broken out to help compiler)

private struct EventHandlers: ViewModifier {
    @ObservedObject var appInit: AppInitService
    @ObservedObject var viewModel: MapViewModel
    @Binding var hasLoadedInitially: Bool
    @Binding var hasShownInitialKingdom: Bool
    @Binding var kingdomForInfoSheet: Kingdom?
    @Binding var hasUnreadNotifications: Bool
    @Binding var showTravelNotification: Bool
    @Binding var displayedTravelEvent: TravelEvent?
    @Binding var showWeatherToast: Bool
    @Binding var currentWeather: WeatherData?
    
    let syncRuledKingdomsToPlayer: () -> Void
    let loadNotificationBadge: () async -> Void
    let loadWeatherForKingdom: (String) async -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: showTravelNotification) { _, _ in }  // Placeholder for type inference
            .task {
                NotificationManager.shared.clearDeliveredNotifications()
                await appInit.initialize()
                syncRuledKingdomsToPlayer()
                await loadNotificationBadge()
                viewModel.loadInitialCooldown()
                
                // Connect to game events WebSocket for real-time updates (duels, etc.)
                if let token = APIClient.shared.authToken {
                    GameEventManager.shared.connect(authToken: token)
                }
            }
            .onChange(of: appInit.ruledKingdoms) { _, _ in
                syncRuledKingdomsToPlayer()
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if !isLoading {
                    withAnimation(.easeIn(duration: 0.3)) {
                        hasLoadedInitially = true
                    }
                    if !hasShownInitialKingdom, let kingdom = viewModel.currentKingdomInside {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            kingdomForInfoSheet = kingdom
                            hasShownInitialKingdom = true
                        }
                    }
                }
            }
            .onChange(of: viewModel.currentKingdomInside) { oldValue, newValue in
                if !hasShownInitialKingdom && !viewModel.isLoading && newValue != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if let kingdom = viewModel.currentKingdomInside {
                            kingdomForInfoSheet = kingdom
                            hasShownInitialKingdom = true
                        }
                    }
                }
                if let kingdom = newValue, oldValue?.id != newValue?.id {
                    Task { await loadWeatherForKingdom(kingdom.id) }
                }
            }
            .onChange(of: viewModel.latestTravelEvent) { _, newValue in
                if let travelEvent = newValue {
                    displayedTravelEvent = travelEvent
                    withAnimation { showTravelNotification = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { showTravelNotification = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            displayedTravelEvent = nil
                            viewModel.latestTravelEvent = nil
                        }
                    }
                }
            }
            .onChange(of: hasUnreadNotifications) { _, _ in }  // Keep for notification badge updates
    }
}
