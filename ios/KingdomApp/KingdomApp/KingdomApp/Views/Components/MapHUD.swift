import SwiftUI

struct MapHUD: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showCharacterSheet: Bool
    @Binding var showMyKingdoms: Bool
    @Binding var showActions: Bool
    @Binding var showProperties: Bool
    @Binding var showActivity: Bool
    @Binding var showAPIDebug: Bool
    @EnvironmentObject var musicService: MusicService
    @State private var showMusicSettings = false
    let notificationBadgeCount: Int
    
    var body: some View {
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
                    
                    // Music Control Button
                    Button {
                        showMusicSettings = true
                    } label: {
                        Image(systemName: musicService.isMusicEnabled ? "music.note" : "music.note.slash")
                            .font(.system(size: 14))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                .sheet(isPresented: $showMusicSettings) {
                    MusicSettingsView()
                        .environmentObject(musicService)
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
                    
                    // Friends (icon only)
                    Button(action: {
                        showActivity = true
                    }) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(KingdomTheme.Colors.gold)
                            .cornerRadius(6)
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
}

