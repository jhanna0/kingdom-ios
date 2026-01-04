import SwiftUI

/// View showing all players in the current kingdom
struct PlayersListView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
    @State private var playersData: PlayersInKingdomResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPlayer: PlayerInKingdom?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading players...")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .padding(.top, 8)
                }
            } else if let error = errorMessage {
                errorView(error)
            } else if let data = playersData {
                playersContent(data)
            }
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await loadPlayers()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
        }
        .sheet(item: $selectedPlayer) { playerData in
            NavigationStack {
                PlayerProfileView(userId: playerData.id)
            }
        }
        .task {
            await loadPlayers()
        }
    }
    
    private func playersContent(_ data: PlayersInKingdomResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Kingdom header
                kingdomHeaderCard(data)
                
                // Players list
                VStack(spacing: 12) {
                    ForEach(data.players) { playerData in
                        PlayerRowCard(playerData: playerData)
                            .onTapGesture {
                                selectedPlayer = playerData
                            }
                    }
                }
            }
            .padding()
        }
    }
    
    private func kingdomHeaderCard(_ data: PlayersInKingdomResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text(data.kingdom_name)
                    .font(.title2.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Players")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    Text("\(data.total_players)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                    
                    Text("\(data.online_count)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("Failed to load players")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(error)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadPlayers()
                }
            }
            .font(KingdomTheme.Typography.body())
            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
        }
        .padding()
    }
    
    private func loadPlayers() async {
        guard let kingdomId = player.currentKingdom else {
            await MainActor.run {
                errorMessage = "You must be in a kingdom to see players"
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data = try await KingdomAPIService.shared.player.getPlayersInKingdom(kingdomId)
            
            await MainActor.run {
                self.playersData = data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Player Row Card

struct PlayerRowCard: View {
    let playerData: PlayerInKingdom
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar or icon
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(KingdomTheme.Colors.inkMedium.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(playerData.display_name.prefix(1)).uppercased())
                            .font(.title3.bold())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    )
                
                // Online indicator
                Circle()
                    .fill(playerData.is_online ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(KingdomTheme.Colors.parchmentLight, lineWidth: 2)
                    )
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(playerData.display_name)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if playerData.is_ruler {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                HStack(spacing: 8) {
                    // Level
                    Text("Lv\(playerData.level)")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                    
                    // Activity
                    HStack(spacing: 4) {
                        Image(systemName: playerData.activity.icon)
                            .font(.caption2)
                            .foregroundColor(playerData.activity.actualColor)
                        
                        Text(playerData.activity.displayText)
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Stats preview
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text("\(playerData.attack_power)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.caption2)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text("\(playerData.defense_power)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 1)
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
    NavigationStack {
        PlayersListView(player: {
            let p = Player(name: "Test")
            p.currentKingdom = "test-kingdom"
            return p
        }())
    }
}

