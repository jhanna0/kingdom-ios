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
    
    var availableContractsInKingdom: [Contract] {
        guard let kingdom = currentKingdom else { return [] }
        return viewModel.availableContracts.filter { $0.kingdomId == kingdom.id }
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
                            // === TRAINING CONTRACTS (Only if purchased) ===
                            
                            if !status.trainingContracts.isEmpty {
                                Divider()
                                    .padding(.horizontal)
                                
                                Text("Character Training")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, KingdomTheme.Spacing.medium)
                                
                                Text("Train your skills - complete actions to level up (2 hour cooldown)")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, KingdomTheme.Spacing.small)
                                
                                // Show training contracts like building contracts
                                ForEach(status.trainingContracts.filter { $0.status != "completed" }) { contract in
                                    TrainingContractCard(
                                        contract: contract,
                                        status: status.training,
                                        fetchedAt: statusFetchedAt ?? Date(),
                                        currentTime: currentTime,
                                        isEnabled: currentKingdom != nil,
                                        onAction: { performTraining(contractId: contract.id) }
                                    )
                                }
                            }
                            
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
                                
                                // Work on Contracts
                                if !availableContractsInKingdom.isEmpty {
                                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                                        Text("Work on Contracts")
                                            .font(KingdomTheme.Typography.subheadline())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                            .padding(.horizontal)
                                            .padding(.top, KingdomTheme.Spacing.small)
                                        
                                        ForEach(availableContractsInKingdom) { contract in
                                            WorkContractCard(
                                                contract: contract,
                                                status: status.work,
                                                fetchedAt: statusFetchedAt ?? Date(),
                                                currentTime: currentTime,
                                                onAction: { performWork(contractId: contract.id) }
                                            )
                                        }
                                    }
                                } else {
                                    InfoCard(
                                        title: "No Active Contracts",
                                        icon: "hammer.fill",
                                        description: "Ruler can create contracts for building upgrades",
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
                                    activeCount: status.patrol.activePatrollers,
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
                                    activeCount: nil,
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
                                    activeCount: nil,
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
                                    activeCount: nil,
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
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            actionStatus = status
            statusFetchedAt = Date()
            
            // Update contracts from the same response
            await MainActor.run {
                viewModel.availableContracts = status.contracts.compactMap { apiContract in
                    Contract(
                        id: apiContract.id,
                        kingdomId: apiContract.kingdom_id,
                        kingdomName: apiContract.kingdom_name,
                        buildingType: apiContract.building_type,
                        buildingLevel: apiContract.building_level,
                        basePopulation: apiContract.base_population,
                        baseHoursRequired: apiContract.base_hours_required,
                        workStartedAt: apiContract.work_started_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        totalActionsRequired: apiContract.total_actions_required,
                        actionsCompleted: apiContract.actions_completed,
                        actionContributions: apiContract.action_contributions,
                        rewardPool: apiContract.reward_pool,
                        createdBy: apiContract.created_by,
                        createdAt: ISO8601DateFormatter().date(from: apiContract.created_at) ?? Date(),
                        completedAt: apiContract.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        status: Contract.ContractStatus(rawValue: apiContract.status) ?? .open
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func performWork(contractId: Int) {
        Task {
            do {
                // Capture state before action
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
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
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation,  // Updated from backend
                            currentExperience: viewModel.player.experience  // Updated from backend
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
                let previousExperience = viewModel.player.experience
                
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
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation,  // Updated from backend
                            currentExperience: viewModel.player.experience  // Updated from backend
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
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.mineResources()
                
                // Refresh player state from backend (which has updated values)
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation,  // Updated from backend
                            currentExperience: viewModel.player.experience  // Updated from backend
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
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.scoutKingdom(kingdomId: kingdomId)
                
                // Refresh player state from backend (which has updated values)
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: rewards.gold ?? 0,
                            reputationReward: rewards.reputation ?? 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: previousGold,
                            previousReputation: previousReputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,  // Updated from backend
                            currentReputation: viewModel.player.reputation,  // Updated from backend
                            currentExperience: viewModel.player.experience  // Updated from backend
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
    
    // MARK: - Training Actions
    
    private func performTraining(contractId: String) {
        Task {
            do {
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnTraining(contractId: contractId)
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        currentReward = Reward(
                            goldReward: 0,
                            reputationReward: 0,
                            experienceReward: rewards.experience ?? 0,
                            message: response.message,
                            previousGold: viewModel.player.gold,
                            previousReputation: viewModel.player.reputation,
                            previousExperience: previousExperience,
                            currentGold: viewModel.player.gold,
                            currentReputation: viewModel.player.reputation,
                            currentExperience: viewModel.player.experience
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
}

// MARK: - Work Contract Card

struct WorkContractCard: View {
    let contract: Contract
    let status: ActionStatus
    let fetchedAt: Date
    let currentTime: Date
    let onAction: () -> Void
    
    var calculatedSecondsRemaining: Int {
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
                Image(systemName: "hammer.fill")
                    .font(.title2)
                    .foregroundColor(isReady ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contract.buildingType)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                                    HStack(spacing: 4) {
                                        Text("\(contract.actionsCompleted)/\(contract.totalActionsRequired) actions")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        
                                        Text("•")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        
                                        Text("\(Int(contract.progress * 100))%")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(KingdomTheme.Colors.gold)
                                            .fontWeight(.semibold)
                                        
                                        Text("•")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        
                                        Text("\(contract.rewardPool)g pool")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    }
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.gold)
                        .frame(width: geometry.size.width * contract.progress, height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            if isReady {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Work on This")
                    }
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else {
                CooldownTimer(secondsRemaining: calculatedSecondsRemaining)
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
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
    let activeCount: Int?
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
                    HStack(spacing: 8) {
                        Text(title)
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Show active count for patrol (always show if available)
                        if let count = activeCount {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption)
                                Text("\(count)")
                                    .font(KingdomTheme.Typography.caption())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(count > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((count > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled).opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
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

// MARK: - Training Contract Card

struct TrainingContractCard: View {
    let contract: TrainingContract
    let status: ActionStatus
    let fetchedAt: Date
    let currentTime: Date
    let isEnabled: Bool
    let onAction: () -> Void
    
    var calculatedSecondsRemaining: Int {
        let elapsed = currentTime.timeIntervalSince(fetchedAt)
        let remaining = max(0, Double(status.secondsRemaining) - elapsed)
        return Int(remaining)
    }
    
    var isReady: Bool {
        return status.ready || calculatedSecondsRemaining <= 0
    }
    
    var iconName: String {
        switch contract.type {
        case "attack": return "bolt.fill"
        case "defense": return "shield.fill"
        case "leadership": return "crown.fill"
        case "building": return "hammer.fill"
        default: return "star.fill"
        }
    }
    
    var title: String {
        switch contract.type {
        case "attack": return "Attack Training"
        case "defense": return "Defense Training"
        case "leadership": return "Leadership Training"
        case "building": return "Building Training"
        default: return "Training"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isReady ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 4) {
                        Text("\(contract.actionsCompleted)/\(contract.actionsRequired) actions")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("•")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("\(Int(contract.progress * 100))%")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.gold)
                        .frame(width: geometry.size.width * contract.progress, height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            if isReady && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Train Now")
                    }
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else if !isEnabled {
                Text("Check in to a kingdom to train")
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
}

#Preview {
    NavigationStack {
        ActionsView(viewModel: MapViewModel())
    }
}

