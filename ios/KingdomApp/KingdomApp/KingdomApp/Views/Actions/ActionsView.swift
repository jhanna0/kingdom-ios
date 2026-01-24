import SwiftUI

// MARK: - Actions View

struct ActionsView: View {
    @ObservedObject var viewModel: MapViewModel
    
    // MARK: - State Properties
    
    @State var actionStatus: AllActionStatus?
    @State var statusFetchedAt: Date?
    @State var isLoading = false
    @State var showError = false
    @State var errorMessage = ""
    @State var showActionResult = false
    @State var actionResultSuccess = true
    @State var actionResultTitle = ""
    @State var actionResultMessage = ""
    @State var showReward = false
    @State var currentReward: Reward?
    @State var currentTime = Date()
    @State var taskID = UUID()  // Persists across view recreations
    
    // Cache kingdom status to avoid recalculating on every render
    @State var isInHomeKingdom: Bool = false
    @State var isInEnemyKingdom: Bool = false
    @State var cachedKingdomId: String?
    
    // Battle state (dynamic - backend tells us what to do)
    @State var showBattleView = false
    @State var isInitiatingBattle = false
    @State var initiatedBattleId: Int?
    
    // Confirmation state for dangerous actions (coups/invasions)
    @State var showBattleConfirmation = false
    @State var pendingBattleAction: ActionStatus?
    
    // Alliance confirmation state
    @State var showAllianceConfirmation = false
    @State var pendingAllianceAction: ActionStatus?
    
    // Scout result popup state (slot machine style)
    @State var showScoutResult = false
    @State var scoutResultSuccess = false
    @State var scoutResultTitle = ""
    @State var scoutResultMessage = ""
    
    // MARK: - Computed Properties
    
    var currentKingdom: Kingdom? {
        guard let currentKingdomId = viewModel.player.currentKingdom else {
            return nil
        }
        
        // Search by ID (which is what player.currentKingdom should always be)
        return viewModel.kingdoms.first(where: { $0.id == currentKingdomId })
    }
    
    var availableContractsInKingdom: [Contract] {
        guard let kingdom = currentKingdom else { return [] }
        return viewModel.availableContracts.filter { $0.kingdomId == kingdom.id }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    headerSection
                    
                    if let status = actionStatus {
                        actionStatusContent(status: status)
                    }
                }
                .padding(.vertical)
            }
            .animation(nil)  // Disable all implicit animations on scroll content
        }
        .transaction { transaction in
            transaction.animation = nil  // Force disable animations on state updates
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task(id: taskID) {
            print("🎬 .task TRIGGERED in ActionsView (taskID: \(taskID))")
            await loadActionStatus()
            updateKingdomStatus()
            startUIUpdateTimer()
        }
        .onDisappear {
            stopUIUpdateTimer()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if showReward, let reward = currentReward {
                RewardDisplayView(reward: reward, isShowing: $showReward)
                    .transition(.opacity)
            }
            if showActionResult {
                ActionResultPopup(
                    success: actionResultSuccess,
                    title: actionResultTitle,
                    message: actionResultMessage,
                    isShowing: $showActionResult
                )
                .transition(.opacity)
            }
            if showScoutResult {
                ScoutResultPopup(
                    success: scoutResultSuccess,
                    title: scoutResultTitle,
                    message: scoutResultMessage,
                    isShowing: $showScoutResult
                )
                .transition(.opacity)
            }
            if showBattleConfirmation, let action = pendingBattleAction {
                BattleConfirmationPopup(
                    title: action.title ?? "Confirm Action",
                    isInvasion: action.endpoint?.contains("invasion") == true,
                    isShowing: $showBattleConfirmation,
                    onConfirm: {
                        executeBattleInitiation(action: action)
                        pendingBattleAction = nil
                    }
                )
                .transition(.opacity)
            }
            if showAllianceConfirmation, let action = pendingAllianceAction {
                AllianceConfirmationPopup(
                    targetKingdomName: action.kingdomName ?? currentKingdom?.name ?? "Unknown",
                    isShowing: $showAllianceConfirmation,
                    onConfirm: {
                        executeAllianceProposal(action: action)
                        pendingAllianceAction = nil
                    }
                )
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showBattleView) {
            if let battleId = initiatedBattleId {
                BattleView(battleId: battleId, onDismiss: {
                    showBattleView = false
                    // Refresh action status after battle view closes
                    Task {
                        await loadActionStatus(force: true)
                    }
                })
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActionsView(viewModel: MapViewModel())
    }
}
