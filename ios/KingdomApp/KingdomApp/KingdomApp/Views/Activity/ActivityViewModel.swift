import Foundation
import SwiftUI
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var notifications: [ActivityNotification] = []
    @Published var selectedCoup: CoupNotificationData?
    @Published var errorMessage: String?
    @Published var unreadKingdomEvents: Int = 0
    
    private let api = KingdomAPIService.shared
    
    func loadActivity() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.notifications.getUpdates()
            notifications = response.notifications
            unreadKingdomEvents = response.unreadKingdomEvents ?? 0
            
            print("✅ Loaded \(notifications.count) activity events, \(unreadKingdomEvents) unread")
        } catch {
            print("❌ Failed to load activity: \(error)")
            errorMessage = "Failed to load activity"
        }
    }
    
    func refresh() async {
        await loadActivity()
    }
    
    func handleNotificationTap(_ notification: ActivityNotification) {
        print("📱 Tapped notification: \(notification.type)")
        
        // Use string prefix matching instead of enum switch - backend controls types!
        let type = notification.type
        
        // Coup notifications - show coup view
        if type.hasPrefix("coup_") {
            if let coupData = notification.coupData {
                // For active coups, show the coup view
                // For resolved coups, the notification already has all the info
                selectedCoup = coupData
            }
            return
        }
        
        // Invasion notifications
        if type.hasPrefix("invasion_") {
            if let invasionData = notification.invasionData {
                print("Invasion notification: \(invasionData)")
            }
            return
        }
        
        // Alliance notifications
        if type.hasPrefix("alliance_") {
            if let allianceData = notification.allianceData {
                print("Alliance notification: \(allianceData)")
            }
            return
        }
        
        // Other specific types (legacy support)
        if type == "contract_ready" {
            print("Navigate to contract: \(notification.actionId ?? "unknown")")
        } else if type == "level_up" || type == "skill_points" {
            print("Navigate to character sheet")
        } else if type == "checkin_ready" {
            print("Navigate to check-in")
        } else if type == "treasury_full" {
            print("Navigate to kingdom: \(notification.actionId ?? "unknown")")
        } else if type == "kingdom_event" {
            // Just informational, no action
        } else {
            print("Unknown notification type: \(type)")
        }
    }
    
    func voteCoup(_ coupId: Int, side: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Call coup join API
            let response = try await api.actions.joinCoup(coupId: coupId, side: side)
            
            print("✅ Voted in coup: \(response.message)")
            
            // Dismiss sheet
            selectedCoup = nil
            
            // Refresh activity to update notifications
            await loadActivity()
            
        } catch {
            print("❌ Failed to vote in coup: \(error)")
            errorMessage = "Failed to vote in coup"
        }
    }
}

