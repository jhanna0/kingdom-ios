import Foundation
import SwiftUI
import Combine

/// Handles app initialization and loading all relevant user data
class AppInitService: ObservableObject {
    @Published var isLoading = false
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published var playerSummary: PlayerSummary?
    @Published var errorMessage: String?
    
    /// Kingdoms the player rules - SOURCE OF TRUTH from backend
    /// This comes from /notifications/updates kingdoms array
    @Published var ruledKingdoms: [KingdomUpdate] = []
    
    /// Generic popup notification - backend tells us when to show via show_popup field
    @Published var popupNotification: AppNotification?
    
    /// Server-driven prompt popup (feedback, polls, etc.) - backend controls content via URL
    @Published var serverPrompt: ServerPrompt?
    
    /// Legacy: Set when user becomes ruler via coup - triggers celebration popup
    @Published var coupCelebrationKingdom: String?
    
    private let apiClient = APIClient.shared
    
    // MARK: - Initialization
    
    /// Load all user data when app starts
    @MainActor
    func initialize() async {
        // FIRST: Check version requirements before doing anything else
        let versionCheckPassed = await VersionManager.shared.performStartupCheck()
        if !versionCheckPassed {
            print("❌ AppInitService: Version check failed, blocking app")
            isLoading = false
            return
        }
        
        guard apiClient.isAuthenticated else {
            print("⚠️ AppInitService: Not authenticated, skipping init")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load tier data first (single source of truth for game data)
            // This runs in parallel with user data for speed
            async let tierTask: () = loadTierData()
            
            // Fetch all updates from backend
            let updates: UserUpdatesResponse = try await apiClient.execute(
                apiClient.request(endpoint: "/notifications/updates")
            )
            
            // Wait for tier data to finish
            await tierTask
            
            // Update state
            playerSummary = updates.summary
            notifications = updates.notifications
            unreadCount = updates.notifications.filter { $0.priority == "high" }.count
            
            // Store ruled kingdoms from backend (SOURCE OF TRUTH)
            ruledKingdoms = updates.kingdoms
            
            // Log what we found
            print("✅ AppInitService: Loaded user data")
            print("   - Level: \(updates.summary.level)")
            print("   - Gold: \(updates.summary.gold)")
            print("   - Ready contracts: \(updates.summary.ready_contracts)")
            print("   - Notifications: \(notifications.count)")
            print("   - Ruled Kingdoms: \(ruledKingdoms.map { $0.name })")
            
            // Show important notifications
            await showImportantNotifications(updates.notifications)
            
            // Check for server-driven prompts (feedback, polls, etc.)
            await checkServerPrompt()
            
        } catch {
            errorMessage = "Failed to load user data: \(error.localizedDescription)"
            print("❌ AppInitService error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load tier data from backend (single source of truth)
    private func loadTierData() async {
        do {
            try await TierManager.shared.loadAllTiers()
            print("✅ AppInitService: Loaded tier data")
        } catch {
            print("⚠️ AppInitService: Failed to load tier data, using defaults: \(error)")
            // TierManager has fallback defaults, so UI won't break
        }
    }
    
    /// Refresh data (called periodically or on app foreground)
    @MainActor
    func refresh() async {
        await initialize()
    }
    
    // MARK: - Notifications
    
    @MainActor
    private func showImportantNotifications(_ notifications: [AppNotification]) async {
        // Check for any notification that needs a popup (backend tells us via show_popup)
        for notification in notifications {
            if notification.show_popup == true {
                print("🎉 POPUP: \(notification.title) - \(notification.message)")
                popupNotification = notification
                break  // Only show one popup at a time
            }
        }
        
        // Log high priority notifications
        let highPriority = notifications.filter { $0.priority == "high" || $0.priority == "critical" }
        for notification in highPriority {
            print("🔔 \(notification.title): \(notification.message)")
        }
    }
    
    /// Get quick summary (for badge/widget)
    func getQuickSummary() async throws -> QuickSummary {
        let summary: QuickSummary = try await apiClient.execute(
            apiClient.request(endpoint: "/notifications/summary")
        )
        
        await MainActor.run {
            self.unreadCount = summary.unread_notifications
        }
        
        return summary
    }
    
    /// Clear a notification
    func dismissNotification(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
        unreadCount = notifications.filter { $0.priority == "high" }.count
    }
    
    // MARK: - Server Prompts (Feedback, Polls, etc.)
    
    /// Check if backend has a prompt to show (feedback request, poll, etc.)
    @MainActor
    private func checkServerPrompt() async {
        do {
            let response: ServerPromptCheckResponse = try await apiClient.execute(
                apiClient.request(endpoint: "/prompts/check")
            )
            
            if let prompt = response.prompt, !prompt.isEmpty {
                print("📋 Server prompt available: \(prompt.id)")
                serverPrompt = prompt
            }
        } catch {
            // Silent fail - prompts are optional
            print("⚠️ Failed to check server prompts: \(error)")
        }
    }
    
    /// Dismiss a server prompt (tells backend user saw it)
    func dismissServerPrompt(_ prompt: ServerPrompt) {
        serverPrompt = nil
        
        // Tell backend user dismissed it
        Task {
            do {
                let _: EmptyResponse = try await apiClient.execute(
                    apiClient.request(endpoint: "/prompts/dismiss", method: "POST", body: ["prompt_id": prompt.id])
                )
                print("✅ Server prompt dismissed: \(prompt.id)")
            } catch {
                print("⚠️ Failed to dismiss server prompt: \(error)")
            }
        }
    }
}

/// Empty response for endpoints that just return success
private struct EmptyResponse: Codable {
    let success: Bool?
}

// MARK: - Models

struct UserUpdatesResponse: Codable {
    let success: Bool
    let summary: PlayerSummary
    let notifications: [AppNotification]
    let contracts: ContractUpdates
    let kingdoms: [KingdomUpdate]
    let server_time: String
}

struct PlayerSummary: Codable {
    let gold: Int
    let level: Int
    let experience: Int
    let xp_to_next_level: Int
    let skill_points: Int
    let reputation: Int
    let kingdoms_ruled: Int
    let active_contracts: Int
    let ready_contracts: Int
}

struct AppNotification: Codable, Identifiable, Equatable {
    var id: String { "\(type)_\(action_id ?? "none")_\(created_at)" }
    
    let type: String  // contract_ready, level_up, skill_points, coup_new_ruler, etc.
    let priority: String  // high, medium, low, critical
    let title: String
    let message: String
    let action: String  // complete_contract, level_up, view_character, etc.
    let action_id: String?
    let created_at: String
    let show_popup: Bool?  // Backend tells us when to show popup!
    let coup_data: AppCoupData?  // Present for coup notifications
    
    // Display info from backend
    let icon: String?
    let icon_color: String?
    let priority_color: String?
    let border_color: String?
    
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id
    }
}

struct AppCoupData: Codable, Equatable {
    let id: Int
    let kingdom_id: String
    let kingdom_name: String?
    let attacker_victory: Bool?
    let user_won: Bool?
    let gold_per_winner: Int?
    let is_new_ruler: Bool?
    let show_celebration: Bool?  // Legacy - for backwards compat
    
    // Winner rewards
    let rep_gained: Int?
    
    // Loser penalties
    let gold_lost_percent: Int?
    let rep_lost: Int?
    let attack_lost: Int?
    let defense_lost: Int?
    let leadership_lost: Int?
    
    // For lost throne
    let new_ruler_name: String?
}

struct ContractUpdates: Codable {
    let ready_to_complete: [ReadyContract]
    let in_progress: [ProgressContract]
}

struct ReadyContract: Codable, Identifiable {
    let id: Int
    let kingdom_name: String
    let building_type: String
    let building_level: Int
    let reward: Int
}

struct ProgressContract: Codable, Identifiable {
    let id: Int
    let kingdom_name: String
    let building_type: String
    let progress: Double
    let actions_remaining: Int
    let actions_completed: Int
    let total_actions_required: Int
}

struct KingdomUpdate: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let level: Int
    let population: Int
    let treasury: Int
    let open_contracts: Int
}

struct QuickSummary: Codable {
    let ready_contracts: Int
    let active_contracts: Int
    let skill_points: Int
    let unread_notifications: Int
}

