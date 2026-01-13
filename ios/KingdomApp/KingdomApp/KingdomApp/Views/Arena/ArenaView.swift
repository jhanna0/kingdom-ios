import SwiftUI

/// Main arena view for PvP duels
struct ArenaView: View {
    let kingdomId: String
    let kingdomName: String
    let playerId: Int
    
    @StateObject private var viewModel = ArenaViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Header
                arenaHeader
                
                // Active Match Banner (if any)
                if let match = viewModel.activeMatch {
                    activeMatchBanner(match)
                }
                
                // Pending Invitations
                if !viewModel.invitations.isEmpty {
                    invitationsSection
                }
                
                // Actions
                actionsSection
                
                // My Stats
                statsSection
                
                // Leaderboard
                leaderboardSection
                
                // Recent Matches
                recentMatchesSection
                
                Spacer(minLength: 40)
            }
            .padding(.top)
            .padding(.horizontal)
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("PvP Arena")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .refreshable {
            await viewModel.refresh(kingdomId: kingdomId)
        }
        .task {
            await viewModel.load(kingdomId: kingdomId)
        }
    }
    
    // MARK: - Header
    
    private var arenaHeader: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "figure.fencing")
                .font(FontStyles.iconExtraLarge)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalCrimson, cornerRadius: 14, shadowOffset: 4, borderWidth: 3)
            
            Text("PvP Arena")
                .font(FontStyles.displayMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Challenge friends to 1v1 combat")
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.bottom, KingdomTheme.Spacing.small)
    }
    
    // MARK: - Active Match Banner
    
    private func activeMatchBanner(_ match: DuelMatch) -> some View {
        NavigationLink {
            DuelCombatView(match: match, playerId: playerId, onComplete: {
                Task { await viewModel.refresh(kingdomId: kingdomId) }
            })
        } label: {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon
                Image(systemName: match.isFighting ? "bolt.fill" : "hourglass")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(
                        backgroundColor: match.isPendingAcceptance ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.royalCrimson,
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(match.statusText)
                            .font(FontStyles.headingSmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if match.isFighting {
                            Circle()
                                .fill(KingdomTheme.Colors.buttonSuccess)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    if let opponent = match.opponent {
                        Text("vs \(opponent.name ?? "???")")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else {
                        Text("Waiting for opponent...")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
                
                // Action hint
                if match.isPendingAcceptance && match.challenger.id == playerId {
                    Text("Review")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.buttonWarning,
                            cornerRadius: 6,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        }
    }
    
    // MARK: - Invitations
    
    private var invitationsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Duel Invitations")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            ForEach(viewModel.invitations) { invitation in
                InvitationCard(invitation: invitation, viewModel: viewModel, playerId: playerId)
            }
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        VStack(spacing: KingdomTheme.Spacing.small) {
            // Create New Duel
            NavigationLink {
                CreateDuelView(kingdomId: kingdomId, playerId: playerId, viewModel: viewModel)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Duel")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(FontStyles.bodySmall)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(KingdomTheme.Colors.buttonSuccess)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
            }
            .disabled(viewModel.activeMatch != nil)
            .opacity(viewModel.activeMatch != nil ? 0.5 : 1)
            
            // Join by Code
            NavigationLink {
                JoinByCodeView(viewModel: viewModel, playerId: playerId)
            } label: {
                HStack {
                    Image(systemName: "ticket.fill")
                    Text("Join by Code")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding()
                .frame(maxWidth: .infinity)
                .background(KingdomTheme.Colors.parchmentLight)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.5))
            }
            .disabled(viewModel.activeMatch != nil)
            .opacity(viewModel.activeMatch != nil ? 0.5 : 1)
        }
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Your Record")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if let stats = viewModel.myStats {
                HStack(spacing: KingdomTheme.Spacing.small) {
                    StatBox(value: "\(stats.wins)", label: "Wins", color: KingdomTheme.Colors.buttonSuccess)
                    StatBox(value: "\(stats.losses)", label: "Losses", color: KingdomTheme.Colors.buttonDanger)
                    StatBox(value: "\(stats.winRatePercent)%", label: "Win Rate", color: KingdomTheme.Colors.royalBlue)
                    StatBox(value: "\(stats.winStreak)", label: "Streak", color: KingdomTheme.Colors.buttonWarning)
                }
            } else {
                Text("No duels yet - be the first!")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
            }
        }
    }
    
    // MARK: - Leaderboard
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Top Duelists")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(spacing: 0) {
                if viewModel.leaderboard.isEmpty {
                    Text("No one has dueled yet!")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(rank: index + 1, entry: entry, isCurrentPlayer: entry.userId == playerId)
                        
                        if index < viewModel.leaderboard.count - 1 {
                            Divider()
                                .background(KingdomTheme.Colors.border)
                        }
                    }
                }
            }
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
        }
    }
    
    // MARK: - Recent Matches
    
    private var recentMatchesSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Recent Matches")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(spacing: 0) {
                if viewModel.recentMatches.isEmpty {
                    Text("No recent matches in this arena")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    ForEach(Array(viewModel.recentMatches.prefix(5).enumerated()), id: \.element.id) { index, match in
                        RecentMatchRow(match: match, playerId: playerId)
                        
                        if index < min(viewModel.recentMatches.count, 5) - 1 {
                            Divider()
                                .background(KingdomTheme.Colors.border)
                        }
                    }
                }
            }
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
        }
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FontStyles.headingMedium)
                .foregroundColor(color)
            Text(label)
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
    }
}

struct InvitationCard: View {
    let invitation: DuelInvitation
    let viewModel: ArenaViewModel
    let playerId: Int
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Challenger icon
            Image(systemName: "figure.fencing")
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonWarning,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(invitation.inviterName)")
                    .font(FontStyles.bodySmallBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("challenges you to a duel!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                if invitation.wagerGold > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "g.circle.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        Text("\(invitation.wagerGold) gold wager")
                            .font(FontStyles.labelTiny)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 6) {
                Button {
                    Task {
                        await viewModel.acceptInvitation(invitation.invitationId, playerId: playerId)
                    }
                } label: {
                    Text("Accept")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    cornerRadius: 6,
                    shadowOffset: 1,
                    borderWidth: 1.5
                )
                
                Button {
                    Task {
                        await viewModel.declineInvitation(invitation.invitationId)
                    }
                } label: {
                    Text("Decline")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: DuelLeaderboardEntry
    let isCurrentPlayer: Bool
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            // Rank badge
            Text("#\(rank)")
                .font(FontStyles.labelBold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(rankColor)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
            
            Text(entry.displayName)
                .font(FontStyles.bodySmall)
                .foregroundColor(isCurrentPlayer ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkDark)
                .fontWeight(isCurrentPlayer ? .bold : .regular)
            
            Spacer()
            
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text("\(entry.wins)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    Text("W")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                HStack(spacing: 2) {
                    Text("\(entry.losses)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("L")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(.horizontal, KingdomTheme.Spacing.medium)
        .padding(.vertical, KingdomTheme.Spacing.small)
        .background(isCurrentPlayer ? KingdomTheme.Colors.royalBlue.opacity(0.1) : Color.clear)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return KingdomTheme.Colors.imperialGold
        case 2: return Color(red: 0.6, green: 0.6, blue: 0.65) // Silver
        case 3: return Color(red: 0.7, green: 0.45, blue: 0.2) // Bronze
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

struct RecentMatchRow: View {
    let match: DuelMatch
    let playerId: Int
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            // Challenger
            Text(match.challenger.name ?? "???")
                .font(FontStyles.bodySmall)
                .foregroundColor(match.challenger.id == playerId ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkDark)
                .fontWeight(match.challenger.id == playerId ? .bold : .regular)
                .lineLimit(1)
            
            Text("vs")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            // Opponent
            Text(match.opponent?.name ?? "???")
                .font(FontStyles.bodySmall)
                .foregroundColor(match.opponent?.id == playerId ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkDark)
                .fontWeight(match.opponent?.id == playerId ? .bold : .regular)
                .lineLimit(1)
            
            Spacer()
            
            // Result badge
            if let winner = match.winner {
                let didWin = winner.id == playerId
                let wasInMatch = match.challenger.id == playerId || match.opponent?.id == playerId
                
                if wasInMatch {
                    Text(didWin ? "Won" : "Lost")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brutalistBadge(
                            backgroundColor: didWin ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger,
                            cornerRadius: 4,
                            shadowOffset: 1,
                            borderWidth: 1
                        )
                } else {
                    // Show winner's name based on side
                    let winnerName = winner.side == "challenger" ? match.challenger.name : match.opponent?.name
                    Text(winnerName ?? "Winner")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            } else {
                Text("In Progress")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
            }
        }
        .padding(.horizontal, KingdomTheme.Spacing.medium)
        .padding(.vertical, KingdomTheme.Spacing.small)
    }
}

// MARK: - Create Duel View

struct CreateDuelView: View {
    let kingdomId: String
    let playerId: Int
    @ObservedObject var viewModel: ArenaViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var wagerGold = 0
    @State private var isCreating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                Spacer().frame(height: 20)
                
                Image(systemName: "figure.fencing")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalCrimson, cornerRadius: 16, shadowOffset: 4, borderWidth: 3)
                
                Text("Create a Duel")
                    .font(FontStyles.displayMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Challenge your friends to battle!")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Wager (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gold Wager (Optional)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack {
                        TextField("0", value: $wagerGold, format: .number)
                            .keyboardType(.numberPad)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .padding(12)
                            .background(KingdomTheme.Colors.parchmentLight)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KingdomTheme.Colors.border, lineWidth: 1.5))
                        
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                
                Spacer().frame(height: 40)
                
                Button {
                    Task {
                        isCreating = true
                        if let _ = await viewModel.createDuel(kingdomId: kingdomId, wagerGold: wagerGold) {
                            dismiss()
                        }
                        isCreating = false
                    }
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Duel")
                                .font(FontStyles.bodySmallBold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                .disabled(isCreating)
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("New Duel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - Join By Code View

struct JoinByCodeView: View {
    @ObservedObject var viewModel: ArenaViewModel
    let playerId: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var code = ""
    @State private var isLookingUp = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var foundMatch: DuelMatch?
    
    private let api = DuelsAPI()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                Spacer().frame(height: 20)
                
                Image(systemName: "ticket.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalBlue, cornerRadius: 16, shadowOffset: 4, borderWidth: 3)
                
                Text("Join by Code")
                    .font(FontStyles.displayMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Enter the 6-character match code")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Code input card
                VStack(spacing: 12) {
                    TextField("ABC123", text: $code)
                        .textInputAutocapitalization(.characters)
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .background(KingdomTheme.Colors.parchmentLight)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(KingdomTheme.Colors.border, lineWidth: 2))
                        .onChange(of: code) { _ in
                            // Clear found match when code changes
                            foundMatch = nil
                            errorMessage = nil
                        }
                    
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text(error)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        }
                    }
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
                
                // Found match details
                if let match = foundMatch {
                    matchDetailsCard(match: match)
                }
                
                Spacer().frame(height: 20)
                
                // Action button
                if foundMatch == nil {
                    // Lookup button
                    Button {
                        Task { await lookupMatch() }
                    } label: {
                        HStack {
                            if isLookingUp {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Find Match")
                                    .font(FontStyles.bodySmallBold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: code.count >= 6 ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled, fullWidth: true))
                    .disabled(code.count < 6 || isLookingUp)
                } else {
                    // Join button
                    Button {
                        Task { await joinMatch() }
                    } label: {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "figure.fencing")
                                Text("Accept & Join Duel")
                                    .font(FontStyles.bodySmallBold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                    .disabled(isJoining)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Join Duel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
    
    // Match details card showing challenger and wager
    private func matchDetailsCard(match: DuelMatch) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                Text("MATCH FOUND")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    .tracking(1)
            }
            
            // Challenger info
            VStack(spacing: 4) {
                Text("Challenger")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text(match.challenger.name ?? "Unknown")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let stats = match.challenger.stats {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "burst.fill")
                                .font(.system(size: 10))
                            Text("\(stats.attack)")
                        }
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 10))
                            Text("\(stats.defense)")
                        }
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    }
                    .font(FontStyles.labelSmall)
                }
            }
            
            // Wager
            if match.wagerGold > 0 {
                Divider()
                
                VStack(spacing: 4) {
                    Text("GOLD WAGER")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .tracking(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        Text("\(match.wagerGold)")
                            .font(FontStyles.headingLarge)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                    }
                    
                    Text("You must match this wager to join")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(KingdomTheme.Spacing.large)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    private func lookupMatch() async {
        isLookingUp = true
        errorMessage = nil
        
        do {
            let response = try await api.getMatchByCode(code)
            if let match = response.match {
                if match.canJoin {
                    foundMatch = match
                } else {
                    errorMessage = "This match is no longer available"
                }
            } else {
                errorMessage = "Match not found. Check the code."
            }
        } catch {
            errorMessage = "Could not find match. Check the code."
        }
        
        isLookingUp = false
    }
    
    private func joinMatch() async {
        isJoining = true
        errorMessage = nil
        
        if let _ = await viewModel.joinByCode(code, playerId: playerId) {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Could not join. You may not have enough gold."
        }
        
        isJoining = false
    }
}
