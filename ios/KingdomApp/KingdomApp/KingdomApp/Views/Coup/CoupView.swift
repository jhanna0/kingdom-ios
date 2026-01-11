import SwiftUI
import Combine

/// Main container view for Coup V2
/// Full-screen game modal - no nav bar
struct CoupView: View {
    let coupId: Int
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = CoupViewModel()
    
    // Fight navigation state
    @State private var showFightView = false
    @State private var selectedTerritory: CoupTerritory?
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.coup == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.coup == nil {
                errorView(error: error)
            } else if let coup = viewModel.coup {
                phaseContent(coup: coup)
            }
        }
        .onAppear {
            viewModel.loadCoup(id: coupId)
        }
        .fullScreenCover(isPresented: $showFightView) {
            if let territory = selectedTerritory, let coup = viewModel.coup {
                CoupFightView(
                    territory: territory,
                    coup: coup,
                    onComplete: { result in
                        showFightView = false
                        selectedTerritory = nil
                        
                        // If fight was resolved, schedule cooldown notification and refresh
                        if let result = result {
                            viewModel.handleFightResolve(result: result)
                        } else {
                            // User cancelled or exited without resolving - still refresh
                            viewModel.refresh()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Phase Content
    
    @ViewBuilder
    private func phaseContent(coup: CoupEventResponse) -> some View {
        switch coup.status {
        case "pledge":
            CoupPledgeView(coup: coup, onDismiss: onDismiss) { side in
                viewModel.pledge(side: side)
            }
        case "battle":
            CoupBattleView(coup: coup, onDismiss: onDismiss) { territoryName in
                // Find the territory and navigate to fight view
                if let territory = coup.territories?.first(where: { $0.name == territoryName }) {
                    selectedTerritory = territory
                    showFightView = true
                }
            }
        case "resolved":
            resolvedView(coup: coup)
        default:
            Text("Unknown coup status")
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Resolved View
    
    private func resolvedView(coup: CoupEventResponse) -> some View {
        let rulerName = coup.rulerName ?? "The Crown"
        let challengerStats = coup.initiatorStats.map { FighterStats(from: $0) } ?? .empty
        let rulerStats = coup.rulerStats.map { FighterStats(from: $0) } ?? .empty
        let attackerWon = coup.attackerVictory == true
        let userWon: Bool? = {
            guard let side = coup.userSide else { return nil }
            if side == "attackers" { return attackerWon }
            return !attackerWon
        }()
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                CoupVsPosterView(
                    kingdomName: coup.kingdomName ?? "Kingdom",
                    challengerName: coup.initiatorName,
                    rulerName: rulerName,
                    attackerCount: coup.attackerCount,
                    defenderCount: coup.defenderCount,
                    timeRemaining: "FINISHED",
                    status: coup.status,
                    userSide: coup.userSide,
                    challengerStats: challengerStats,
                    rulerStats: rulerStats,
                    onDismiss: onDismiss
                )
                
                // Result card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: attackerWon ? "crown.fill" : "shield.lefthalf.filled")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .brutalistBadge(
                                backgroundColor: attackerWon ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.royalBlue,
                                cornerRadius: 12,
                                shadowOffset: 2,
                                borderWidth: 2
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attackerWon ? "COUP SUCCEEDED" : "COUP FAILED")
                                .font(.system(size: 16, weight: .black, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Text(attackerWon ? "\(coup.initiatorName) seized the throne!" : "The crown defended its rule.")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        Spacer()
                    }
                    
                    if let won = userWon {
                        let tint = won ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
                        HStack(spacing: 10) {
                            Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(tint)
                            
                            Text(won ? "Victory! You won." : "Defeat. You lost.")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                        }
                        .padding(12)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                    }
                }
                .padding(16)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            }
            .padding(.horizontal, KingdomTheme.Spacing.medium)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
    }
    
    // MARK: - Loading & Error
    
    private var loadingView: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            ProgressView()
                .tint(KingdomTheme.Colors.loadingTint)
            Text("Loading...")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.error)
            
            Text("Error")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(error)
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                viewModel.loadCoup(id: coupId)
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - ViewModel

@MainActor
class CoupViewModel: ObservableObject {
    @Published var coup: CoupEventResponse?
    @Published var isLoading = false
    @Published var error: String?
    
    private var coupId: Int?
    private var refreshTimer: Timer?
    
    func loadCoup(id: Int) {
        self.coupId = id
        isLoading = true
        error = nil
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/coups/\(id)",
                    method: "GET"
                )
                let response: CoupEventResponse = try await APIClient.shared.execute(request)
                self.coup = response
                self.isLoading = false
                
                // Start auto-refresh during battle phase
                if response.isBattlePhase {
                    startAutoRefresh()
                }
                
                // Schedule phase notifications if user has pledged
                if response.userSide != nil {
                    schedulePhaseNotifications(coup: response)
                }
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func refresh() {
        guard let id = coupId else { return }
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/coups/\(id)",
                    method: "GET"
                )
                let response: CoupEventResponse = try await APIClient.shared.execute(request)
                self.coup = response
            } catch {
                // Silent refresh failure
                print("Refresh failed: \(error)")
            }
        }
    }
    
    func pledge(side: String) {
        guard let id = coupId else { return }
        isLoading = true
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/coups/\(id)/join",
                    method: "POST",
                    body: ["side": side]
                )
                let _: CoupJoinResponse = try await APIClient.shared.execute(request)
                loadCoup(id: id)
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Handle fight resolution - schedule cooldown notification and refresh
    func handleFightResolve(result: FightResolveResponse) {
        // Schedule notification for when cooldown ends
        if result.cooldownSeconds > 0 {
            Task {
                await NotificationManager.shared.scheduleActionCooldownNotification(
                    actionName: "Coup Battle",
                    cooldownSeconds: result.cooldownSeconds,
                    slot: "coup_battle"
                )
            }
        }
        
        // Refresh coup data to get updated territories and cooldown
        refresh()
    }
    
    // MARK: - Notifications
    
    private func schedulePhaseNotifications(coup: CoupEventResponse) {
        let kingdomName = coup.kingdomName ?? "Kingdom"
        
        // Schedule pledge end notification (battle start)
        if coup.isPledgePhase {
            let formatter = ISO8601DateFormatter()
            if let pledgeEnd = formatter.date(from: coup.pledgeEndTime) {
                Task {
                    await NotificationManager.shared.scheduleCoupPhaseNotification(
                        coupId: coup.id,
                        phase: "pledge",
                        endDate: pledgeEnd,
                        kingdomName: kingdomName
                    )
                }
            }
        }
        
        // Schedule battle cooldown notification if user has one
        if coup.isBattlePhase, let cooldown = coup.battleCooldownSeconds, cooldown > 0 {
            Task {
                await NotificationManager.shared.scheduleActionCooldownNotification(
                    actionName: "Coup Battle",
                    cooldownSeconds: cooldown,
                    slot: "coup_battle"
                )
            }
        }
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
}

#Preview {
    CoupView(coupId: 1, onDismiss: {})
}
