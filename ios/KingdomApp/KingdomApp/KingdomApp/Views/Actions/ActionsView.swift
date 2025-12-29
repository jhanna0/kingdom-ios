import SwiftUI

struct ActionsView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var actionStatus: AllActionStatus?
    @State private var statusFetchedAt: Date?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showReward = false
    @State private var currentReward: Reward?
    @State private var currentTime = Date()
    
    var currentKingdom: Kingdom? {
        guard let currentKingdomName = viewModel.player.currentKingdom else { return nil }
        return viewModel.kingdoms.first { $0.name == currentKingdomName }
    }
    
    var activeContract: Contract? {
        guard let contractId = viewModel.player.activeContractId else { return nil }
        return viewModel.availableContracts.first { $0.id == contractId }
    }
    
    var isInHomeKingdom: Bool {
        guard let kingdom = currentKingdom else { return false }
        return viewModel.isHomeKingdom(kingdom)
    }
    
    var isInEnemyKingdom: Bool {
        guard let kingdom = currentKingdom else { return false }
        return !viewModel.isHomeKingdom(kingdom)
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            if isLoading && actionStatus == nil {
                MedievalLoadingView(status: "Loading actions...")
            } else {
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Header
                        VStack(spacing: KingdomTheme.Spacing.medium) {
                            // Title
                            HStack {
                                Image(systemName: "figure.walk")
                                    .font(.title2)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                
                                Text("Available Actions")
                                    .font(KingdomTheme.Typography.title2())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                Spacer()
                            }
                            
                            // Kingdom Context Card
                            if let kingdom = currentKingdom {
                                HStack(spacing: KingdomTheme.Spacing.medium) {
                                    // Icon based on kingdom type
                                    Image(systemName: isInHomeKingdom ? "crown.fill" : "shield.fill")
                                        .font(.title3)
                                        .foregroundColor(isInHomeKingdom ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
                                        .frame(width: 40, height: 40)
                                        .background(isInHomeKingdom ? KingdomTheme.Colors.gold.opacity(0.1) : KingdomTheme.Colors.buttonDanger.opacity(0.1))
                                        .cornerRadius(KingdomTheme.CornerRadius.medium)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(kingdom.name)
                                            .font(KingdomTheme.Typography.headline())
                                            .foregroundColor(KingdomTheme.Colors.inkDark)
                                        
                                        Text(isInHomeKingdom ? "Your Kingdom" : "Enemy Territory")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(isInHomeKingdom ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(KingdomTheme.Spacing.medium)
                                .parchmentCard(
                                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                                    hasShadow: false
                                )
                            } else {
                                HStack(spacing: KingdomTheme.Spacing.medium) {
                                    Image(systemName: "map")
                                        .font(.title3)
                                        .foregroundColor(KingdomTheme.Colors.textMuted)
                                        .frame(width: 40, height: 40)
                                        .background(KingdomTheme.Colors.disabled.opacity(0.1))
                                        .cornerRadius(KingdomTheme.CornerRadius.medium)
                                    
                                    Text("Enter a kingdom to perform actions")
                                        .font(KingdomTheme.Typography.body())
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    
                                    Spacer()
                                }
                                .padding(KingdomTheme.Spacing.medium)
                                .parchmentCard(
                                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                                    hasShadow: false
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, KingdomTheme.Spacing.small)
                        
                        // Actions List
                        if let status = actionStatus {
                            if isInHomeKingdom {
                                // === BENEFICIAL ACTIONS (Home Kingdom) ===
                                
                                Divider()
                                    .padding(.horizontal)
                                
                                Text("Beneficial Actions")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, KingdomTheme.Spacing.medium)
                                
                                // Work on Contract
                                if let contract = activeContract {
                                    ActionCard(
                                        title: "Work on Contract",
                                        icon: "hammer.fill",
                                        description: "Contribute to \(contract.buildingType) construction",
                                        status: status.work,
                                        fetchedAt: statusFetchedAt ?? Date(),
                                        currentTime: currentTime,
                                        actionType: .work,
                                        isEnabled: true,
                                        onAction: { performWork() }
                                    )
                                } else {
                                    InfoCard(
                                        title: "No Active Contract",
                                        icon: "hammer.fill",
                                        description: "Join a contract to start working",
                                        color: .gray
                                    )
                                }
                                
                                // Patrol
                                ActionCard(
                                    title: "Patrol",
                                    icon: "eye.fill",
                                    description: "Guard against saboteurs for 10 minutes",
                                    status: status.patrol,
                                    fetchedAt: statusFetchedAt ?? Date(),
                                    currentTime: currentTime,
                                    actionType: .patrol,
                                    isEnabled: true,
                                    onAction: { performPatrol() }
                                )
                                
                                // Mine Resources
                                ActionCard(
                                    title: "Mine Resources",
                                    icon: "hammer.circle.fill",
                                    description: "Collect iron from the kingdom mine",
                                    status: status.mine,
                                    fetchedAt: statusFetchedAt ?? Date(),
                                    currentTime: currentTime,
                                    actionType: .mine,
                                    isEnabled: true,
                                    onAction: { performMine() }
                                )
                                
                            } else if isInEnemyKingdom {
                                // === MALICIOUS ACTIONS (Enemy Kingdom) ===
                                
                                Divider()
                                    .padding(.horizontal)
                                
                                Text("Hostile Actions")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, KingdomTheme.Spacing.medium)
                                
                                // Scout
                                ActionCard(
                                    title: "Scout Kingdom",
                                    icon: "magnifyingglass",
                                    description: "Gather intelligence on this enemy kingdom",
                                    status: status.scout,
                                    fetchedAt: statusFetchedAt ?? Date(),
                                    currentTime: currentTime,
                                    actionType: .scout,
                                    isEnabled: true,
                                    onAction: { performScout() }
                                )
                                
                                // Sabotage (coming soon)
                                ActionCard(
                                    title: "Sabotage (Coming Soon)",
                                    icon: "flame.fill",
                                    description: "Damage enemy buildings and infrastructure",
                                    status: status.sabotage,
                                    fetchedAt: statusFetchedAt ?? Date(),
                                    currentTime: currentTime,
                                    actionType: .sabotage,
                                    isEnabled: false,
                                    onAction: { /* Not implemented yet */ }
                                )
                            } else {
                                // Not in any kingdom
                                InfoCard(
                                    title: "Enter a Kingdom",
                                    icon: "location.fill",
                                    description: "Move to a kingdom to perform actions",
                                    color: .orange
                                )
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadActionStatus()
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
        }
    }
    
    // MARK: - Helpers
    
    private func isHomeKingdom(_ kingdom: Kingdom) -> Bool {
        return kingdom.rulerId == viewModel.player.playerId
    }
    
    // MARK: - API Calls
    
    private func loadActionStatus() async {
        isLoading = true
        do {
            actionStatus = try await KingdomAPIService.shared.actions.getActionStatus()
            statusFetchedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func performWork() {
        guard let contractId = activeContract?.id else { return }
        
        Task {
            do {
                // Capture state before action
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                
                let response = try await KingdomAPIService.shared.actions.workOnContract(contractId: contractId)
                
                // Refresh player state from backend (which has updated values)
                await loadActionStatus()
                await viewModel.loadContracts()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation  // Updated from backend
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performPatrol() {
        Task {
            do {
                print("🎬 Starting patrol action...")
                
                // Capture state before action
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                
                let response = try await KingdomAPIService.shared.actions.startPatrol()
                print("✅ Patrol response received: \(response)")
                
                // Refresh player state from backend (which has updated values)
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation  // Updated from backend
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch {
                print("❌ Patrol action failed: \(error)")
                print("❌ Error type: \(type(of: error))")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performMine() {
        Task {
            do {
                // Capture state before action
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                
                let response = try await KingdomAPIService.shared.actions.mineResources()
                
                // Refresh player state from backend (which has updated values)
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation  // Updated from backend
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performScout() {
        guard let kingdomId = currentKingdom?.id else { return }
        
        Task {
            do {
                // Capture state before action
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                
                let response = try await KingdomAPIService.shared.actions.scoutKingdom(kingdomId: kingdomId)
                
                // Refresh player state from backend (which has updated values)
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation  // Updated from backend
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Timer
    
    private func startUIUpdateTimer() {
        // Update current time every second to trigger countdown UI refresh
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopUIUpdateTimer() {
        // Timer will be deallocated when view disappears
    }
}

// MARK: - Action Card

enum ActionType {
    case work, patrol, mine, scout, sabotage
}

struct ActionCard: View {
    let title: String
    let icon: String
    let description: String
    let status: ActionStatus
    let fetchedAt: Date
    let currentTime: Date
    let actionType: ActionType
    let isEnabled: Bool
    let onAction: () -> Void
    
    var calculatedSecondsRemaining: Int {
        // Calculate how much time has elapsed since we fetched the status
        let elapsed = currentTime.timeIntervalSince(fetchedAt)
        let remaining = max(0, Double(status.secondsRemaining) - elapsed)
        return Int(remaining)
    }
    
    var isReady: Bool {
        return status.ready || calculatedSecondsRemaining <= 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(description)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            if isReady && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Perform Action")
                    }
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else if !isEnabled {
                Text("Check in to a kingdom first")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KingdomTheme.Colors.parchmentDark)
                    .cornerRadius(KingdomTheme.CornerRadius.medium)
            } else {
                CooldownTimer(secondsRemaining: calculatedSecondsRemaining)
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
    
    private var iconColor: Color {
        if isReady && isEnabled {
            return KingdomTheme.Colors.gold
        } else {
            return KingdomTheme.Colors.disabled
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let icon: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(description)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
}

// MARK: - Cooldown Timer

struct CooldownTimer: View {
    let secondsRemaining: Int
    
    var formattedTime: String {
        let hours = secondsRemaining / 3600
        let minutes = (secondsRemaining % 3600) / 60
        let seconds = secondsRemaining % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(KingdomTheme.Colors.disabled)
            
            Text("Available in \(formattedTime)")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(KingdomTheme.Colors.parchmentDark)
        .cornerRadius(KingdomTheme.CornerRadius.medium)
    }
}

#Preview {
    NavigationStack {
        ActionsView(viewModel: MapViewModel())
    }
}

