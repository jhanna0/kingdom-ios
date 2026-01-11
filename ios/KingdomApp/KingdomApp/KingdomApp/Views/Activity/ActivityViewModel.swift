import Foundation
import SwiftUI
import Combine

/// Wrapper for opening a battle view from notifications
/// Works for both coups and invasions
struct SelectedBattle: Identifiable {
    let id: Int
    let type: String  // "coup" or "invasion"
    
    var isCoup: Bool { type == "coup" }
    var isInvasion: Bool { type == "invasion" }
}

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var notifications: [ActivityNotification] = []
    @Published var selectedBattle: SelectedBattle?
    @Published var errorMessage: String?
    @Published var unreadKingdomEvents: Int = 0
    
    // Backwards compat - maps to selectedBattle for coup notifications
    var selectedCoup: CoupNotificationData? {
        get { nil }  // Not used for reading anymore
        set {
            if let data = newValue {
                selectedBattle = SelectedBattle(id: data.id, type: "coup")
            } else {
                selectedBattle = nil
            }
        }
    }
    
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
        
        // Coup notifications - show battle view
        if type.hasPrefix("coup_") {
            if let coupData = notification.coupData {
                // Open battle view for the coup
                selectedBattle = SelectedBattle(id: coupData.id, type: "coup")
            }
            return
        }
        
        // Invasion notifications - show battle view
        if type.hasPrefix("invasion_") {
            if let invasionData = notification.invasionData {
                // Open battle view for the invasion
                selectedBattle = SelectedBattle(id: invasionData.id, type: "invasion")
            }
            return
        }
        
        // Battle notifications (unified) - show battle view
        if type.hasPrefix("battle_") {
            // Try coup data first, then invasion data
            if let coupData = notification.coupData {
                selectedBattle = SelectedBattle(id: coupData.id, type: "coup")
            } else if let invasionData = notification.invasionData {
                selectedBattle = SelectedBattle(id: invasionData.id, type: "invasion")
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
    
    func voteBattle(_ battleId: Int, side: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Call battle join API (unified for coups and invasions)
            let response = try await api.actions.joinCoup(coupId: battleId, side: side)
            
            print("✅ Voted in battle: \(response.message)")
            
            // Dismiss sheet
            selectedBattle = nil
            
            // Refresh activity to update notifications
            await loadActivity()
            
        } catch {
            print("❌ Failed to vote in battle: \(error)")
            errorMessage = "Failed to vote in battle"
        }
    }
    
    // Backwards compat alias
    func voteCoup(_ coupId: Int, side: String) async {
        await voteBattle(coupId, side: side)
    }
}

