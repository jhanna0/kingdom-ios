import SwiftUI

/// Kingdom marker with flying activity icons that trickle out when players are active
struct KingdomMarkerWithActivity: View {
    let kingdom: Kingdom
    let homeKingdomId: String?
    let playerId: Int
    
    // Flying icons state
    @State private var flyingIcons: [FlyingIconData] = []
    @State private var lastSeenPlayerIds: Set<Int> = []
    @State private var refreshTimer: Timer?
    @State private var pendingActivities: [PlayerActivity] = []
    @State private var isTrickling = false
    
    // Polling configuration
    private let pollInterval: TimeInterval = 8.0
    private let trickleDelay: TimeInterval = 0.8  // Delay between each flying icon
    private let maxFlyingIcons: Int = 6  // Don't show too many at once
    
    var body: some View {
        ZStack {
            // Flying icons layer (behind and around the marker)
            ForEach(flyingIcons) { iconData in
                FlyingActivityIcon(
                    icon: iconData.icon,
                    color: iconData.color,
                    angle: iconData.angle,
                    onComplete: {
                        removeIcon(id: iconData.id)
                    }
                )
            }
            
            // The actual kingdom marker
            KingdomMarker(
                kingdom: kingdom,
                homeKingdomId: homeKingdomId,
                playerId: playerId
            )
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    // MARK: - Polling
    
    private func startPolling() {
        // Initial fetch
        Task {
            await fetchAndProcessActivity()
        }
        
        // Periodic polling
        refreshTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task {
                await fetchAndProcessActivity()
            }
        }
    }
    
    private func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func fetchAndProcessActivity() async {
        do {
            let response = try await KingdomAPIService.shared.player.getPlayersInKingdom(kingdom.id, limit: 10)
            
            await MainActor.run {
                processNewActivity(players: response.players)
            }
        } catch {
            // Silently fail - no activity icons if we can't fetch
            // This is fine - the marker still shows normally
        }
    }
    
    // MARK: - Activity Processing
    
    private func processNewActivity(players: [PlayerInKingdom]) {
        let currentPlayerIds = Set(players.map(\.id))
        
        // Find new players (not seen before)
        let newPlayerIds = currentPlayerIds.subtracting(lastSeenPlayerIds)
        
        // Get activities from new players (filter out idle)
        let newActivities = players
            .filter { newPlayerIds.contains($0.id) && $0.activity.type != "idle" }
            .map(\.activity)
        
        // Queue up new activities for trickling
        if !newActivities.isEmpty {
            pendingActivities.append(contentsOf: newActivities)
            if !isTrickling {
                Task {
                    await trickleActivities()
                }
            }
        }
        
        // Update seen players
        lastSeenPlayerIds = currentPlayerIds
    }
    
    private func trickleActivities() async {
        await MainActor.run {
            isTrickling = true
        }
        
        while await hasPendingActivities() {
            guard let activity = await popNextActivity() else { break }
            
            // Don't spawn too many at once
            let currentCount = await flyingIconCount()
            if currentCount >= maxFlyingIcons {
                // Wait for some to clear
                try? await Task.sleep(nanoseconds: UInt64(trickleDelay * 1_000_000_000))
                continue
            }
            
            // Spawn the flying icon
            await MainActor.run {
                spawnFlyingIcon(for: activity)
            }
            
            // Wait before next one (the trickle effect!)
            try? await Task.sleep(nanoseconds: UInt64(trickleDelay * 1_000_000_000))
        }
        
        await MainActor.run {
            isTrickling = false
        }
    }
    
    @MainActor
    private func hasPendingActivities() -> Bool {
        !pendingActivities.isEmpty
    }
    
    @MainActor
    private func popNextActivity() -> PlayerActivity? {
        pendingActivities.isEmpty ? nil : pendingActivities.removeFirst()
    }
    
    @MainActor
    private func flyingIconCount() -> Int {
        flyingIcons.count
    }
    
    // MARK: - Flying Icon Management
    
    private func spawnFlyingIcon(for activity: PlayerActivity) {
        // Random angle for variety (full 360°)
        let angle = Double.random(in: 0..<360)
        
        let iconData = FlyingIconData(
            icon: activity.icon,
            color: ActionIconHelper.actionColor(for: activity.type),
            angle: angle
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            flyingIcons.append(iconData)
        }
    }
    
    private func removeIcon(id: UUID) {
        flyingIcons.removeAll { $0.id == id }
    }
}
