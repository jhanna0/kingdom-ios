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
    
    // MARK: - Coup Phase Notifications
    
    /// Schedule a notification for when a coup phase ends
    /// - Parameters:
    ///   - coupId: The coup ID
    ///   - phase: Current phase ('pledge' or 'battle')
    ///   - endDate: When this phase ends
    ///   - kingdomName: Name of the kingdom for the notification
    func scheduleCoupPhaseNotification(coupId: Int, phase: String, endDate: Date, kingdomName: String) async {
        let now = Date()
        let secondsUntilEnd = endDate.timeIntervalSince(now)
        
        // Don't schedule if already passed or too short
        guard secondsUntilEnd > 5 else {
            print("⏭️ Skipping coup notification - phase already ended")
            return
        }
        
        let hasPermission = await checkPermission()
        guard hasPermission else {
            print("⚠️ Cannot schedule coup notification - permission not granted")
            return
        }
        
        let identifier = "coup_\(coupId)_\(phase)"
        
        let content = UNMutableNotificationContent()
        if phase == "pledge" {
            content.title = "Coup Battle Starting!"
            content.body = "The battle for \(kingdomName) has begun!"
        } else {
            content.title = "Coup Ending Soon"
            content.body = "The battle for \(kingdomName) is about to conclude"
        }
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "COUP_PHASE"
        content.userInfo = ["coup_id": coupId, "phase": phase, "kingdom": kingdomName]
        
        // Cancel any existing notification for this coup phase
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilEnd, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            let minutesUntil = Int(secondsUntilEnd / 60)
            print("✅ Scheduled coup \(phase) notification for \(kingdomName) in \(minutesUntil)m (ID: \(identifier))")
        } catch {
            print("❌ Error scheduling coup notification: \(error)")
        }
    }
    
    /// Cancel coup notifications for a specific coup
    func cancelCoupNotifications(coupId: Int) {
        let identifiers = ["coup_\(coupId)_pledge", "coup_\(coupId)_battle"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled coup \(coupId) notifications")
    }
    
    // MARK: - Garden Watering Notifications
    
    /// Schedule a notification for when a garden plant needs watering
    /// - Parameters:
    ///   - slotIndex: The garden slot index (0-5)
    ///   - secondsUntilWater: Seconds until the plant can be watered
    func scheduleGardenWateringNotification(slotIndex: Int, secondsUntilWater: Int) async {
        // Don't schedule if too short
        guard secondsUntilWater > 60 else {
            print("⏭️ Skipping garden notification - too short (\(secondsUntilWater)s)")
            return
        }
        
        let hasPermission = await checkPermission()
        guard hasPermission else {
            print("⚠️ Cannot schedule garden notification - permission not granted")
            return
        }
        
        let identifier = "garden_water_\(slotIndex)"
        
        let content = UNMutableNotificationContent()
        content.title = "Garden Needs Water! 💧"
        content.body = "Your plant is ready to be watered. Don't let it wilt!"
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "GARDEN_WATER"
        content.userInfo = ["slot_index": slotIndex]
        
        // Cancel existing notification for this slot
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsUntilWater), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            let hours = secondsUntilWater / 3600
            let minutes = (secondsUntilWater % 3600) / 60
            print("✅ Scheduled garden watering notification for slot \(slotIndex) in \(hours)h \(minutes)m")
        } catch {
            print("❌ Error scheduling garden notification: \(error)")
        }
    }
    
    /// Cancel garden watering notification for a specific slot
    func cancelGardenNotification(slotIndex: Int) {
        let identifier = "garden_water_\(slotIndex)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled garden notification for slot \(slotIndex)")
    }
    
    /// Cancel all garden watering notifications
    func cancelAllGardenNotifications() {
        let identifiers = (0..<6).map { "garden_water_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled all garden watering notifications")
    }
    
    // MARK: - Kitchen Baking Notifications
    
    /// Schedule a notification for when bread is done baking
    /// - Parameters:
    ///   - slotIndex: The oven slot index (0-3)
    ///   - secondsUntilReady: Seconds until the bread is done
    func scheduleKitchenBakingNotification(slotIndex: Int, secondsUntilReady: Int) async {
        // Don't schedule if too short
        guard secondsUntilReady > 60 else {
            print("⏭️ Skipping kitchen notification - too short (\(secondsUntilReady)s)")
            return
        }
        
        let hasPermission = await checkPermission()
        guard hasPermission else {
            print("⚠️ Cannot schedule kitchen notification - permission not granted")
            return
        }
        
        let identifier = "kitchen_baking_\(slotIndex)"
        
        let content = UNMutableNotificationContent()
        content.title = "Bread is Ready! 🍞"
        content.body = "Your sourdough is done baking. Time to collect!"
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "KITCHEN_BAKING"
        content.userInfo = ["slot_index": slotIndex]
        
        // Cancel existing notification for this slot
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsUntilReady), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            let hours = secondsUntilReady / 3600
            let minutes = (secondsUntilReady % 3600) / 60
            print("✅ Scheduled kitchen baking notification for slot \(slotIndex) in \(hours)h \(minutes)m")
        } catch {
            print("❌ Error scheduling kitchen notification: \(error)")
        }
    }
    
    /// Cancel kitchen baking notification for a specific slot
    func cancelKitchenNotification(slotIndex: Int) {
        let identifier = "kitchen_baking_\(slotIndex)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled kitchen notification for slot \(slotIndex)")
    }
    
    /// Cancel all kitchen baking notifications
    func cancelAllKitchenNotifications() {
        let identifiers = (0..<4).map { "kitchen_baking_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled all kitchen baking notifications")
    }
    
    // MARK: - Resource Reset Notifications (Lumbermill/Mine)
    
    /// Schedule a notification for when a resource building resets (daily limit)
    /// - Parameters:
    ///   - resourceType: The resource type ("wood", "stone", "iron")
    ///   - secondsUntilReset: Seconds until the daily limit resets
    func scheduleResourceResetNotification(resourceType: String, secondsUntilReset: Int) async {
        // Don't schedule if too short (less than 5 minutes)
        guard secondsUntilReset > 300 else {
            print("⏭️ Skipping resource reset notification - too short (\(secondsUntilReset)s)")
            return
        }
        
        let hasPermission = await checkPermission()
        guard hasPermission else {
            print("⚠️ Cannot schedule resource reset notification - permission not granted")
            return
        }
        
        // Use building-based identifier (wood = lumbermill, stone/iron = mine)
        let buildingType = resourceType == "wood" ? "lumbermill" : "mine"
        let identifier = "resource_reset_\(buildingType)"
        
        let content = UNMutableNotificationContent()
        if resourceType == "wood" {
            content.title = "Lumbermill Ready!"
            content.body = "The lumbermill has replenished. You may chop wood again!"
        } else {
            content.title = "Mine Ready!"
            content.body = "The mine has replenished. You may mine ore again!"
        }
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "RESOURCE_RESET"
        content.userInfo = ["resource_type": resourceType, "building_type": buildingType]
        
        // Cancel existing notification for this building (don't stack)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsUntilReset), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            let hours = secondsUntilReset / 3600
            let minutes = (secondsUntilReset % 3600) / 60
            print("✅ Scheduled \(buildingType) reset notification in \(hours)h \(minutes)m")
        } catch {
            print("❌ Error scheduling resource reset notification: \(error)")
        }
    }
    
    /// Cancel resource reset notification for a specific building
    func cancelResourceResetNotification(buildingType: String) {
        let identifier = "resource_reset_\(buildingType)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled \(buildingType) reset notification")
    }
    
    /// Cancel all resource reset notifications
    func cancelAllResourceResetNotifications() {
        let identifiers = ["resource_reset_lumbermill", "resource_reset_mine"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled all resource reset notifications")
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
            "cooldown_intelligence",
            "cooldown_coup_battle"
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

