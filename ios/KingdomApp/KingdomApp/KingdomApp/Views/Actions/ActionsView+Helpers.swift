import SwiftUI

// MARK: - Helper Methods

extension ActionsView {
    
    // MARK: - Time Formatting
    
    func formatTime(seconds: Int) -> String {
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
    
    // MARK: - Timer Management
    
    func startUIUpdateTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    func stopUIUpdateTimer() {
        // Timer will be deallocated when view disappears
    }
    
    // MARK: - Slot Cooldown Helpers
    
    /// Get cooldown info for a specific action's slot
    func getSlotCooldown(for action: ActionStatus, status: AllActionStatus) -> (active: Bool, seconds: Int, blockingAction: String?) {
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
    
    // MARK: - Notification Scheduling
    
    /// Schedule notification for action cooldown completion
    /// Supports parallel actions - schedules per-slot notifications
    func scheduleNotificationForCooldown(actionName: String, slot: String? = nil) async {
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
