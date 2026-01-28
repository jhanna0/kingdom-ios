import SwiftUI
import Combine

/// Main container view for Battles (Coups & Invasions)
/// Full-screen game modal - no nav bar
struct BattleView: View {
    let battleId: Int
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = BattleViewModel()
    
    // Fight navigation state
    @State private var showFightView = false
    @State private var selectedTerritory: BattleTerritory?
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.battle == nil {
                loadingView
            } else if let error = viewModel.error, viewModel.battle == nil {
                errorView(error: error)
            } else if let battle = viewModel.battle {
                phaseContent(battle: battle)
            }
        }
        .onAppear {
            viewModel.loadBattle(id: battleId)
        }
        .fullScreenCover(isPresented: $showFightView) {
            if let territory = selectedTerritory, let battle = viewModel.battle {
                BattleFightView(
                    territory: territory,
                    battle: battle,
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
    private func phaseContent(battle: BattleEventResponse) -> some View {
        // Show pledge view during pledge phase OR if user can still join during battle phase
        if battle.status == "pledge" || (battle.userSide == nil && battle.canJoin) {
            BattlePledgeView(battle: battle, onDismiss: onDismiss) { side in
                viewModel.pledge(side: side)
            }
        } else if battle.status == "battle" {
            BattlePhaseView(battle: battle, onDismiss: onDismiss) { territoryName in
                // Find the territory and navigate to fight view
                if let territory = battle.territories?.first(where: { $0.name == territoryName }) {
                    selectedTerritory = territory
                    showFightView = true
                }
            }
        } else if battle.status == "resolved" {
            resolvedView(battle: battle)
        } else {
            Text("Unknown battle status")
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Resolved View
    
    private func resolvedView(battle: BattleEventResponse) -> some View {
        let rulerName = battle.rulerName ?? "The Crown"
        let challengerStats = battle.initiatorStats.map { FighterStats(from: $0) } ?? .empty
        let rulerStats = battle.rulerStats.map { FighterStats(from: $0) } ?? .empty
        let attackerWon = battle.attackerVictory == true
        let userWon: Bool? = {
            guard let side = battle.userSide else { return nil }
            if side == "attackers" { return attackerWon }
            return !attackerWon
        }()
        
        // Battle-type aware text
        let battleTypeName = battle.isCoup ? "COUP" : "INVASION"
        let successMessage = battle.isCoup
            ? "\(battle.initiatorName) seized the throne!"
            : "\(battle.initiatorName) conquered \(battle.kingdomName ?? "the kingdom")!"
        let failureMessage = battle.isCoup
            ? "The crown defended its rule."
            : "The defenders repelled the invasion."
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                BattleVsPosterView(
                    battle: battle,
                    timeRemaining: "FINISHED",
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
                            Text(attackerWon ? "\(battleTypeName) SUCCEEDED" : "\(battleTypeName) FAILED")
                                .font(.system(size: 16, weight: .black, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Text(attackerWon ? successMessage : failureMessage)
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
                    
                    // Show wall damage for invasions
                    if battle.isInvasion, let wallDefense = battle.wallDefenseApplied, wallDefense > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.fill")
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Text("Wall defense contributed +\(wallDefense) to defenders")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
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
                viewModel.loadBattle(id: battleId)
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Backwards Compatible Alias
typealias CoupView = BattleView

// MARK: - ViewModel

@MainActor
class BattleViewModel: ObservableObject {
    @Published var battle: BattleEventResponse?
    @Published var isLoading = false
    @Published var error: String?
    
    private var battleId: Int?
    
    func loadBattle(id: Int) {
        self.battleId = id
        isLoading = true
        error = nil
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/battles/\(id)",
                    method: "GET"
                )
                let response: BattleEventResponse = try await APIClient.shared.execute(request)
                self.battle = response
                self.isLoading = false
                
                // Schedule phase notifications if user has pledged
                if response.userSide != nil {
                    schedulePhaseNotifications(battle: response)
                }
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func refresh() {
        guard let id = battleId else { return }
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/battles/\(id)",
                    method: "GET"
                )
                let response: BattleEventResponse = try await APIClient.shared.execute(request)
                self.battle = response
            } catch {
                // Silent refresh failure
                print("Refresh failed: \(error)")
            }
        }
    }
    
    func pledge(side: String) {
        guard let id = battleId else { return }
        isLoading = true
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/battles/\(id)/join",
                    method: "POST",
                    body: ["side": side]
                )
                let _: BattleJoinResponse = try await APIClient.shared.execute(request)
                loadBattle(id: id)
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Handle fight resolution - schedule cooldown notification and refresh
    func handleFightResolve(result: FightResolveResponse) {
        let battleTypeName = battle?.isCoup == true ? "Coup" : "Invasion"
        
        // Schedule notification for when cooldown ends
        // InAppNotificationManager intercepts these when app is in foreground
        if result.cooldownSeconds > 0 {
            Task {
                await NotificationManager.shared.scheduleActionCooldownNotification(
                    actionName: "\(battleTypeName) Battle",
                    cooldownSeconds: result.cooldownSeconds,
                    slot: "battle"
                )
            }
        }
        
        // Refresh battle data to get updated territories and cooldown
        refresh()
    }
    
    // MARK: - Notifications
    
    private func schedulePhaseNotifications(battle: BattleEventResponse) {
        let kingdomName = battle.kingdomName ?? "Kingdom"
        let battleTypeName = battle.isCoup ? "Coup" : "Invasion"
        
        // Schedule pledge end notification (battle start)
        if battle.isPledgePhase {
            let formatter = ISO8601DateFormatter()
            if let pledgeEnd = formatter.date(from: battle.pledgeEndTime) {
                Task {
                    await NotificationManager.shared.scheduleCoupPhaseNotification(
                        coupId: battle.id,
                        phase: "pledge",
                        endDate: pledgeEnd,
                        kingdomName: "\(battleTypeName) in \(kingdomName)"
                    )
                }
            }
        }
        
        // Schedule battle cooldown notification if user has one
        // InAppNotificationManager intercepts these when app is in foreground
        if battle.isBattlePhase, let cooldown = battle.battleCooldownSeconds, cooldown > 0 {
            Task {
                await NotificationManager.shared.scheduleActionCooldownNotification(
                    actionName: "\(battleTypeName) Battle",
                    cooldownSeconds: cooldown,
                    slot: "battle"
                )
            }
        }
    }
    
}

// Backwards compatible alias
typealias CoupViewModel = BattleViewModel

#Preview {
    BattleView(battleId: 1, onDismiss: {})
}
