//
//  ContentView.swift
//  KingdomApp
//
//  Created by Jad Hanna on 12/27/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appInit: AppInitService
    
    var body: some View {
        ZStack {
            MapView()
                .ignoresSafeArea()
            
            // Loading indicator during init
            if appInit.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    
                    Text("Loading your kingdom...")
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
        }
    }
}

#Preview {
    ContentView()
}
