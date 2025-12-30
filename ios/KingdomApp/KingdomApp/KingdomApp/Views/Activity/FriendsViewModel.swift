import Foundation
import SwiftUI
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var friends: [Friend] = []
    @Published var pendingReceived: [Friend] = []
    @Published var pendingSent: [Friend] = []
    @Published var errorMessage: String?
    
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
}

