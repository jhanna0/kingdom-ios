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
    @Published var tradeHistory: [TradeOffer] = []
    @Published var pendingTradeCount: Int = 0
    @Published var hasMerchantSkill: Bool = false
    
    // Alliances
    @Published var activeAlliances: [AllianceResponse] = []
    @Published var pendingAlliancesSent: [AllianceResponse] = []
    @Published var pendingAlliancesReceived: [AllianceResponse] = []
    @Published var isRuler: Bool = false
    
    // Duel challenges
    @Published var incomingDuelChallenges: [DuelInvitation] = []
    @Published var pendingDuelCount: Int = 0
    
    private let api = KingdomAPIService.shared
    private let duelsApi = DuelsAPI()
    
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
            tradeHistory = response.history
            pendingTradeCount = response.incoming.count
            hasMerchantSkill = true
            print("✅ Loaded \(incomingTrades.count) incoming, \(outgoingTrades.count) outgoing, \(tradeHistory.count) history trades")
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
    
    // MARK: - Alliance Functions
    
    func loadAlliances() async {
        do {
            // Load active alliances
            let activeResponse = try await APIClient.shared.getActiveAlliances()
            activeAlliances = activeResponse.alliances
            isRuler = !activeResponse.alliances.isEmpty || true // Will be set properly
            
            // Load pending alliances
            let pendingResponse = try await APIClient.shared.getPendingAlliances()
            pendingAlliancesSent = pendingResponse.sent
            pendingAlliancesReceived = pendingResponse.received
            isRuler = pendingResponse.sentCount > 0 || pendingResponse.receivedCount > 0 || !activeAlliances.isEmpty
            
            print("✅ Loaded \(activeAlliances.count) active alliances, \(pendingAlliancesSent.count) sent, \(pendingAlliancesReceived.count) received")
        } catch {
            print("❌ Failed to load alliances: \(error)")
            // Not a ruler or error - just don't show alliance section
            isRuler = false
        }
    }
    
    func acceptAlliance(_ allianceId: Int) async {
        do {
            let response = try await APIClient.shared.acceptAlliance(allianceId: allianceId)
            print("✅ Accepted alliance: \(response.message)")
            await loadAlliances()
        } catch {
            print("❌ Failed to accept alliance: \(error)")
            errorMessage = "Failed to accept alliance"
        }
    }
    
    func declineAlliance(_ allianceId: Int) async {
        do {
            let response = try await APIClient.shared.declineAlliance(allianceId: allianceId)
            print("✅ Declined alliance: \(response.message)")
            await loadAlliances()
        } catch {
            print("❌ Failed to decline alliance: \(error)")
            errorMessage = "Failed to decline alliance"
        }
    }
    
    // MARK: - Duel Challenge Functions
    
    func loadDuelChallenges() async {
        do {
            let response = try await duelsApi.getInvitations()
            incomingDuelChallenges = response.invitations
            pendingDuelCount = response.invitations.count
            print("✅ Loaded \(incomingDuelChallenges.count) duel challenges")
        } catch {
            print("❌ Failed to load duel challenges: \(error)")
            // Don't show error to user, just fail silently
        }
    }
    
    func acceptDuelChallenge(_ invitationId: Int) async {
        do {
            let response = try await duelsApi.acceptInvitation(invitationId: invitationId)
            print("✅ Accepted duel challenge: \(response.message)")
            await loadDuelChallenges()
        } catch {
            print("❌ Failed to accept duel challenge: \(error)")
            errorMessage = "Failed to accept challenge"
        }
    }
    
    func declineDuelChallenge(_ invitationId: Int) async {
        do {
            _ = try await duelsApi.declineInvitation(invitationId: invitationId)
            print("✅ Declined duel challenge")
            await loadDuelChallenges()
        } catch {
            print("❌ Failed to decline duel challenge: \(error)")
            errorMessage = "Failed to decline challenge"
        }
    }
}

