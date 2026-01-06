import SwiftUI

struct MapHUD: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showCharacterSheet: Bool
    @Binding var showActions: Bool
    @Binding var showProperties: Bool
    @Binding var showActivity: Bool
    @Binding var showMarket: Bool
    @State private var currentTime = Date()
    @State private var updateTimer: Timer?
    let notificationBadgeCount: Int
    
    // Get home kingdom name
    private var homeKingdomName: String? {
        guard let homeKingdomId = viewModel.player.hometownKingdomId else { return nil }
        return viewModel.kingdoms.first(where: { $0.id == homeKingdomId })?.name
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                // Top row - player and location
                HStack(spacing: 12) {
                    // Player badge with brutalist style - shows home kingdom
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.player.isRuler ? "crown.fill" : "shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                    if let homeKingdom = homeKingdomName {
                        Text("\(viewModel.player.name) of \(homeKingdom)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Text(viewModel.player.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black)
                                .offset(x: 2, y: 2)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(KingdomTheme.Colors.parchmentLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                    )
                    
                    Spacer()
                    
                    // Action Status Indicator - inline
                    if let cooldown = viewModel.globalCooldown {
                        actionStatusBadge(cooldown: cooldown)
                    }
                }
                
                // Divider - thick black line
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                // Bottom row - action buttons
                HStack(spacing: 10) {
                    // Character button (shows level + gold) - brutalist style
                    Button(action: {
                        showCharacterSheet = true
                    }) {
                        HStack(spacing: 6) {
                            // Level badge
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 26, height: 26)
                                    .offset(x: 1, y: 1)
                                Circle()
                                    .fill(KingdomTheme.Colors.buttonPrimary)
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                Text("\(viewModel.player.level)")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.white)
                            }
                            
                            // Gold
                            HStack(spacing: 3) {
                                Text("\(viewModel.player.gold)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(KingdomTheme.Colors.goldLight)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black)
                                    .offset(x: 2, y: 2)
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(KingdomTheme.Colors.parchmentLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }
                        )
                    }
                    
                    Spacer()
                    
                    // Actions (icon only)
                    BrutalistIconButton(
                        icon: "hammer.fill",
                        backgroundColor: KingdomTheme.Colors.royalBlue
                    ) {
                        showActions = true
                    }
                    
                    // Properties (icon only)
                    BrutalistIconButton(
                        icon: "house.fill",
                        backgroundColor: KingdomTheme.Colors.buttonSuccess
                    ) {
                        showProperties = true
                    }
                    
                    // Market (icon only)
                    BrutalistIconButton(
                        icon: "cart.fill",
                        backgroundColor: KingdomTheme.Colors.imperialGold
                    ) {
                        showMarket = true
                    }
                    
                    // Friends (icon only)
                    BrutalistIconButton(
                        icon: "person.2.fill",
                        backgroundColor: KingdomTheme.Colors.buttonDanger
                    ) {
                        showActivity = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    // Offset shadow
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    
                    // Main card
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
            // Soft shadow for extra depth
            .shadow(
                color: KingdomTheme.Shadows.brutalistSoft.color,
                radius: KingdomTheme.Shadows.brutalistSoft.radius,
                x: KingdomTheme.Shadows.brutalistSoft.x,
                y: KingdomTheme.Shadows.brutalistSoft.y
            )
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            startUIUpdateTimer()
        }
        .onDisappear {
            stopUIUpdateTimer()
        }
    }
    
    // MARK: - Timer
    
    private func startUIUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopUIUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Action Status Badge (Compact)
    
    @ViewBuilder
    private func actionStatusBadge(cooldown: GlobalCooldown) -> some View {
        let elapsed = viewModel.cooldownFetchedAt.map { Date().timeIntervalSince($0) } ?? 0
        let calculatedRemaining = max(0, Double(cooldown.secondsRemaining) - elapsed)
        let isIdle = cooldown.ready || calculatedRemaining <= 0
        
        HStack(spacing: 4) {
            if isIdle {
                Text("💤")
                    .font(.system(size: 12))
            } else if let action = cooldown.blockingAction {
                Image(systemName: actionIcon(for: action))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(actionBackgroundColor(for: action))
                let minutes = Int(calculatedRemaining) / 60
                Text("\(minutes)m")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    private func actionIcon(for action: String) -> String {
        return ActionIconHelper.icon(for: action)
    }
    
    private func actionBackgroundColor(for action: String?) -> Color {
        guard let action = action else {
            return KingdomTheme.Colors.parchmentLight
        }
        return ActionIconHelper.actionColor(for: action)
    }
}

// MARK: - Brutalist Icon Button Component
struct BrutalistIconButton: View {
    let icon: String
    var backgroundColor: Color = KingdomTheme.Colors.buttonPrimary
    var size: CGFloat = 36
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Offset shadow
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .frame(width: size, height: size)
                    .offset(x: 2, y: 2)
                
                // Button
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

