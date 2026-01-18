import SwiftUI

// MARK: - Slot Action Item (Named struct to avoid anonymous tuple crashes)
/// SwiftUI can crash with anonymous tuples in ForEach due to type metadata lookup issues.
/// This named struct provides stable Identifiable conformance.
private struct SlotActionItem: Identifiable {
    let key: String
    let action: ActionStatus
    
    var id: String { key }
}

// MARK: - Actions View

struct ActionsView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var actionStatus: AllActionStatus?
    @State private var statusFetchedAt: Date?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showActionResult = false
    @State private var actionResultSuccess = true
    @State private var actionResultTitle = ""
    @State private var actionResultMessage = ""
    @State private var showReward = false
    @State private var currentReward: Reward?
    @State private var currentTime = Date()
    @State private var taskID = UUID()  // Persists across view recreations
    
    // Cache kingdom status to avoid recalculating on every render
    @State private var isInHomeKingdom: Bool = false
    @State private var isInEnemyKingdom: Bool = false
    @State private var cachedKingdomId: String?
    
    // Battle state (dynamic - backend tells us what to do)
    @State private var showBattleView = false
    @State private var isInitiatingBattle = false
    @State private var initiatedBattleId: Int?
    
    // Confirmation state for dangerous actions (coups/invasions)
    @State private var showBattleConfirmation = false
    @State private var pendingBattleAction: ActionStatus?
    
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
        .alert(pendingBattleAction?.title ?? "Confirm Action", isPresented: $showBattleConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingBattleAction = nil
            }
            Button(pendingBattleAction?.title ?? "Confirm", role: .destructive) {
                if let action = pendingBattleAction {
                    executeBattleInitiation(action: action)
                }
                pendingBattleAction = nil
            }
        } message: {
            Text(getBattleConfirmationMessage())
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
        // ALL slots rendered dynamically from backend - no duplicates!
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
    
    private func formatTime(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "\(mins)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
    
    // MARK: - Beneficial Actions (Home Kingdom) - DYNAMICALLY RENDERED FROM BACKEND
    
    private func beneficialActionsSection(status: AllActionStatus) -> some View {
        Group {
            // Alliance Requests Section (Ruler Only - Critical Priority)
            allianceRequestsSection(status: status)
            
            // DYNAMIC: Render all home slots from backend
            ForEach(status.homeSlots) { slot in
                dynamicSlotSection(slot: slot, status: status)
            }
        }
    }
    
    // MARK: - Alliance Requests Section
    
    @ViewBuilder
    private func allianceRequestsSection(status: AllActionStatus) -> some View {
        if let requests = status.pendingAllianceRequests, !requests.isEmpty {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                // Section header
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.buttonSuccess)
                        .frame(height: 3)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "handshake.fill")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        
                        Text("Alliance Proposals")
                            .font(FontStyles.headingLarge)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // Badge showing count
                        Text("\(requests.count)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.buttonSuccess,
                                cornerRadius: 8,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                    }
                    .padding(.horizontal)
                    .padding(.top, KingdomTheme.Spacing.medium)
                    
                    Text("Respond to alliance requests from other rulers")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .padding(.horizontal)
                }
                
                // Alliance request cards
                ForEach(requests) { request in
                    AllianceRequestCard(
                        request: request,
                        onAccept: { acceptAllianceRequest(request) },
                        onDecline: { declineAllianceRequest(request) }
                    )
                }
            }
        }
    }
    
    // MARK: - Dynamic Slot Section Renderer
    
    /// Renders a slot section with header and all its actions
    /// Frontend is a "dumb renderer" - all organization comes from backend
    @ViewBuilder
    private func dynamicSlotSection(slot: SlotInfo, status: AllActionStatus) -> some View {
        // Check if this slot has any content to show
        let hasContent = slotHasContent(slot: slot, status: status)
        
        if hasContent {
            // Section header with slot metadata from backend
            dynamicSectionHeader(slot: slot, status: status)
            
            // Slot description from backend
            if let description = slot.description, !description.isEmpty {
                Text(description)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, KingdomTheme.Spacing.small)
            }
            
            // Render slot-specific content
            renderSlotContent(slot: slot, status: status)
        }
    }
    
    /// Check if a slot has any content to display - uses contentType from backend!
    private func slotHasContent(slot: SlotInfo, status: AllActionStatus) -> Bool {
        switch slot.contentType {
        case "training_contracts":
            return !status.trainingContracts.filter { $0.status != "completed" }.isEmpty
        case "workshop_contracts":
            return !(status.workshopContracts?.filter { $0.status != "completed" }.isEmpty ?? true)
        case "building_contracts":
            let hasKingdomContracts = !availableContractsInKingdom.isEmpty
            let hasPropertyContracts = !(status.propertyUpgradeContracts?.filter { $0.status != "completed" }.isEmpty ?? true)
            return hasKingdomContracts || hasPropertyContracts
        case "actions":
            let slotActions = slot.actions.compactMap { status.actions[$0] }
            return !slotActions.isEmpty
        default:
            return false
        }
    }
    
    /// Render content for a specific slot - uses contentType from backend, NO hardcoded slot IDs!
    @ViewBuilder
    private func renderSlotContent(slot: SlotInfo, status: AllActionStatus) -> some View {
        switch slot.contentType {
        case "training_contracts":
            renderTrainingContracts(slot: slot, status: status)
            
        case "workshop_contracts":
            renderWorkshopContracts(slot: slot, status: status)
            
        case "building_contracts":
            renderBuildingContracts(slot: slot, status: status)
            
        case "actions":
            renderSlotActions(slot: slot, status: status)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Content Type Renderers (driven by backend contentType)
    
    @ViewBuilder
    private func renderTrainingContracts(slot: SlotInfo, status: AllActionStatus) -> some View {
        let cooldown = status.cooldown(for: slot.id)
        let isReady = cooldown?.ready ?? true
        let remainingSeconds = cooldown?.secondsRemaining ?? 0
        
        ForEach(status.trainingContracts.filter { $0.status != "completed" }) { contract in
            TrainingContractCard(
                contract: contract,
                status: status.training,
                fetchedAt: statusFetchedAt ?? Date(),
                currentTime: currentTime,
                isEnabled: true,
                globalCooldownActive: !isReady,
                blockingAction: cooldown?.blockingAction,
                globalCooldownSecondsRemaining: remainingSeconds,
                onAction: { performTraining(contractId: contract.id) }
            )
        }
    }
    
    @ViewBuilder
    private func renderWorkshopContracts(slot: SlotInfo, status: AllActionStatus) -> some View {
        let cooldown = status.cooldown(for: slot.id)
        let isReady = cooldown?.ready ?? true
        let remainingSeconds = cooldown?.secondsRemaining ?? 0
        
        if let workshopContracts = status.workshopContracts {
            ForEach(workshopContracts.filter { $0.status != "completed" }) { contract in
                WorkshopContractCard(
                    contract: contract,
                    status: status.crafting,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    globalCooldownActive: !isReady,
                    blockingAction: cooldown?.blockingAction,
                    globalCooldownSecondsRemaining: remainingSeconds,
                    onAction: { performWorkshopWork(contract: contract) }
                )
            }
        }
    }
    
    @ViewBuilder
    private func renderBuildingContracts(slot: SlotInfo, status: AllActionStatus) -> some View {
        let cooldown = status.cooldown(for: slot.id)
        let isReady = cooldown?.ready ?? true
        let remainingSeconds = cooldown?.secondsRemaining ?? 0
        
        // Kingdom building contracts
        ForEach(availableContractsInKingdom) { contract in
            WorkContractCard(
                contract: contract,
                status: status.work,
                fetchedAt: statusFetchedAt ?? Date(),
                currentTime: currentTime,
                globalCooldownActive: !isReady,
                blockingAction: cooldown?.blockingAction,
                globalCooldownSecondsRemaining: remainingSeconds,
                onAction: { performWork(contractId: contract.id) }
            )
        }
        
        // Property upgrade contracts
        if let propertyContracts = status.propertyUpgradeContracts {
            ForEach(propertyContracts.filter { $0.status != "completed" }) { contract in
                PropertyUpgradeContractCard(
                    contract: contract,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    globalCooldownActive: !isReady,
                    blockingAction: cooldown?.blockingAction,
                    globalCooldownSecondsRemaining: remainingSeconds,
                    onAction: { performPropertyUpgrade(contract: contract) }
                )
            }
        }
        
    }
    
    @ViewBuilder
    private func renderSlotActions(slot: SlotInfo, status: AllActionStatus) -> some View {
        // Use named struct instead of anonymous tuple to avoid SwiftUI type metadata crashes
        // Filter out empty keys and sort once before iteration
        let slotActions: [SlotActionItem] = slot.actions
            .filter { !$0.isEmpty }  // Guard against empty keys
            .compactMap { key in
                status.actions[key].map { SlotActionItem(key: key, action: $0) }
            }
            .sorted { ($0.action.displayOrder ?? 999) < ($1.action.displayOrder ?? 999) }
        
        ForEach(slotActions) { item in
            renderAction(key: item.key, action: item.action, status: status)
        }
    }
    
    // MARK: - Dynamic Section Header (Backend-driven)
    
    private func dynamicSectionHeader(slot: SlotInfo, status: AllActionStatus) -> some View {
        let cooldown = status.cooldown(for: slot.id)
        let isReady = cooldown?.ready ?? true
        let remainingSeconds = cooldown?.secondsRemaining ?? 0
        
        return VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                // Icon from backend
                Image(systemName: slot.icon)
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Display name from backend
                Text(slot.displayName)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if !isReady {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatTime(seconds: remainingSeconds))
                    }
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Ready")
                    }
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
            .padding(.horizontal)
            .padding(.top, KingdomTheme.Spacing.medium)
        }
    }
    
    // MARK: - Hostile Actions (Enemy Kingdom) - DYNAMICALLY RENDERED FROM BACKEND
    
    private func hostileActionsSection(status: AllActionStatus) -> some View {
        Group {
            // DYNAMIC: Render all enemy slots from backend
            ForEach(status.enemySlots) { slot in
                dynamicSlotSection(slot: slot, status: status)
            }
        }
    }
    
    // MARK: - Dynamic Action Rendering
    
    @ViewBuilder
    private func renderAction(key: String, action: ActionStatus, status: AllActionStatus) -> some View {
        if action.unlocked == true {
            let actionCooldown = getSlotCooldown(for: action, status: status)
            
            // Check action handler type from backend - NO HARDCODED ACTION TYPES!
            if action.handler == "initiate_battle" {
                // Actions that POST to create a battle and open BattleView
                ActionCard(
                    title: action.title ?? key.capitalized,
                    icon: action.icon ?? "bolt.fill",
                    description: action.description ?? "",
                    status: action,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    isEnabled: !isInitiatingBattle,
                    activeCount: nil,
                    globalCooldownActive: false,
                    blockingAction: nil,
                    globalCooldownSecondsRemaining: 0,
                    onAction: { initiateBattle(action: action) }
                )
            }
            else if action.handler == "view_battle" {
                // Actions that open an existing battle directly
                ActionCard(
                    title: action.title ?? "View Battle",
                    icon: action.icon ?? "bolt.fill",
                    description: action.description ?? "",
                    status: action,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    isEnabled: true,
                    activeCount: nil,
                    globalCooldownActive: false,
                    blockingAction: nil,
                    globalCooldownSecondsRemaining: 0,
                    onAction: { openBattle(battleId: action.battleId) }
                )
            }
            else {
                ActionCard(
                    title: action.title ?? key.capitalized,
                    icon: action.icon ?? "circle.fill",
                    description: action.description ?? "",
                    status: action,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    isEnabled: true,
                    activeCount: action.activePatrollers,
                    globalCooldownActive: actionCooldown.active,
                    blockingAction: actionCooldown.blockingAction,
                    globalCooldownSecondsRemaining: actionCooldown.seconds,
                    onAction: { performGenericAction(action: action) }
                )
            }
        } else {
            LockedActionCard(
                title: action.title ?? key.capitalized,
                icon: action.icon ?? "circle.fill",
                description: action.description ?? "",
                requirementText: action.requirementDescription ?? "Locked"
            )
        }
    }
    
    private func openBattle(battleId: Int?) {
        guard let id = battleId else {
            errorMessage = "Battle not found"
            showError = true
            return
        }
        initiatedBattleId = id
        showBattleView = true
    }
    
    // MARK: - Battle Actions (Dynamic - backend provides endpoint)
    
    /// Show confirmation before initiating a battle (coup or invasion)
    private func initiateBattle(action: ActionStatus) {
        pendingBattleAction = action
        showBattleConfirmation = true
    }
    
    /// Get confirmation message for pending battle action
    private func getBattleConfirmationMessage() -> String {
        guard let action = pendingBattleAction else {
            return "Are you sure you want to proceed?"
        }
        
        let kingdomName = currentKingdom?.name ?? "this kingdom"
        
        // Customize message based on action type
        if action.endpoint?.contains("invasion") == true {
            return "You are about to declare war on \(kingdomName). This will start a battle that other players can join. Are you sure?"
        } else if action.endpoint?.contains("coup") == true {
            return "You are about to stage a coup in \(kingdomName). This will challenge the current ruler for control. Are you sure?"
        } else {
            return action.description ?? "Are you sure you want to proceed with this action?"
        }
    }
    
    /// Actually execute the battle initiation after confirmation
    private func executeBattleInitiation(action: ActionStatus) {
        guard let endpoint = action.endpoint else {
            errorMessage = "No endpoint provided"
            showError = true
            return
        }
        
        guard let kingdomId = action.kingdomId ?? currentKingdom?.id else {
            errorMessage = "No kingdom selected"
            showError = true
            return
        }
        
        isInitiatingBattle = true
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: endpoint,
                    method: "POST",
                    body: ["target_kingdom_id": kingdomId]
                )
                let response: BattleInitiateResponse = try await APIClient.shared.execute(request)
                
                await MainActor.run {
                    initiatedBattleId = response.battleId
                    showBattleView = true
                    isInitiatingBattle = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isInitiatingBattle = false
                }
            }
        }
    }
    
    /// FULLY DYNAMIC ACTION HANDLER
    /// Backend provides complete endpoint with all params - we just POST to it!
    private func performGenericAction(action: ActionStatus) {
        guard let endpoint = action.endpoint else {
            errorMessage = "Action not available (no endpoint)"
            showError = true
            return
        }
        
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion (use action's slot)
                await scheduleNotificationForCooldown(actionName: action.title ?? "Action", slot: action.slot)
                
                await MainActor.run {
                    if let rewards = response.rewards {
                        // Show reward popup for actions with rewards
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
                    } else if !response.message.isEmpty {
                        // Show themed popup for actions without rewards
                        actionResultSuccess = response.success
                        actionResultTitle = response.success ? "Success!" : "Failed"
                        actionResultMessage = response.message
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showActionResult = true
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

// MARK: - API Calls

extension ActionsView {
    private func loadActionStatus(force: Bool = false, caller: String = #function, file: String = #file, line: Int = #line) async {
        print("🔍 loadActionStatus CALLED from \(file.split(separator: "/").last ?? ""):\(line) - \(caller)")
        print("   - isLoading: \(isLoading), force: \(force)")
        print("   - statusFetchedAt: \(statusFetchedAt?.description ?? "nil")")
        print("   - Time since last fetch: \(statusFetchedAt.map { Date().timeIntervalSince($0) } ?? -1) seconds")
        
        // Prevent duplicate requests if we just loaded (within 3 seconds) - UNLESS forced
        if !force, let lastFetch = statusFetchedAt, Date().timeIntervalSince(lastFetch) < 3 {
            print("⏭️ Skipping loadActionStatus - recent data exists")
            return
        }
        
        // Prevent concurrent requests
        guard !isLoading else {
            print("⏭️ Skipping loadActionStatus - already loading")
            return
        }
        
        isLoading = true
        print("📡 Making API call to /actions/status...")
        do {
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            print("✅ Got action status response")
            actionStatus = status
            statusFetchedAt = Date()
            print("✅ Set actionStatus and statusFetchedAt")
            
            await MainActor.run {
                viewModel.availableContracts = status.contracts.compactMap { apiContract in
                    // Convert per-action costs from API format
                    let perActionCosts = apiContract.per_action_costs?.map { apiCost in
                        ContractPerActionCost(
                            resource: apiCost.resource,
                            amount: apiCost.amount,
                            displayName: apiCost.display_name,
                            icon: apiCost.icon
                        )
                    }
                    
                    return Contract(
                        id: apiContract.id,
                        kingdomId: apiContract.kingdom_id,
                        kingdomName: apiContract.kingdom_name,
                        buildingType: apiContract.building_type,
                        buildingLevel: apiContract.building_level,
                        buildingBenefit: apiContract.building_benefit,
                        buildingIcon: apiContract.building_icon,
                        buildingDisplayName: apiContract.building_display_name,
                        basePopulation: apiContract.base_population,
                        baseHoursRequired: apiContract.base_hours_required,
                        workStartedAt: apiContract.work_started_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                        totalActionsRequired: apiContract.total_actions_required,
                        actionsCompleted: apiContract.actions_completed,
                        actionContributions: apiContract.action_contributions,
                        constructionCost: apiContract.construction_cost ?? 0,  // Default to 0 for old contracts
                        rewardPool: apiContract.reward_pool,
                        actionReward: apiContract.action_reward,
                        perActionCosts: perActionCosts,
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
    
    private func performWork(contractId: String) {
        Task {
            do {
                let previousGold = viewModel.player.gold
                let previousReputation = viewModel.player.reputation
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnContract(contractId: contractId)
                
                await loadActionStatus(force: true)
                await viewModel.loadContracts()
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion (use slot from action status)
                await scheduleNotificationForCooldown(actionName: "Work", slot: actionStatus?.work.slot)
                
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
    
    private func performTraining(contractId: String) {
        Task {
            do {
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.workOnTraining(contractId: contractId)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion (use slot from action status)
                await scheduleNotificationForCooldown(actionName: "Training", slot: actionStatus?.training.slot)
                
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
    
    private func performPropertyUpgrade(contract: PropertyUpgradeContract) {
        guard let endpoint = contract.endpoint else {
            errorMessage = "Action not available (no endpoint)"
            showError = true
            return
        }
        
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion (use slot from action status)
                await scheduleNotificationForCooldown(actionName: "Property Upgrade", slot: actionStatus?.work.slot)
                
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
    
    private func performWorkshopWork(contract: WorkshopContract) {
        guard let endpoint = contract.endpoint else {
            errorMessage = "Action not available (no endpoint)"
            showError = true
            return
        }
        
        Task {
            do {
                let previousExperience = viewModel.player.experience
                
                let response = try await KingdomAPIService.shared.actions.performGenericAction(endpoint: endpoint)
                
                await loadActionStatus(force: true)
                await viewModel.refreshPlayerFromBackend()
                viewModel.refreshCooldown()
                
                // Schedule notification for cooldown completion
                await scheduleNotificationForCooldown(actionName: "Workshop", slot: actionStatus?.crafting.slot)
                
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
                    } else {
                        actionResultSuccess = response.success
                        actionResultTitle = response.success ? "Progress!" : "Failed"
                        actionResultMessage = response.message
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showActionResult = true
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
    
    // MARK: - Alliance Actions
    
    private func acceptAllianceRequest(_ request: PendingAllianceRequest) {
        Task {
            do {
                let response = try await APIClient.shared.acceptAlliance(allianceId: request.id)
                
                await loadActionStatus(force: true)
                
                await MainActor.run {
                    actionResultSuccess = response.success
                    actionResultTitle = "Alliance Accepted!"
                    actionResultMessage = response.message
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showActionResult = true
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
    
    private func declineAllianceRequest(_ request: PendingAllianceRequest) {
        Task {
            do {
                let response = try await APIClient.shared.declineAlliance(allianceId: request.id)
                
                await loadActionStatus(force: true)
                
                await MainActor.run {
                    actionResultSuccess = response.success
                    actionResultTitle = "Alliance Declined"
                    actionResultMessage = response.message
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showActionResult = true
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
    
    // MARK: - Centralized Notification Helper
    
    /// Schedule notification for action cooldown completion
    /// NEW: Supports parallel actions - schedules per-slot notifications
    private func scheduleNotificationForCooldown(actionName: String, slot: String? = nil) async {
        guard let status = actionStatus else { return }
        
        var cooldownSeconds = 0
        
        // If parallel actions enabled and we have a slot, use slot-specific cooldown
        if status.supportsParallelActions, let slot = slot, let slotCooldown = status.cooldown(for: slot) {
            cooldownSeconds = slotCooldown.secondsRemaining
            print("📱 Scheduling notification for \(actionName) (\(slot) slot) - \(cooldownSeconds)s")
        } else {
            // Fallback to global cooldown
            cooldownSeconds = status.globalCooldown.secondsRemaining
            print("📱 Scheduling notification for \(actionName) (global) - \(cooldownSeconds)s")
        }
        
        // Schedule notification if there's a cooldown
        // InAppNotificationManager intercepts these when app is in foreground
        if cooldownSeconds > 0 {
            await NotificationManager.shared.scheduleActionCooldownNotification(
                actionName: actionName,
                cooldownSeconds: cooldownSeconds,
                slot: slot
            )
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
    
    // MARK: - Slot Cooldown Helpers (NEW)
    
    /// Get cooldown info for a specific action's slot
    private func getSlotCooldown(for action: ActionStatus, status: AllActionStatus) -> (active: Bool, seconds: Int, blockingAction: String?) {
        // If parallel actions enabled, check slot-specific cooldown
        if status.supportsParallelActions, let slot = action.slot {
            if let slotCooldown = status.cooldown(for: slot) {
                return (
                    active: !slotCooldown.ready,
                    seconds: slotCooldown.secondsRemaining,
                    blockingAction: slotCooldown.blockingAction
                )
            }
        }
        
        // Fallback to global cooldown (legacy)
        return (
            active: !status.globalCooldown.ready,
            seconds: status.globalCooldown.secondsRemaining,
            blockingAction: status.globalCooldown.blockingAction
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActionsView(viewModel: MapViewModel())
    }
}
