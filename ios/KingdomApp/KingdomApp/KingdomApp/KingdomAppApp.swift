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
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
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
