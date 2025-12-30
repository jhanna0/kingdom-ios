import SwiftUI

/// Shows live player activity feed in a kingdom
struct PlayerActivityFeedCard: View {
    let kingdomId: String
    
    @State private var playersData: PlayersInKingdomResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Player Activity")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if let data = playersData {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("\(data.online_count) online")
                            .font(.caption)
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
                        .font(.system(size: 40))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("Intelligence Required")
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(error)
                        .font(.caption)
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
                                .font(.title3)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            Text("No players in this kingdom")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    // Show up to 5 most recent/relevant players
                    VStack(spacing: 8) {
                        ForEach(Array(data.players.prefix(5))) { playerData in
                            NavigationLink(destination: PlayerProfileView(userId: playerData.id)) {
                                PlayerActivityRow(playerData: playerData)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if data.players.count > 5 {
                            Text("+\(data.players.count - 5) more players")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
        .task {
            await loadPlayers()
        }
    }
    
    private func loadPlayers() async {
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
                errorMessage = "Failed to load players"
                isLoading = false
            }
        }
    }
}

// MARK: - Player Activity Row

struct PlayerActivityRow: View {
    let playerData: PlayerInKingdom
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(playerData.is_ruler ? KingdomTheme.Colors.gold.opacity(0.3) : KingdomTheme.Colors.inkDark.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(playerData.display_name.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                            .foregroundColor(playerData.is_ruler ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark)
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
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .lineLimit(1)
                    
                    if playerData.is_ruler {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                
                // Activity with icon
                HStack(spacing: 4) {
                    Image(systemName: playerData.activity.icon)
                        .font(.caption2)
                        .foregroundColor(activityColor(playerData.activity.color))
                    
                    Text(playerData.activity.displayText)
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Level badge
            Text("L\(playerData.level)")
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(KingdomTheme.Colors.inkDark.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(KingdomTheme.Colors.parchment.opacity(0.5))
        .cornerRadius(8)
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

