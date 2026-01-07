import Foundation
import UserNotifications

/// Centralized manager for handling local notifications
/// Schedules notifications when actions complete and character becomes idle
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Permission
    
    /// Request notification permissions from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            print("📱 Notification permission granted: \(granted)")
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    /// Check if notifications are authorized
    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    /// Get detailed notification settings for debugging
    func getNotificationSettings() async -> UNNotificationSettings {
        return await UNUserNotificationCenter.current().notificationSettings()
    }
    
    /// Print notification settings for debugging
    func debugNotificationSettings() async {
        let settings = await getNotificationSettings()
        print("🔔 Notification Settings Debug:")
        print("  Authorization: \(settings.authorizationStatus.rawValue)")
        print("  Sound: \(settings.soundSetting.rawValue)")
        print("  Badge: \(settings.badgeSetting.rawValue)")
        print("  Alert: \(settings.alertSetting.rawValue)")
    }
    
    // MARK: - Schedule Action Cooldown Notification
    
    /// Schedule a notification for when an action cooldown completes
    /// NEW: Supports parallel actions - multiple notifications can be scheduled at once
    /// - Parameters:
    ///   - actionName: Name of the action (e.g. "Farming", "Training", "Work")
    ///   - cooldownSeconds: How many seconds until the cooldown completes
    ///   - slot: Optional slot identifier for parallel actions (e.g. "economy", "building")
    func scheduleActionCooldownNotification(actionName: String, cooldownSeconds: Int, slot: String? = nil) async {
        // Don't schedule if cooldown is too short (< 5 seconds)
        guard cooldownSeconds > 5 else {
            print("⏭️ Skipping notification - cooldown too short (\(cooldownSeconds)s)")
            return
        }
        
        // Check permission and debug settings
        await debugNotificationSettings()
        
        let hasPermission = await checkPermission()
        guard hasPermission else {
            print("⚠️ Cannot schedule notification - permission not granted")
            return
        }
        
        let settings = await getNotificationSettings()
        if settings.soundSetting != .enabled {
            print("⚠️ Warning: Sound is not enabled in notification settings!")
        }
        
        // Create unique identifier per slot (enables parallel notifications!)
        let identifier = slot != nil ? "cooldown_\(slot!)" : "cooldown_global"
        
        // Create notification content with better messaging
        let content = UNMutableNotificationContent()
        content.title = "Action Complete!"
        content.body = formatCompletionMessage(for: actionName)
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "ACTION_COOLDOWN"
        
        // Add slot info to userInfo for future use
        if let slot = slot {
            content.userInfo = ["slot": slot, "action": actionName]
        }
        
        // Cancel existing notification for this specific slot
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Schedule for cooldown completion
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(cooldownSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            let slotInfo = slot != nil ? " [\(slot!) slot]" : ""
            print("✅ Scheduled notification for \(actionName)\(slotInfo) in \(cooldownSeconds)s (ID: \(identifier))")
        } catch {
            print("❌ Error scheduling notification: \(error)")
        }
    }
    
    /// Format a completion message for the action
    /// Examples: "You are no longer farming", "You are no longer training"
    private func formatCompletionMessage(for actionName: String) -> String {
        let lowercased = actionName.lowercased()
        
        // Handle gerunds (actions ending in -ing)
        if lowercased.hasSuffix("ing") {
            // "Farming" -> "You are no longer farming"
            // "Training" -> "You are no longer training"
            return "You are no longer \(lowercased)"
        }
        
        // Handle "Work" specially
        if lowercased == "work" {
            return "You are no longer working"
        }
        
        // Handle "Patrol" specially
        if lowercased == "patrol" {
            return "You are no longer on patrol"
        }
        
        // Default: "You can [action] again"
        return "You can \(lowercased) again"
    }
    
    // MARK: - Cancel Notifications
    
    /// Cancel all action cooldown notifications
    func cancelActionCooldownNotifications() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "cooldown_global",
            "cooldown_building",
            "cooldown_economy",
            "cooldown_security",
            "cooldown_personal",
            "cooldown_intelligence"
        ])
        print("🗑️ Cancelled all action cooldown notifications")
    }
    
    /// Cancel notification for a specific slot
    func cancelSlotNotification(slot: String) {
        let identifier = "cooldown_\(slot)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled \(slot) slot notification")
    }
    
    /// Clear all delivered notifications (badge count)
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

