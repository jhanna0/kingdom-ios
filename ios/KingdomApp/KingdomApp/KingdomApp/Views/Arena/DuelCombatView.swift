import SwiftUI
import Combine

// MARK: - Duel Combat View
/// PvP duel combat screen (clean + minimal; no duplicate stat cards)
struct DuelCombatView: View {
    let match: DuelMatch
    let playerId: Int
    let onComplete: () -> Void

    @StateObject private var viewModel = DuelCombatViewModel()
    @State private var animatedBarValue: Double = 50
    @Environment(\.dismiss) private var dismiss

    private var currentMatch: DuelMatch { viewModel.match ?? match }

    private var isChallenger: Bool { currentMatch.challenger.id == playerId }

    private var me: DuelPlayer? { isChallenger ? currentMatch.challenger : currentMatch.opponent }
    private var opponent: DuelPlayer? { isChallenger ? currentMatch.opponent : currentMatch.challenger }

    private var myStats: DuelPlayerStats? { me?.stats }
    private var opponentStats: DuelPlayerStats? { opponent?.stats }

    private var opponentDisplayName: String {
        opponent?.name ?? (currentMatch.opponent == nil ? "Waiting..." : "Opponent")
    }
    
    private var myDisplayName: String {
        me?.name ?? "—"
    }

    /// Hit chance for display (prefer backend value after an attack; fall back to a simple estimate)
    private var hitChancePercent: Int {
        if let backend = viewModel.lastAction?.hitChance {
            return Int((backend * 100).rounded())
        }
        guard let attack = myStats?.attack, let defense = opponentStats?.defense else { return 50 }
        let chance = Double(attack + 1) / (Double(defense + 1) * 2.0)
        return Int(min(90, max(10, chance * 100)))
    }

    private var barValueForPlayer: Double {
        currentMatch.barForPlayer(playerId: playerId)
    }

    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Control bar (NOT wrapped in a card)
                        controlBar

                        // Status line(s)
                        statusLine

                        // Only show AFTER an attack
                        if let action = viewModel.lastAction {
                            RollResultDisplay(
                                outcome: CombatOutcome.from(action.outcome),
                                rollValue: Int(action.rollValue * 100),
                                message: nil,
                                pushAmount: action.pushAmount
                            )
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, KingdomTheme.Spacing.medium)
                }

                bottomActionBar
            }

            // Victory/Defeat overlay
            if currentMatch.isComplete, let winner = currentMatch.winner {
                resultOverlay(winner: winner)
            }
        }
        .navigationTitle("Duel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await viewModel.load(match: match, playerId: playerId)
            animatedBarValue = barValueForPlayer
        }
        .onChange(of: barValueForPlayer) { newValue in
            withAnimation(.easeInOut(duration: 0.45)) {
                animatedBarValue = newValue
            }
        }
    }

    // MARK: - Header (names + stats ONCE)

    private var header: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            playerHeaderCard(
                name: myDisplayName,
                stats: myStats,
                accent: KingdomTheme.Colors.royalBlue,
                isTurn: viewModel.isMyTurn && currentMatch.isFighting
            )

            Text("VS")
                .font(FontStyles.headingSmall)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.inkMedium,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )

            playerHeaderCard(
                name: opponentDisplayName,
                stats: opponentStats,
                accent: KingdomTheme.Colors.royalCrimson,
                isTurn: !viewModel.isMyTurn && currentMatch.isFighting
            )
        }
        .padding(KingdomTheme.Spacing.medium)
        .background(KingdomTheme.Colors.parchmentDark)
        .overlay(
            Rectangle()
                .fill(Color.black)
                .frame(height: 2),
            alignment: .bottom
        )
    }

    private func playerHeaderCard(name: String, stats: DuelPlayerStats?, accent: Color, isTurn: Bool) -> some View {
        let attackText = stats?.attackDisplayString
        let defenseText = stats?.defenseDisplayString

        return VStack(alignment: .leading, spacing: 6) {
            // Top row: name + turn pill (reserved space even when hidden)
            HStack(spacing: 8) {
                Text(name)
                    .font(FontStyles.bodySmallBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                turnPill
                    .opacity(isTurn ? 1 : 0)

                Spacer(minLength: 0)
            }

            // Two fixed stat rows so both cards stay the same height
            statRow(
                icon: "burst.fill",
                iconColor: KingdomTheme.Colors.buttonDanger,
                value: attackText
            )

            statRow(
                icon: "shield.fill",
                iconColor: KingdomTheme.Colors.royalBlue,
                value: defenseText
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.7), lineWidth: 2)
        )
        .frame(height: 86, alignment: .top)
    }

    private var turnPill: some View {
        Text("TURN")
            .font(FontStyles.labelTiny)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .brutalistBadge(
                backgroundColor: KingdomTheme.Colors.buttonSuccess,
                cornerRadius: 6,
                shadowOffset: 1,
                borderWidth: 1.5
            )
    }

    private func statRow(icon: String, iconColor: Color, value: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 14, alignment: .center)

            Text(value ?? "—")
                .font(FontStyles.labelSmall)
                .foregroundColor(value == nil ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkDark)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .frame(height: 16, alignment: .leading)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        SimpleCombatBar(
            value: animatedBarValue,
            leftLabel: myDisplayName,
            rightLabel: opponentDisplayName,
            leftColor: KingdomTheme.Colors.royalBlue,
            rightColor: KingdomTheme.Colors.royalCrimson
        )
        .padding(.horizontal)
    }

    // MARK: - Status Line

    private var statusLine: some View {
        VStack(spacing: 6) {
            if currentMatch.isWaiting {
                HStack(spacing: 8) {
                    Text("Match code:")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text(currentMatch.matchCode)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)

                    Button {
                        UIPasteboard.general.string = currentMatch.matchCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                Text("Waiting for an opponent to join…")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if currentMatch.isPendingAcceptance {
                Text(isChallenger ? "Opponent joined. Accept or decline below." : "Waiting for challenger to accept…")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if currentMatch.isReady {
                Text("Both fighters are ready. Start the duel below.")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if currentMatch.isFighting {
                Text(viewModel.isMyTurn ? "Your turn." : "Opponent’s turn…")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if currentMatch.isComplete {
                Text("Duel complete.")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = viewModel.errorMessage, !error.isEmpty {
                Text(error)
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)

            Group {
                if currentMatch.isWaiting {
                    HStack {
                        ProgressView()
                            .tint(KingdomTheme.Colors.inkMedium)
                        Text("Waiting for opponent…")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Spacer()
                        Button("Cancel") {
                            Task {
                                await viewModel.cancel()
                                dismiss()
                            }
                        }
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                } else if currentMatch.isPendingAcceptance {
                    pendingAcceptanceActions
                } else if currentMatch.isReady {
                    Button {
                        Task { await viewModel.startMatch() }
                    } label: {
                        HStack {
                            Image(systemName: "figure.fencing")
                            Text("Start Duel")
                                .font(FontStyles.bodySmallBold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                } else if currentMatch.isFighting {
                    attackButton
                } else if currentMatch.isComplete {
                    Button {
                        onComplete()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("Return to Arena")
                                .font(FontStyles.bodySmallBold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
                }
            }
            .padding(KingdomTheme.Spacing.medium)
            .background(KingdomTheme.Colors.parchmentDark)
        }
    }

    @ViewBuilder
    private var pendingAcceptanceActions: some View {
        if isChallenger {
            VStack(spacing: KingdomTheme.Spacing.small) {
                Text("Opponent wants to duel.")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)

                HStack(spacing: KingdomTheme.Spacing.medium) {
                    Button {
                        Task {
                            await viewModel.declineOpponent()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Decline")
                                .font(FontStyles.bodySmallBold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonDanger, fullWidth: true))

                    Button {
                        Task { await viewModel.confirmOpponent() }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                                .font(FontStyles.bodySmallBold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                }
            }
        } else {
            HStack {
                ProgressView()
                    .tint(KingdomTheme.Colors.inkMedium)
                Text("Waiting for challenger to accept…")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
            }
        }
    }

    private var attackButton: some View {
        Button {
            Task { await viewModel.attack() }
        } label: {
            VStack(spacing: 4) {
                HStack {
                    if viewModel.isAttacking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "figure.fencing")
                        Text(viewModel.isMyTurn ? "ATTACK!" : "Opponent’s Turn")
                            .font(FontStyles.headingSmall)
                    }
                }

                if viewModel.isMyTurn {
                    Text("\(hitChancePercent)% hit chance")
                        .font(FontStyles.labelTiny)
                        .opacity(0.85)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.isMyTurn ? KingdomTheme.Colors.royalCrimson : KingdomTheme.Colors.disabled)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
        .disabled(!viewModel.isMyTurn || viewModel.isAttacking)
    }

    // MARK: - Result Overlay

    private func resultOverlay(winner: DuelWinner) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: KingdomTheme.Spacing.large) {
                let didWin = winner.id == playerId

                Image(systemName: didWin ? "trophy.fill" : "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(didWin ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.buttonDanger)

                Text(didWin ? "VICTORY!" : "DEFEAT")
                    .font(FontStyles.displayLarge)
                    .foregroundColor(didWin ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.buttonDanger)

                if let gold = winner.goldEarned, gold > 0, didWin {
                    HStack {
                        Image(systemName: "bitcoinsign.circle.fill")
                        Text("+\(gold) gold")
                    }
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                }

                Button {
                    onComplete()
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.circle.fill")
                        Text("Return to Arena")
                            .font(FontStyles.bodySmallBold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.brutalist(
                    backgroundColor: didWin ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonPrimary,
                    fullWidth: true
                ))
                .padding(.horizontal, 40)
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 20)
            .padding(24)
        }
    }
}

// MARK: - Duel Combat ViewModel

@MainActor
class DuelCombatViewModel: ObservableObject {
    @Published var match: DuelMatch?
    @Published var lastAction: DuelActionResult?
    @Published var rollHistory: [RollHistoryItem] = []
    @Published var isAttacking = false
    @Published var errorMessage: String?
    
    private let api = DuelsAPI()
    private var matchId: Int?
    private var playerId: Int?
    private var pollTimer: Timer?
    
    var isMyTurn: Bool {
        guard let match = match, let playerId = playerId else { return false }
        return match.isPlayersTurn(playerId: playerId)
    }
    
    func load(match: DuelMatch, playerId: Int) async {
        self.match = match
        self.matchId = match.id
        self.playerId = playerId
        
        await refresh()
        startPolling()
    }
    
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.match?.isActive == true else {
                    self?.stopPolling()
                    return
                }
                await self.refresh()
            }
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func refresh() async {
        guard let matchId = matchId else { return }
        do {
            let response = try await api.getMatch(matchId: matchId)
            if let newMatch = response.match {
                match = newMatch
                if newMatch.isComplete { stopPolling() }
            }
        } catch {
            print("Failed to refresh: \(error)")
        }
    }
    
    func confirmOpponent() async {
        guard let matchId = matchId else { return }
        do {
            let response = try await api.confirmOpponent(matchId: matchId)
            if response.success { match = response.match }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func declineOpponent() async {
        guard let matchId = matchId else { return }
        do {
            let response = try await api.declineOpponent(matchId: matchId)
            if response.success {
                match = response.match
                stopPolling()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func startMatch() async {
        guard let matchId = matchId else { return }
        do {
            let response = try await api.startMatch(matchId: matchId)
            if response.success { match = response.match }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func attack() async {
        guard let matchId = matchId else { return }
        isAttacking = true
        defer { isAttacking = false }
        
        do {
            let response = try await api.attack(matchId: matchId)
            if response.success {
                lastAction = response.action
                if let action = response.action {
                    rollHistory.append(RollHistoryItem(
                        outcome: CombatOutcome.from(action.outcome),
                        rollValue: Int(action.rollValue * 100),
                        isSuccess: action.outcome != "miss"
                    ))
                }
                match = response.match
                if match?.isComplete == true { stopPolling() }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func cancel() async {
        guard let matchId = matchId else { return }
        do {
            _ = try await api.cancel(matchId: matchId)
            stopPolling()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    deinit {
        pollTimer?.invalidate()
    }
}
