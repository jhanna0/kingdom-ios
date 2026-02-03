import SwiftUI

// MARK: - Dynamic Slot Rendering

extension ActionsView {
    
    // MARK: - Dynamic Slot Section Renderer
    
    /// Renders a slot section with header and all its actions
    /// Frontend is a "dumb renderer" - all organization comes from backend
    @ViewBuilder
    func dynamicSlotSection(slot: SlotInfo, status: AllActionStatus) -> some View {
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
    func slotHasContent(slot: SlotInfo, status: AllActionStatus) -> Bool {
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
    func renderSlotContent(slot: SlotInfo, status: AllActionStatus) -> some View {
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
    
    // MARK: - Dynamic Section Header
    
    func dynamicSectionHeader(slot: SlotInfo, status: AllActionStatus) -> some View {
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
    
    // MARK: - Content Type Renderers
    
    @ViewBuilder
    func renderTrainingContracts(slot: SlotInfo, status: AllActionStatus) -> some View {
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
                onAction: { performTraining(contractId: contract.id) },
                onRefresh: { Task { await loadActionStatus(force: true) } }
            )
        }
    }
    
    @ViewBuilder
    func renderWorkshopContracts(slot: SlotInfo, status: AllActionStatus) -> some View {
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
                    onAction: { performWorkshopWork(contract: contract) },
                    onRefresh: { Task { await loadActionStatus(force: true) } }
                )
            }
        }
    }
    
    @ViewBuilder
    func renderBuildingContracts(slot: SlotInfo, status: AllActionStatus) -> some View {
        let cooldown = status.cooldown(for: slot.id)
        let isReady = cooldown?.ready ?? true
        let remainingSeconds = cooldown?.secondsRemaining ?? 0
        
        // Property upgrade contracts (show first - player's own property takes priority)
        if let propertyContracts = status.propertyUpgradeContracts {
            ForEach(propertyContracts.filter { $0.status != "completed" }) { contract in
                PropertyUpgradeContractCard(
                    contract: contract,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    globalCooldownActive: !isReady,
                    blockingAction: cooldown?.blockingAction,
                    globalCooldownSecondsRemaining: remainingSeconds,
                    canUseBook: cooldown?.canUseBook ?? false,
                    onAction: { performPropertyUpgrade(contract: contract) },
                    onRefresh: { Task { await loadActionStatus(force: true) } }
                )
            }
        }
        
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
                onAction: {
                    if let endpoint = contract.endpoint {
                        performGenericWorkAction(endpoint: endpoint)
                    } else {
                        performWork(contractId: contract.id)
                    }
                },
                onRefresh: { Task { await loadActionStatus(force: true) } }
            )
        }
    }
}
