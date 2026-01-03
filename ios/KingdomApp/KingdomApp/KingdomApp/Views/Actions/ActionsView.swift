import SwiftUI

// MARK: - Actions View

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
    @State private var showSabotageTargets = false
    @State private var sabotageTargets: SabotageTargetsResponse?
    
    // Cache kingdom status to avoid recalculating on every render
    @State private var isInHomeKingdom: Bool = false
    @State private var isInEnemyKingdom: Bool = false
    @State private var cachedKingdomId: String?
    
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
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadActionStatus()
            updateKingdomStatus()
            startUIUpdateTimer()
        }
        .onChange(of: currentKingdom?.id) { oldValue, newValue in
            // Only recalculate when kingdom actually changes
            updateKingdomStatus()
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
        .sheet(isPresented: $showSabotageTargets) {
            if let targets = sabotageTargets {
                SabotageTargetSelectionView(
                    targets: targets,
                    onSabotage: { contractId in
                        showSabotageTargets = false
                        performSabotage(contractId: contractId)
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        // Just the Kingdom Context Card - sleek!
        kingdomContextCard
            .padding(.horizontal)
            .padding(.top, KingdomTheme.Spacing.small)
    }
    
    @ViewBuilder
    private var kingdomContextCard: some View {
        if let kingdom = currentKingdom {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: isInHomeKingdom ? "crown.fill" : "shield.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: isInHomeKingdom ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kingdom.name)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(isInHomeKingdom ? "Your Kingdom" : "Enemy Territory")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(isInHomeKingdom ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonDanger)
                }
                
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        } else {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.disabled,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Kingdom")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Enter a kingdom to perform actions")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        }
    }
    
    // MARK: - Action Status Content
    
    @ViewBuilder
    private func actionStatusContent(status: AllActionStatus) -> some View {
        // Training Contracts
        if !status.trainingContracts.isEmpty {
            trainingSection(status: status)
        }
        
        // Property Upgrade Contracts
        if let propertyContracts = status.propertyUpgradeContracts, !propertyContracts.isEmpty {
            propertyUpgradeSection(contracts: propertyContracts, status: status)
        }
        
        // Location-based actions
        if isInHomeKingdom {
            beneficialActionsSection(status: status)
        } else if isInEnemyKingdom {
            hostileActionsSection(status: status)
        } else {
            InfoCard(
                title: "Enter a Kingdom",
                icon: "location.fill",
                description: "Move to a kingdom to perform actions",
                color: .orange
            )
        }
    }
    
    // MARK: - Training Section
    
    private func trainingSection(status: AllActionStatus) -> some View {
        Group {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            Text("Character Training")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.medium)
            
            Text("Train your skills - complete actions to level up (2 hour cooldown)")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, KingdomTheme.Spacing.small)
            
            ForEach(status.trainingContracts.filter { $0.status != "completed" }) { contract in
                TrainingContractCard(
                    contract: contract,
                    status: status.training,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    isEnabled: currentKingdom != nil,
                    globalCooldownActive: !status.globalCooldown.ready,
                    blockingAction: status.globalCooldown.blockingAction,
                    globalCooldownSecondsRemaining: status.globalCooldown.secondsRemaining,
                    onAction: { performTraining(contractId: contract.id) }
                )
            }
        }
    }
    
    // MARK: - Property Upgrade Section
    
    private func propertyUpgradeSection(contracts: [PropertyUpgradeContract], status: AllActionStatus) -> some View {
        Group {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            Text("Property Upgrades")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.medium)
            
            Text("Build and upgrade your properties - complete work actions to finish")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, KingdomTheme.Spacing.small)
            
            ForEach(contracts.filter { $0.status != "completed" }) { contract in
                PropertyUpgradeContractCard(
                    contract: contract,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    globalCooldownActive: !status.globalCooldown.ready,
                    blockingAction: status.globalCooldown.blockingAction,
                    globalCooldownSecondsRemaining: status.globalCooldown.secondsRemaining,
                    onAction: { performPropertyUpgrade(contractId: contract.id) }
                )
            }
        }
    }
    
    // MARK: - Beneficial Actions (Home Kingdom)
    
    private func beneficialActionsSection(status: AllActionStatus) -> some View {
        Group {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            Text("Kingdom Project")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.medium)
            
            // Work on Contracts
            if !availableContractsInKingdom.isEmpty {
                ForEach(availableContractsInKingdom) { contract in
                    WorkContractCard(
                        contract: contract,
                        status: status.work,
                        fetchedAt: statusFetchedAt ?? Date(),
                        currentTime: currentTime,
                        globalCooldownActive: !status.globalCooldown.ready,
                        blockingAction: status.globalCooldown.blockingAction,
                        globalCooldownSecondsRemaining: status.globalCooldown.secondsRemaining,
                        onAction: { performWork(contractId: contract.id) }
                    )
                }
            } else {
                InfoCard(
                    title: "No Active Contracts",
                    icon: "hammer.fill",
                    description: "Ruler can create contracts for building upgrades",
                    color: .gray
                )
            }
            
            // Divider
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.medium)
            
            Text("Beneficial Actions")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.medium)
            
            // Farm (Always available)
            ActionCard(
                title: "Farm",
                icon: "leaf.fill",
                description: "Work the fields to earn gold",
                status: status.farm,
                fetchedAt: statusFetchedAt ?? Date(),
                currentTime: currentTime,
                isEnabled: true,
                activeCount: nil,
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
                globalCooldownSecondsRemaining: status.globalCooldown.secondsRemaining,
                onAction: { performFarming() }
            )
            
            // Patrol
            ActionCard(
                title: "Patrol",
                icon: "eye.fill",
                description: "Guard against saboteurs for 10 minutes",
                status: status.patrol,
                fetchedAt: statusFetchedAt ?? Date(),
                currentTime: currentTime,
                isEnabled: true,
                activeCount: status.patrol.activePatrollers,
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
                globalCooldownSecondsRemaining: status.globalCooldown.secondsRemaining,
                onAction: { performPatrol() }
            )
        }
    }
    
    // MARK: - Hostile Actions (Enemy Kingdom)
    
    private func hostileActionsSection(status: AllActionStatus) -> some View {
        Group {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            Text("Hostile Actions")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.medium)
            
            // DYNAMIC: Render all hostile actions from API
            ForEach(sortedActions(status.actions, category: "hostile"), id: \.key) { key, action in
                renderAction(key: key, action: action, status: status)
            }
        }
    }
    
    // MARK: - Dynamic Action Rendering
    
    private func sortedActions(_ actions: [String: ActionStatus], category: String) -> [(key: String, value: ActionStatus)] {
        return actions
            .filter { $0.value.category == category }
            .sorted { ($0.value.displayOrder ?? 999) < ($1.value.displayOrder ?? 999) }
    }
    
    @ViewBuilder
    private func renderAction(key: String, action: ActionStatus, status: AllActionStatus) -> some View {
        if action.unlocked == true {
            ActionCard(
                title: action.title ?? key.capitalized,
                icon: action.icon ?? "circle.fill",
                description: action.description ?? "",
                status: action,
                fetchedAt: statusFetchedAt ?? Date(),
                currentTime: currentTime,
                isEnabled: true,
                activeCount: action.activePatrollers,
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
                globalCooldownSecondsRemaining: status.globalCooldown.secondsRemaining,
                onAction: { performAction(key: key) }
            )
        } else {
            LockedActionCard(
                title: action.title ?? key.capitalized,
                icon: action.icon ?? "circle.fill",
                description: action.description ?? "",
                requirementText: action.requirementDescription ?? "Locked"
            )
        }
    }
    
    private func performAction(key: String) {
        switch key {
        case "scout":
            performScout()
        case "sabotage":
            showSabotageTargetSelection()
        case "vault_heist":
            performVaultHeist()
        default:
            print("⚠️ Unknown action: \(key)")
        }
    }
}

// MARK: - API Calls

extension ActionsView {
    private func loadActionStatus() async {
        isLoading = true
        do {
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            actionStatus = status
            statusFetchedAt = Date()
            
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
                        constructionCost: apiContract.construction_cost ?? 0,  // Default to 0 for old contracts
                        rewardPool: apiContract.reward_pool,
                        createdBy: apiContract.created_by,
                        createdAt: ISO8601DateFormatter().date(from: apiContract.created_at) ?? Date(),
                        completedAt: apiContract.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        status: Contract.ContractStatus(rawValue: apiContract.status) ?? .open
                    )
                }
            }
        } catch let error as APIError {
            print("❌ loadActionStatus error: \(error)")
            await MainActor.run {
                errorMessage = "Status Error: \(error.localizedDescription)"
                showError = true
            }
        } catch {
            print("❌ loadActionStatus error: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        isLoading = false
    }
    
    private func performWork(contractId: Int) {
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnContract(contractId: contractId)
                
                await loadActionStatus()
                await viewModel.loadContracts()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
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
    
    private func performPatrol() {
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.startPatrol()
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
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
    
    private func performFarming() {
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.performFarming()
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
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
                            currentGold: viewModel.player.gold,
                            currentReputation: viewModel.player.reputation,
                            currentExperience: viewModel.player.experience
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showReward = true
                        }
                    }
                }
            } catch let error as APIError {
                print("❌ Farm action error: \(error)")
                await MainActor.run {
                    errorMessage = "Farm Error: \(error.localizedDescription)"
                    showError = true
                }
            } catch {
                print("❌ Farm action error: \(error)")
                await MainActor.run {
                    errorMessage = "Farm Error: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func performScout() {
        guard let kingdomId = currentKingdom?.id else { return }
        
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.scoutKingdom(kingdomId: kingdomId)
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
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
    
    private func showSabotageTargetSelection() {
        Task {
            do {
                let targets = try await KingdomAPIService.shared.actions.getSabotageTargets()
                await MainActor.run {
                    sabotageTargets = targets
                    showSabotageTargets = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performSabotage(contractId: Int) {
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                
                let response = try await KingdomAPIService.shared.actions.sabotageContract(contractId: contractId)
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                await MainActor.run {
                    currentReward = Reward(
                        goldReward: response.rewards.netGold,
                        reputationReward: response.rewards.reputation,
                        experienceReward: 0,
                        message: response.message,
                        previousGold: previousGold,
                        previousReputation: previousReputation,
                        previousExperience: viewModel.player.experience,
                        currentGold: viewModel.player.gold,
                        currentReputation: viewModel.player.reputation,
                        currentExperience: viewModel.player.experience
                    )
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showReward = true
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
    
    private func performTraining(contractId: String) {
        Task {
            do {
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnTraining(contractId: contractId)
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
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
    
    private func performPropertyUpgrade(contractId: String) {
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.workOnPropertyUpgrade(contractId: contractId)
                
                await loadActionStatus()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                await MainActor.run {
                    currentReward = Reward(
                        goldReward: 0,
                        reputationReward: 0,
                        experienceReward: 0,
                        message: response.message,
                        previousGold: viewModel.player.gold,
                        previousReputation: viewModel.player.reputation,
                        previousExperience: viewModel.player.experience,
                        currentGold: viewModel.player.gold,
                        currentReputation: viewModel.player.reputation,
                        currentExperience: viewModel.player.experience
                    )
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showReward = true
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
    
    private func performVaultHeist() {
        guard let kingdomId = currentKingdom?.id else { return }
        
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                
                // TODO: Implement vault heist API call
                // let response = try await KingdomAPIService.shared.actions.attemptVaultHeist(kingdomId: kingdomId)
                
                await MainActor.run {
                    errorMessage = "Vault heist not yet implemented"
                    showError = true
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

// MARK: - Timer & Kingdom Status

extension ActionsView {
    private func startUIUpdateTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopUIUpdateTimer() {
        // Timer will be deallocated when view disappears
    }
    
    private func updateKingdomStatus() {
        guard let kingdom = currentKingdom else {
            isInHomeKingdom = false
            isInEnemyKingdom = false
            cachedKingdomId = nil
            return
        }
        
        // Only recalculate if kingdom changed
        if cachedKingdomId != kingdom.id {
            cachedKingdomId = kingdom.id
            isInHomeKingdom = viewModel.isHomeKingdom(kingdom)
            isInEnemyKingdom = !isInHomeKingdom
            print("♻️ Updated kingdom status cache for \(kingdom.name)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActionsView(viewModel: MapViewModel())
    }
}
