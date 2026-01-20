import Foundation
import SwiftUI
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var notifications: [ActivityNotification] = []
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
}
