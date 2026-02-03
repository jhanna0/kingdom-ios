import SwiftUI

// MARK: - Precise Number Formatting (for HUD gold display)

private extension Int {
    /// Format large numbers with k/m suffix and one decimal place, truncated (e.g., 1950 → "1.9k")
    func abbreviatedPrecise() -> String {
        if abs(self) >= 1_000_000 {
            let truncated = Double(self / 100_000) / 10.0  // Truncate to 1 decimal
            if truncated.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(truncated))m"
            }
            return String(format: "%.1fm", truncated)
        } else if abs(self) >= 1_000 {
            let truncated = Double(self / 100) / 10.0  // Truncate to 1 decimal
            if truncated.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(truncated))k"
            }
            return String(format: "%.1fk", truncated)
        } else {
            return "\(self)"
        }
    }
}

struct MapHUD: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showCharacterSheet: Bool
    @Binding var showActions: Bool
    @Binding var showProperties: Bool
    @Binding var showActivity: Bool
    var pendingFriendRequests: Int = 0
    @State private var currentTime = Date()
    @State private var updateTimer: Timer?
    @State private var showTutorial = false
    @State private var showStore = false
    
    // Get home kingdom name - use direct property from backend (always available)
    private var homeKingdomName: String? {
        return viewModel.player.hometownKingdomName
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
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    )
                    
                    Spacer()
                    
                    // Action Status Indicator - inline
                    // With parallel actions, show the busiest slot (longest remaining time)
                    if let slotCooldowns = viewModel.slotCooldowns, !slotCooldowns.isEmpty {
                        actionStatusBadgeFromSlots(slotCooldowns: slotCooldowns)
                    } else if let cooldown = viewModel.globalCooldown {
                        // Fallback to legacy global cooldown if slots not available
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
                                    .frame(width: 22, height: 22)
                                    .offset(x: 1, y: 1)
                                Circle()
                                    .fill(KingdomTheme.Colors.buttonPrimary)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                Text("\(viewModel.player.level)")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.white)
                            }
                            
                            // Gold & Food stacked
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 2) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(KingdomTheme.Colors.goldLight)
                                    Text(viewModel.player.gold.abbreviatedPrecise())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                }
                                HStack(spacing: 2) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                                    Text(viewModel.player.food.abbreviatedPrecise())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(KingdomTheme.Colors.parchmentLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        )
                    }
                    
                    // Store button (buy gold/resources)
                    Button(action: {
                        showStore = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(KingdomTheme.Colors.goldLight)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
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
                    
                    // Friends (icon only)
                    BrutalistIconButton(
                        icon: "person.2.fill",
                        backgroundColor: KingdomTheme.Colors.buttonDanger,
                        badgeCount: pendingFriendRequests
                    ) {
                        showActivity = true
                    }
                    
                    // Help / Tutorial (icon only)
                    BrutalistIconButton(
                        icon: "questionmark",
                        backgroundColor: KingdomTheme.Colors.inkLight,
                        isCircular: true
                    ) {
                        showTutorial = true
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
        .sheet(isPresented: $showTutorial) {
            TutorialView()
        }
        .sheet(isPresented: $showStore) {
            StoreView()
                .environmentObject(viewModel.player)
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
    
    // MARK: - Action Status Badge (Slot-based for Parallel Actions)
    
    @ViewBuilder
    private func actionStatusBadgeFromSlots(slotCooldowns: [String: SlotCooldown]) -> some View {
        let elapsed = viewModel.cooldownFetchedAt.map { Date().timeIntervalSince($0) } ?? 0
        
        // Find the busiest slot (longest remaining time)
        let busiestSlot = slotCooldowns
            .map { (key: $0.key, value: $0.value) }
            .filter { !$0.value.ready }
            .max { 
                let remaining1 = max(0, Double($0.value.secondsRemaining) - elapsed)
                let remaining2 = max(0, Double($1.value.secondsRemaining) - elapsed)
                return remaining1 < remaining2
            }
        
        HStack(spacing: 4) {
            if let slot = busiestSlot,
               let action = slot.value.blockingAction {
                let calculatedRemaining = max(0, Double(slot.value.secondsRemaining) - elapsed)
                
                Image(systemName: actionIcon(for: action))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(actionBackgroundColor(for: action))
                let minutes = Int(calculatedRemaining) / 60
                Text("\(minutes)m")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            } else {
                // All slots are idle
                Text("💤")
                    .font(.system(size: 12))
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(KingdomTheme.Colors.parchmentLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 2)
                )
        )
    }
    
    // MARK: - Action Status Badge (Legacy - for backward compatibility)
    
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
        .frame(height: 36)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(KingdomTheme.Colors.parchmentLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 2)
                )
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
    var iconColor: Color = .white
    var size: CGFloat = 36
    var isCircular: Bool = false
    var badgeCount: Int = 0
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isCircular {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: size, height: size)
                        .offset(x: 2, y: 2)
                    
                    // Button
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: size, height: size)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                } else {
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
                }
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
                
                // Badge overlay
                if badgeCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 18, height: 18)
                            .offset(x: 1, y: 1)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 1.5)
                            )
                        Text("\(min(badgeCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: size / 2 - 4, y: -size / 2 + 4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

