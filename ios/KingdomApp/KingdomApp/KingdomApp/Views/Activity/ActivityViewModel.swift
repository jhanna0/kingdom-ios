import Foundation
import SwiftUI
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var notifications: [ActivityNotification] = []
    @Published var selectedCoup: CoupNotificationData?
    @Published var errorMessage: String?
    
    private let api = KingdomAPIService.shared
    
    func loadActivity() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.notifications.getUpdates()
            notifications = response.notifications
            
            print("✅ Loaded \(notifications.count) activity events")
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
        
        switch notification.type {
        case .coupVoteNeeded, .coupInProgress, .coupAgainstYou:
            // Show coup voting sheet
            if let coupData = notification.coupData {
                selectedCoup = coupData
            }
            
        case .coupResolved:
            // Show coup results
            if let coupData = notification.coupData {
                // TODO: Show results modal
                print("Coup resolved: \(coupData)")
            }
            
        case .invasionAgainstYou, .allyUnderAttack, .invasionDefenseNeeded, .invasionInProgress:
            // Show invasion details
            if let invasionData = notification.invasionData {
                // TODO: Show invasion join sheet
                print("Invasion notification: \(invasionData)")
            }
            
        case .invasionResolved:
            // Show invasion results
            if let invasionData = notification.invasionData {
                // TODO: Show results modal
                print("Invasion resolved: \(invasionData)")
            }
            
        case .contractReady:
            // TODO: Navigate to contract completion
            print("Navigate to contract: \(notification.actionId ?? "unknown")")
            
        case .levelUp:
            // TODO: Navigate to character sheet
            print("Navigate to character sheet")
            
        case .skillPoints:
            // TODO: Navigate to character sheet
            print("Navigate to character sheet")
            
        case .checkinReady:
            // TODO: Navigate to map/kingdom
            print("Navigate to check-in")
            
        case .treasuryFull:
            // TODO: Navigate to kingdom management
            print("Navigate to kingdom: \(notification.actionId ?? "unknown")")
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

