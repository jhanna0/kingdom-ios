import SwiftUI

struct MapHUD: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showCharacterSheet: Bool
    @Binding var showMyKingdoms: Bool
    @Binding var showActions: Bool
    @Binding var showProperties: Bool
    @Binding var showActivity: Bool
    @Binding var showAPIDebug: Bool
    let notificationBadgeCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Left side - Compact player badge (clickable)
                Button(action: {
                    showCharacterSheet = true
                }) {
                    HStack(spacing: 8) {
                        // Level badge with avatar-style
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [KingdomTheme.Colors.gold, KingdomTheme.Colors.gold.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                                )
                            Text("\(viewModel.player.level)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1)
                        }
                        
                        // Name and gold stacked
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.player.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "bitcoinsign.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                Text("\(viewModel.player.gold)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(KingdomTheme.Colors.parchment)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.brown.opacity(0.3),
                                                Color.brown.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .padding(.leading, 12)
                .padding(.top, 60)
                
                Spacer()
                
                // Right side - Vertical button stack (TikTok/Instagram style)
                VStack(spacing: 14) {
                    // My Kingdoms
                    if viewModel.player.isRuler || !viewModel.player.fiefsRuled.isEmpty {
                        ActionButton(
                            icon: "crown.fill",
                            label: "Kingdoms",
                            color: KingdomTheme.Colors.buttonPrimary,
                            badge: viewModel.player.fiefsRuled.count > 0 ? viewModel.player.fiefsRuled.count : nil
                        ) {
                            showMyKingdoms = true
                        }
                    }
                    
                    // Actions
                    ActionButton(
                        icon: "hammer.fill",
                        label: "Actions",
                        color: KingdomTheme.Colors.buttonSuccess
                    ) {
                        showActions = true
                    }
                    
                    // Properties (Home)
                    ActionButton(
                        icon: "house.fill",
                        label: "Home",
                        color: Color(red: 0.6, green: 0.4, blue: 0.2)
                    ) {
                        showProperties = true
                    }
                    
                    // Activity
                    ActionButton(
                        icon: "person.2.fill",
                        label: "Activity",
                        color: Color(red: 0.5, green: 0.3, blue: 0.5),
                        badge: notificationBadgeCount > 0 ? notificationBadgeCount : nil
                    ) {
                        showActivity = true
                    }
                    
                    // API Debug (small dot indicator)
                    Button {
                        showAPIDebug = true
                    } label: {
                        Circle()
                            .fill(viewModel.apiService.isConnected ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(6)
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 60)
            }
            
            Spacer()
        }
    }
}

// Medieval-themed action button component
private struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var badge: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    ZStack {
                        // Medieval button background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: 0)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(KingdomTheme.Colors.parchment.opacity(0.9))
                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        )
                }
                .frame(width: 56)
                
                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

