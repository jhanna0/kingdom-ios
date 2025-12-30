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
            }
            .onAppear {
                // Start background music when app launches
                musicService.playBackgroundMusic(filename: "ambient_background.mp3", volume: 0.25)
            }
        }
    }
}

struct AuthenticatedView: View {
    @EnvironmentObject var appInit: AppInitService
    @StateObject private var viewModel = MapViewModel()
    @State private var hasLoadedInitially = false
    
    var body: some View {
        ZStack {
            MapView(viewModel: viewModel)
                .ignoresSafeArea()
                .opacity(hasLoadedInitially ? 1 : 0)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await appInit.refresh()
                    }
                }
            
            // Show loading screen until initial load completes
            if !hasLoadedInitially {
                ZStack {
                    Color.black.ignoresSafeArea()
                    MedievalLoadingView(status: "Loading your kingdom...")
                }
            }
        }
        .task {
            await appInit.initialize()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                withAnimation(.easeIn(duration: 0.3)) {
                    hasLoadedInitially = true
                }
            }
        }
    }
}
