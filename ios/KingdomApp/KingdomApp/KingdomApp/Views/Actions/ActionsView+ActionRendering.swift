import SwiftUI

// MARK: - Slot Action Item

/// Named struct to avoid anonymous tuple crashes.
/// SwiftUI can crash with anonymous tuples in ForEach due to type metadata lookup issues.
/// This named struct provides stable Identifiable conformance.
struct SlotActionItem: Identifiable {
    let key: String
    let action: ActionStatus
    
    var id: String { key }
}

// MARK: - Action Rendering

extension ActionsView {
    
    // MARK: - Render Slot Actions
    
    @ViewBuilder
    func renderSlotActions(slot: SlotInfo, status: AllActionStatus) -> some View {
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
    
    // MARK: - Dynamic Action Rendering
    
    @ViewBuilder
    func renderAction(key: String, action: ActionStatus, status: AllActionStatus) -> some View {
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
            else if action.handler == "propose_alliance" {
                // Alliance proposal - needs kingdom_id in body
                ActionCard(
                    title: action.title ?? "Propose Alliance",
                    icon: action.icon ?? "person.2.fill",
                    description: action.description ?? "",
                    status: action,
                    fetchedAt: statusFetchedAt ?? Date(),
                    currentTime: currentTime,
                    isEnabled: true,
                    activeCount: nil,
                    globalCooldownActive: false,
                    blockingAction: nil,
                    globalCooldownSecondsRemaining: 0,
                    onAction: { proposeAlliance(action: action) }
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
}
