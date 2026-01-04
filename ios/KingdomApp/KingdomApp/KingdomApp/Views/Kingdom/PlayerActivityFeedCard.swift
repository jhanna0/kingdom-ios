import SwiftUI

/// Shows live player activity feed in a kingdom - brutalist style
struct PlayerActivityFeedCard: View {
    let kingdomId: String
    
    @State private var playersData: PlayersInKingdomResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTimer: Timer?
    
    // Intelligent polling state
    @State private var currentRefreshInterval: TimeInterval = 10.0
    @State private var unchangedPollCount: Int = 0
    
    // Constants
    private let baseRefreshInterval: TimeInterval = 5.0   // Fast polling for FIFO effect
    private let maxRefreshInterval: TimeInterval = 15.0   // Don't slow down too much
    private let displayLimit: Int = 5                      // Only show top 5
    private let fetchLimit: Int = 10                       // Fetch a few extra for smoother transitions
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "person.3.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalBlue, cornerRadius: 10)
                
                Text("Player Activity")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if let data = playersData {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(1.8)
                                    .opacity(0.3)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: data.online_count)
                            )
                        
                        Text("\(data.online_count) online")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if let error = errorMessage {
                // Show intelligence required message
                VStack(spacing: 12) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 14)
                    
                    Text("Intelligence Required")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(error)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if let data = playersData {
                if data.players.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(FontStyles.iconLarge)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 12)
                            
                            Text("No players in this kingdom")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    // Show up to 5 most recent/relevant players - FIFO queue style
                    VStack(spacing: 10) {
                        ForEach(Array(data.players.prefix(5))) { playerData in
                            ZStack {
                                NavigationLink(destination: PlayerProfileView(userId: playerData.id)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                PlayerActivityRow(playerData: playerData)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: data.players.map(\.id))
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .task {
            await loadPlayers()
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private func loadPlayers() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Fetch only what we need + a few extra
            let data = try await KingdomAPIService.shared.player.getPlayersInKingdom(kingdomId, limit: fetchLimit)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.playersData = data
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Scout to reveal kingdom activity"
                isLoading = false
            }
        }
    }
    
    private func refreshPlayers() async {
        // Silent refresh (no loading spinner)
        do {
            // Fetch efficiently with limit
            let newData = try await KingdomAPIService.shared.player.getPlayersInKingdom(kingdomId, limit: fetchLimit)
            
            await MainActor.run {
                guard let oldData = playersData else {
                    // First load, just set it
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        self.playersData = newData
                    }
                    return
                }
                
                // Find new players (not in old list)
                let oldIds = Set(oldData.players.map(\.id))
                let newPlayers = newData.players.filter { !oldIds.contains($0.id) }
                
                // Find removed players (in old but not in new)
                let newIds = Set(newData.players.map(\.id))
                let removedIds = oldData.players.filter { !newIds.contains($0.id) }.map(\.id)
                
                if !newPlayers.isEmpty || !removedIds.isEmpty {
                    // Trickle in changes
                    Task {
                        await trickleUpdates(newPlayers: newPlayers, removedIds: removedIds, fullData: newData)
                    }
                } else {
                    // No changes
                    unchangedPollCount += 1
                    if unchangedPollCount >= 3 {
                        currentRefreshInterval = min(currentRefreshInterval * 1.5, maxRefreshInterval)
                        restartPolling()
                    }
                }
            }
        } catch {
            // Silently fail on refresh - keep existing data visible
            print("Failed to refresh players: \(error)")
        }
    }
    
    private func trickleUpdates(newPlayers: [PlayerInKingdom], removedIds: [Int], fullData: PlayersInKingdomResponse) async {
        // Add new players one at a time at the TOP, removing from BOTTOM to keep size at 5
        for newPlayer in newPlayers {
            await MainActor.run {
                guard let current = playersData else { return }
                
                var updatedPlayers = current.players
                
                // Add new player at top
                updatedPlayers.insert(newPlayer, at: 0)
                
                // Keep only top 5 (removes from bottom automatically)
                if updatedPlayers.count > 5 {
                    updatedPlayers = Array(updatedPlayers.prefix(5))
                }
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.playersData = PlayersInKingdomResponse(
                        kingdom_id: current.kingdom_id,
                        kingdom_name: current.kingdom_name,
                        total_players: fullData.total_players,
                        online_count: fullData.online_count,
                        players: updatedPlayers
                    )
                }
            }
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s between additions for smooth trickle
        }
        
        // Reset poll speed after activity
        await MainActor.run {
            unchangedPollCount = 0
            currentRefreshInterval = baseRefreshInterval
            restartPolling()
        }
    }
    
    private func hasDataChanged(old: PlayersInKingdomResponse?, new: PlayersInKingdomResponse) -> Bool {
        guard let old = old else { return true }
        
        // Check key changes
        if old.online_count != new.online_count { return true }
        if old.total_players != new.total_players { return true }
        
        // Check if top players changed (IDs or activity)
        let oldTop = old.players.prefix(displayLimit)
        let newTop = new.players.prefix(displayLimit)
        
        if oldTop.count != newTop.count { return true }
        
        for (oldPlayer, newPlayer) in zip(oldTop, newTop) {
            if oldPlayer.id != newPlayer.id { return true }
            if oldPlayer.is_online != newPlayer.is_online { return true }
            if oldPlayer.activity.type != newPlayer.activity.type { return true }
        }
        
        return false
    }
    
    private func startPolling() {
        // Start timer for periodic refreshes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: currentRefreshInterval, repeats: true) { _ in
            Task {
                await refreshPlayers()
            }
        }
        print("🔄 Polling started: every \(Int(currentRefreshInterval))s")
    }
    
    private func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("⏸️ Polling stopped")
    }
    
    private func restartPolling() {
        stopPolling()
        startPolling()
    }
}

// MARK: - Player Activity Row - Brutalist Style

struct PlayerActivityRow: View {
    let playerData: PlayerInKingdom
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Text(String(playerData.display_name.prefix(1)).uppercased())
                    .font(FontStyles.bodyLargeBold)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(
                        backgroundColor: playerData.is_ruler ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonPrimary,
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                // Online indicator
                if playerData.is_online {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            
            // Player info and activity
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(playerData.display_name)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .lineLimit(1)
                    
                    if playerData.is_ruler {
                        Image(systemName: "crown.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                // Activity with icon
                HStack(spacing: 6) {
                    Image(systemName: playerData.activity.icon)
                        .font(FontStyles.iconMini)
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(playerData.activity.actualColor)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black, lineWidth: 1)
                        )
                    
                    Text(playerData.activity.displayText)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Level badge
            VStack(spacing: 2) {
                Text("LVL")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("\(playerData.level)")
                    .font(FontStyles.bodyLargeBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .frame(width: 40)
            .padding(.vertical, 6)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "green": return KingdomTheme.Colors.buttonSuccess
        case "purple": return KingdomTheme.Colors.buttonSpecial
        case "orange": return .orange
        case "yellow": return KingdomTheme.Colors.inkMedium
        case "red": return KingdomTheme.Colors.buttonDanger
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PlayerActivityFeedCard(kingdomId: "test-kingdom")
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
