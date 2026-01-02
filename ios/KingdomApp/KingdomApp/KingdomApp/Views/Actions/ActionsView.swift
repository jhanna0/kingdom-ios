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
            print("❌ ActionsView: player.currentKingdom is nil")
            return nil
        }
        
        print("🔍 ActionsView currentKingdom computed:")
        print("   - Looking for ID: '\(currentKingdomId)'")
        print("   - viewModel.kingdoms.count: \(viewModel.kingdoms.count)")
        print("   - Kingdom IDs in viewModel: \(viewModel.kingdoms.map { $0.id }.joined(separator: ", "))")
        
        // Search by ID (which is what player.currentKingdom should always be)
        if let kingdom = viewModel.kingdoms.first(where: { $0.id == currentKingdomId }) {
            print("✅ ActionsView: Found kingdom: \(kingdom.name) (ID: \(kingdom.id))")
            return kingdom
        } else {
            print("❌ ActionsView: NO KINGDOM FOUND for ID '\(currentKingdomId)'")
            return nil
        }
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
        VStack(spacing: KingdomTheme.Spacing.large) {
            // Title
            HStack {
                Image(systemName: "figure.walk")
                    .font(FontStyles.iconExtraLarge)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Available Actions")
                    .font(FontStyles.displayMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            // Kingdom Context Card
            kingdomContextCard
        }
        .padding(.horizontal)
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    @ViewBuilder
    private var kingdomContextCard: some View {
        if let kingdom = currentKingdom {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: isInHomeKingdom ? "crown.fill" : "shield.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .brutalistBadge(
                        backgroundColor: isInHomeKingdom ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 8
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kingdom.name)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(isInHomeKingdom ? "Your Kingdom" : "Enemy Territory")
                        .font(FontStyles.labelLarge)
                        .foregroundColor(isInHomeKingdom ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
                }
                
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        } else {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Icon with brutalist badge
                Image(systemName: "map")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.disabled,
                        cornerRadius: 8
                    )
                
                Text("Enter a kingdom to perform actions")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
    }
    
    // MARK: - Action Status Content
    
    @ViewBuilder
    private func actionStatusContent(status: AllActionStatus) -> some View {
        // Global Cooldown Warning
        if !status.globalCooldown.ready {
            globalCooldownWarning(status: status)
        }
        
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
    
    // MARK: - Global Cooldown Warning
    
    private func globalCooldownWarning(status: AllActionStatus) -> some View {
        let blockingAction = status.globalCooldown.blockingAction
        let blockingActionDisplay = actionNameToDisplayName(blockingAction)
        
        // Calculate remaining time accounting for elapsed time since fetch
        let elapsed = currentTime.timeIntervalSince(statusFetchedAt ?? Date())
        let calculatedRemaining = max(0, Double(status.globalCooldown.secondsRemaining) - elapsed)
        let remaining = Int(calculatedRemaining)
        
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                
                Text("Action in Progress")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Text("You are already \(blockingActionDisplay). Only ONE action at a time!")
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack {
                if hours > 0 {
                    Text("Available in \(hours)h \(minutes)m \(seconds)s")
                        .font(FontStyles.bodyLargeBold)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                } else if minutes > 0 {
                    Text("Available in \(minutes)m \(seconds)s")
                        .font(FontStyles.bodyLargeBold)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                } else {
                    Text("Available in \(seconds)s")
                        .font(FontStyles.bodyLargeBold)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.buttonWarning.opacity(0.15))
        .padding(.horizontal)
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
                actionType: .farm,
                isEnabled: true,
                activeCount: nil,
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
                onAction: { performFarming() }
            )
            
            // Work on Contracts
            if !availableContractsInKingdom.isEmpty {
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    Text("Work on Contracts")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .padding(.horizontal)
                        .padding(.top, KingdomTheme.Spacing.small)
                    
                    ForEach(availableContractsInKingdom) { contract in
                        WorkContractCard(
                            contract: contract,
                            status: status.work,
                            fetchedAt: statusFetchedAt ?? Date(),
                            currentTime: currentTime,
                            globalCooldownActive: !status.globalCooldown.ready,
                            blockingAction: status.globalCooldown.blockingAction,
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
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
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
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
                onAction: { performScout() }
            )
            
            // Sabotage
            ActionCard(
                title: "Sabotage Contract",
                icon: "flame.fill",
                description: "Delay enemy construction projects (300g cost)",
                status: status.sabotage,
                fetchedAt: statusFetchedAt ?? Date(),
                currentTime: currentTime,
                actionType: .sabotage,
                isEnabled: true,
                activeCount: nil,
                globalCooldownActive: !status.globalCooldown.ready,
                blockingAction: status.globalCooldown.blockingAction,
                onAction: { showSabotageTargetSelection() }
            )
        }
    }
}

// MARK: - API Calls

extension ActionsView {
    private func loadActionStatus() async {
        isLoading = true
        do {
            print("📊 Loading action status...")
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            print("📊 Action status loaded successfully")
            print("📊 Farm status: ready=\(status.farm.ready), secondsRemaining=\(status.farm.secondsRemaining)")
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
                print("📊 Loaded \(viewModel.availableContracts.count) contracts")
            }
        } catch let error as APIError {
            print("❌ loadActionStatus APIError: \(error)")
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
                print("🌾 Starting farm action...")
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                print("🌾 Calling API performFarming...")
                let response = try await KingdomAPIService.shared.actions.performFarming()
                print("🌾 Farm response received: \(response.message)")
                print("🌾 Farm rewards: \(String(describing: response.rewards))")
                
                print("🌾 Loading action status...")
                await loadActionStatus()
                
                print("🌾 Refreshing player from backend...")
                await viewModel.refreshPlayerFromBackend()
                
                await MainActor.run {
                    print("🌾 Displaying reward UI...")
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
                        print("🌾 Farm action complete!")
                    } else {
                        print("⚠️ No rewards in farm response")
                    }
                }
            } catch let error as APIError {
                print("❌ Farm action APIError: \(error)")
                switch error {
                case .serverError(let message):
                    print("❌ Server error: \(message)")
                case .decodingError(let decodingError):
                    print("❌ Decoding error: \(decodingError)")
                case .networkError(let networkError):
                    print("❌ Network error: \(networkError)")
                case .unauthorized:
                    print("❌ Unauthorized")
                case .notFound(let message):
                    print("❌ Not found: \(message)")
                case .invalidURL:
                    print("❌ Invalid URL")
                }
                await MainActor.run {
                    errorMessage = "Farm Error: \(error.localizedDescription)"
                    showError = true
                }
            } catch {
                print("❌ Farm action unknown error: \(error)")
                print("❌ Error type: \(type(of: error))")
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
