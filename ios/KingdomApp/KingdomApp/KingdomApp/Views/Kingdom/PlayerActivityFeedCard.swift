import SwiftUI

/// Shows live player activity feed in a kingdom
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 8)
                
                Text("Player Activity")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if let data = playersData {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .overlay(
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(1.5)
                                    .opacity(0.3)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: data.online_count)
                            )
                        
                        Text("\(data.online_count) online")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            
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
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
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
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash")
                                .font(FontStyles.iconMedium)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            Text("No players in this kingdom")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    // Show up to 5 most recent/relevant players - FIFO queue style
                    VStack(spacing: 8) {
                        ForEach(Array(data.players.prefix(5))) { playerData in
                            NavigationLink(destination: PlayerProfileView(userId: playerData.id)) {
                                PlayerActivityRow(playerData: playerData)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                        
                        if data.players.count > 5 {
                            Text("+\(data.players.count - 5) more players")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: data.players.map(\.id))
                }
            }
        }
        .padding()
        .parchmentCard()
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
                errorMessage = "Failed to load players"
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

// MARK: - Player Activity Row

struct PlayerActivityRow: View {
    let playerData: PlayerInKingdom
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Text(String(playerData.display_name.prefix(1)).uppercased())
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(
                        backgroundColor: playerData.is_ruler ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium,
                        cornerRadius: 8
                    )
                
                // Online indicator
                if playerData.is_online {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(KingdomTheme.Colors.parchmentLight, lineWidth: 2)
                        )
                }
            }
            
            // Player info and activity
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(playerData.display_name)
                        .font(FontStyles.bodySmallBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .lineLimit(1)
                    
                    if playerData.is_ruler {
                        Image(systemName: "crown.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                
                // Activity with icon
                HStack(spacing: 4) {
                    Image(systemName: playerData.activity.icon)
                        .font(FontStyles.iconMini)
                        .foregroundColor(activityColor(playerData.activity.color))
                    
                    Text(playerData.activity.displayText)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Level badge
            Text("L\(playerData.level)")
                .font(FontStyles.labelSmall)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(KingdomTheme.Colors.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
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

