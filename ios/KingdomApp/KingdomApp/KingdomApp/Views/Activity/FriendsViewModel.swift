import Foundation
import SwiftUI
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var friends: [Friend] = []
    @Published var pendingReceived: [Friend] = []
    @Published var pendingSent: [Friend] = []
    @Published var myActivities: [ActivityLogEntry] = []
    @Published var friendActivities: [ActivityLogEntry] = []
    @Published var errorMessage: String?
    
    // Trade offers
    @Published var incomingTrades: [TradeOffer] = []
    @Published var outgoingTrades: [TradeOffer] = []
    @Published var pendingTradeCount: Int = 0
    @Published var hasMerchantSkill: Bool = false
    
    private let api = KingdomAPIService.shared
    
    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.friends.listFriends()
            friends = response.friends.sorted { ($0.isOnline ?? false) && !($1.isOnline ?? false) }
            pendingReceived = response.pendingReceived
            pendingSent = response.pendingSent
            
            print("✅ Loaded \(friends.count) friends, \(pendingReceived.count) requests")
        } catch {
            print("❌ Failed to load friends: \(error)")
            errorMessage = "Failed to load friends"
        }
    }
    
    func acceptFriend(_ friendId: Int) async {
        do {
            _ = try await api.friends.acceptFriendRequest(friendId: friendId)
            print("✅ Accepted friend request")
            await loadFriends()
        } catch {
            print("❌ Failed to accept friend: \(error)")
            errorMessage = "Failed to accept friend request"
        }
    }
    
    func rejectFriend(_ friendId: Int) async {
        do {
            _ = try await api.friends.rejectFriendRequest(friendId: friendId)
            print("✅ Rejected friend request")
            await loadFriends()
        } catch {
            print("❌ Failed to reject friend: \(error)")
            errorMessage = "Failed to reject friend request"
        }
    }
    
    func removeFriend(_ friendId: Int) async {
        do {
            _ = try await api.friends.removeFriend(friendId: friendId)
            print("✅ Removed friend")
            await loadFriends()
        } catch {
            print("❌ Failed to remove friend: \(error)")
            errorMessage = "Failed to remove friend"
        }
    }
    
    func loadMyActivity() async {
        do {
            let response = try await api.friends.getMyActivities(limit: 50, days: 7)
            myActivities = response.activities
            print("✅ Loaded \(myActivities.count) activities")
        } catch {
            print("❌ Failed to load my activity: \(error)")
            // Don't show error to user for activity, just fail silently
        }
    }
    
    func loadFriendActivity() async {
        do {
            let response = try await api.friends.getFriendActivities(limit: 50, days: 7)
            friendActivities = response.activities
            print("✅ Loaded \(friendActivities.count) friend activities")
        } catch {
            print("❌ Failed to load friend activity: \(error)")
            // Don't show error to user for activity, just fail silently
        }
    }
    
    // MARK: - Trade Functions
    
    func loadTrades() async {
        do {
            let response = try await api.trades.listTrades()
            incomingTrades = response.incoming
            outgoingTrades = response.outgoing
            pendingTradeCount = response.incoming.count
            hasMerchantSkill = true
            print("✅ Loaded \(incomingTrades.count) incoming, \(outgoingTrades.count) outgoing trades")
        } catch {
            // Merchant skill not available or other error
            print("❌ Failed to load trades: \(error)")
            hasMerchantSkill = false
        }
    }
    
    func loadPendingTradeCount() async {
        do {
            let response = try await api.trades.getPendingCount()
            pendingTradeCount = response.count
            hasMerchantSkill = response.hasMerchantSkill
        } catch {
            print("❌ Failed to load trade count: \(error)")
        }
    }
    
    func acceptTrade(_ offerId: Int) async {
        do {
            let response = try await api.trades.acceptOffer(offerId: offerId)
            print("✅ Accepted trade: \(response.message)")
            await loadTrades()
        } catch {
            print("❌ Failed to accept trade: \(error)")
            errorMessage = "Failed to accept trade"
        }
    }
    
    func declineTrade(_ offerId: Int) async {
        do {
            _ = try await api.trades.declineOffer(offerId: offerId)
            print("✅ Declined trade")
            await loadTrades()
        } catch {
            print("❌ Failed to decline trade: \(error)")
            errorMessage = "Failed to decline trade"
        }
    }
    
    func cancelTrade(_ offerId: Int) async {
        do {
            _ = try await api.trades.cancelOffer(offerId: offerId)
            print("✅ Cancelled trade")
            await loadTrades()
        } catch {
            print("❌ Failed to cancel trade: \(error)")
            errorMessage = "Failed to cancel trade"
        }
    }
}

