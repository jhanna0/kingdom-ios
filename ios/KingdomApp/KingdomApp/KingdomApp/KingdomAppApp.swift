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
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(appInit)
                    .task {
                        // Initialize app data when authenticated
                        await appInit.initialize()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // Refresh when app comes to foreground
                        Task {
                            await appInit.refresh()
                        }
                    }
            } else if authManager.needsOnboarding {
                OnboardingView()
                    .environmentObject(authManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
    }
}
