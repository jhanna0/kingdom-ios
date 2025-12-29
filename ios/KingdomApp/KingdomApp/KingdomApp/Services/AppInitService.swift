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
    
    private let apiClient = APIClient.shared
    
    // MARK: - Initialization
    
    /// Load all user data when app starts
    @MainActor
    func initialize() async {
        guard apiClient.isAuthenticated else {
            print("⚠️ AppInitService: Not authenticated, skipping init")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all updates from backend
            let updates: UserUpdatesResponse = try await apiClient.execute(
                apiClient.request(endpoint: "/notifications/updates")
            )
            
            // Update state
            playerSummary = updates.summary
            notifications = updates.notifications
            unreadCount = updates.notifications.filter { $0.priority == "high" }.count
            
            // Log what we found
            print("✅ AppInitService: Loaded user data")
            print("   - Level: \(updates.summary.level)")
            print("   - Gold: \(updates.summary.gold)")
            print("   - Ready contracts: \(updates.summary.ready_contracts)")
            print("   - Notifications: \(notifications.count)")
            
            // Show important notifications
            await showImportantNotifications(updates.notifications)
            
        } catch {
            errorMessage = "Failed to load user data: \(error.localizedDescription)"
            print("❌ AppInitService error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refresh data (called periodically or on app foreground)
    @MainActor
    func refresh() async {
        await initialize()
    }
    
    // MARK: - Notifications
    
    @MainActor
    private func showImportantNotifications(_ notifications: [AppNotification]) async {
        // Show high priority notifications as alerts/toasts
        let highPriority = notifications.filter { $0.priority == "high" }
        
        for notification in highPriority {
            print("🔔 \(notification.title): \(notification.message)")
            // TODO: Show as toast/banner in UI
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
    
    let type: String  // contract_ready, level_up, skill_points, etc.
    let priority: String  // high, medium, low
    let title: String
    let message: String
    let action: String  // complete_contract, level_up, view_character, etc.
    let action_id: String?
    let created_at: String
    
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id
    }
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

struct KingdomUpdate: Codable, Identifiable {
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

