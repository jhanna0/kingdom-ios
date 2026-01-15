import SwiftUI

struct HuntLeaderboardView: View {
    let kingdomId: String
    let kingdomName: String
    
    @State private var leaderboard: [HuntLeaderboardEntry] = []
    @State private var creatures: [String: CreatureInfo] = [:]
    @State private var isLoading = false
    @State private var error: String?
    
    // Creature order for consistent display
    private let creatureOrder = ["squirrel", "rabbit", "deer", "boar", "bear", "moose"]
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(KingdomTheme.Colors.inkMedium)
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text(error)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Button("Retry") {
                        Task { await loadLeaderboard() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if leaderboard.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Text("No hunters yet")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text("Complete hunts to appear on the leaderboard")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(leaderboard) { entry in
                            LeaderboardCard(entry: entry, creatures: creatures, creatureOrder: creatureOrder)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Hunt Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await KingdomAPIService.shared.hunts.getLeaderboard(kingdomId: kingdomId)
            leaderboard = response.leaderboard
            creatures = response.creatures
        } catch {
            self.error = "Failed to load leaderboard"
            leaderboard = []
        }
        
        isLoading = false
    }
}

// MARK: - Leaderboard Card

private struct LeaderboardCard: View {
    let entry: HuntLeaderboardEntry
    let creatures: [String: CreatureInfo]
    let creatureOrder: [String]
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return KingdomTheme.Colors.imperialGold
        case 2: return Color(red: 0.6, green: 0.6, blue: 0.65)
        case 3: return Color(red: 0.7, green: 0.45, blue: 0.2)
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Rank + Name + Hunts
            HStack(spacing: 12) {
                // Rank badge
                Text("\(entry.rank)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .brutalistBadge(
                        backgroundColor: entry.rank <= 3 ? rankColor : KingdomTheme.Colors.inkMedium,
                        cornerRadius: 16,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                // Name + Hunts
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .lineLimit(1)
                    
                    Text("\(entry.huntsCompleted) hunts")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            // Creature kills row
            if !entry.creatureKills.isEmpty {
                HStack(spacing: 8) {
                    ForEach(creatureOrder, id: \.self) { creatureId in
                        if let count = entry.creatureKills[creatureId], count > 0,
                           let creature = creatures[creatureId] {
                            CreatureKillBadge(icon: creature.icon, count: count)
                        }
                    }
                }
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
    }
}

// MARK: - Creature Kill Badge

private struct CreatureKillBadge: View {
    let icon: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 16))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(KingdomTheme.Colors.parchment)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        HuntLeaderboardView(kingdomId: "test", kingdomName: "Test Kingdom")
    }
}
