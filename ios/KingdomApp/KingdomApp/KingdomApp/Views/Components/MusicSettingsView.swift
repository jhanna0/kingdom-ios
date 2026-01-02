//
//  MusicSettingsView.swift
//  KingdomApp
//
//  Created by Jad Hanna on 12/30/25.
//

import SwiftUI

struct MusicSettingsView: View {
    @EnvironmentObject var musicService: MusicService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Music Toggle
                    HStack {
                        Image(systemName: musicService.isMusicEnabled ? "music.note" : "music.note.slash")
                            .font(.title2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Background Music")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: $musicService.isMusicEnabled)
                            .labelsHidden()
                            .tint(KingdomTheme.Colors.inkMedium)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    // Sound Effects Toggle
                    HStack {
                        Image(systemName: musicService.isSoundEffectsEnabled ? "speaker.wave.3" : "speaker.slash")
                            .font(.title2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Sound Effects")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: $musicService.isSoundEffectsEnabled)
                            .labelsHidden()
                            .tint(KingdomTheme.Colors.inkMedium)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    Spacer()
                    
                    // Info text
                    Text("Background music will play continuously while you explore your kingdom.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
    }
}

#Preview {
    MusicSettingsView()
        .environmentObject(MusicService.shared)
}

