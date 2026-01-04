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
    /// - Parameters:
    ///   - actionName: Name of the action (e.g. "Farming", "Training")
    ///   - cooldownSeconds: How many seconds until the cooldown completes
    func scheduleActionCooldownNotification(actionName: String, cooldownSeconds: Int) async {
        // Cancel any existing cooldown notifications
        await cancelActionCooldownNotifications()
        
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
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "You are Idle!"
        content.body = ""
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "ACTION_COOLDOWN"
        
        // Schedule for cooldown completion
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(cooldownSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: "action_cooldown", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled notification for \(actionName) in \(cooldownSeconds)s")
        } catch {
            print("❌ Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Cancel Notifications
    
    /// Cancel all action cooldown notifications
    func cancelActionCooldownNotifications() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["action_cooldown"])
        print("🗑️ Cancelled existing action cooldown notifications")
    }
    
    /// Clear all delivered notifications (badge count)
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

