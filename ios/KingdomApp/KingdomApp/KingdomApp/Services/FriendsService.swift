import Foundation

class FriendsService {
    private let client = APIClient.shared
    
    // MARK: - List Friends
    
    func listFriends() async throws -> FriendListResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/friends/list")
        return try await client.execute(request)
    }
    
    // MARK: - Add Friend
    
    func addFriend(username: String) async throws -> AddFriendResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = FriendRequest(username: username, userId: nil)
        let request = try client.request(endpoint: "/friends/add", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    func addFriend(userId: Int) async throws -> AddFriendResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = FriendRequest(username: nil, userId: userId)
        let request = try client.request(endpoint: "/friends/add", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Accept Friend Request
    
    func acceptFriendRequest(friendId: Int) async throws -> FriendActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/friends/\(friendId)/accept", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Reject Friend Request
    
    func rejectFriendRequest(friendId: Int) async throws -> FriendActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/friends/\(friendId)/reject", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(friendId: Int) async throws -> FriendActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/friends/\(friendId)", method: "DELETE")
        return try await client.execute(request)
    }
    
    // MARK: - Search Users
    
    func searchUsers(query: String) async throws -> SearchUsersResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let request = client.request(endpoint: "/friends/search?query=\(encodedQuery)")
        return try await client.execute(request)
    }
}

