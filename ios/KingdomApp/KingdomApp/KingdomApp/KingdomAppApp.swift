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
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if authManager.isAuthenticated {
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
                if authManager.hasCriticalError {
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
            }
            // API errors use BlockingErrorWindow which is a UIKit window overlay
            // that appears above ALL content including sheets - handled by APIClient directly
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
    @State private var showMarket = false
    @State private var showNotifications = false
    @State private var notificationBadgeCount = 0
    @State private var hasShownInitialKingdom = false
    @State private var showTravelNotification = false
    @State private var displayedTravelEvent: TravelEvent?
    
    var body: some View {
        ZStack {
            DrawnMapView(viewModel: viewModel, kingdomForInfoSheet: $kingdomForInfoSheet)
                .ignoresSafeArea()
                .opacity(hasLoadedInitially ? 1 : 0)
            
            // Show loading screen until initial load completes
            if !hasLoadedInitially {
                ZStack {
                    Color.black.ignoresSafeArea()
                    MedievalLoadingView(status: "Loading your kingdom...")
                }
            }
            
            // HUD and UI overlays
            if hasLoadedInitially {
                MapHUD(
                    viewModel: viewModel,
                    showCharacterSheet: $showCharacterSheet,
                    showActions: $showActions,
                    showProperties: $showProperties,
                    showActivity: $showActivity,
                    showMarket: $showMarket,
                    notificationBadgeCount: notificationBadgeCount
                )
                
                FloatingNotificationsButton(
                    showNotifications: $showNotifications,
                    badgeCount: notificationBadgeCount
                )
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
            
            // Travel notification toast
            if showTravelNotification, let travelEvent = displayedTravelEvent {
                VStack {
                    TravelNotificationToast(
                        travelEvent: travelEvent,
                        onDismiss: {
                            withAnimation {
                                showTravelNotification = false
                                displayedTravelEvent = nil
                            }
                            // Clear the event from viewModel to avoid re-showing
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
        .onReceive(locationManager.$currentLocation) { location in
            if let location = location {
                viewModel.updateUserLocation(location)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await appInit.refresh()
                await loadNotificationBadge()
                
                // Clear delivered notifications when app comes to foreground
                NotificationManager.shared.clearDeliveredNotifications()
            }
        }
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
        .sheet(isPresented: $showMarket) {
            NavigationStack {
                MarketView()
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet()
        }
        .task {
            // Clear notification badge when app opens
            NotificationManager.shared.clearDeliveredNotifications()
            
            await appInit.initialize()
            await loadNotificationBadge()
            viewModel.loadInitialCooldown()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                withAnimation(.easeIn(duration: 0.3)) {
                    hasLoadedInitially = true
                }
                
                // When loading completes, show kingdom sheet if player is inside one
                if !hasShownInitialKingdom, let kingdom = viewModel.currentKingdomInside {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        kingdomForInfoSheet = kingdom
                        hasShownInitialKingdom = true
                    }
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
        .onChange(of: viewModel.latestTravelEvent) { oldValue, newValue in
            // Show travel notification when travel event occurs
            if let travelEvent = newValue {
                displayedTravelEvent = travelEvent
                withAnimation {
                    showTravelNotification = true
                }
                
                // Auto-dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation {
                        showTravelNotification = false
                    }
                    // Clear after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        displayedTravelEvent = nil
                        viewModel.latestTravelEvent = nil
                    }
                }
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
