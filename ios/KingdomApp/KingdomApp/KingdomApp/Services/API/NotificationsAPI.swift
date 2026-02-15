import Foundation

class NotificationsAPI {
    private let client: APIClient
    
    init(client: APIClient) {
        self.client = client
    }
    
    /// Get all activity updates (notifications, contracts, kingdoms, etc.)
    func getUpdates() async throws -> ActivityResponse {
        let request = client.request(endpoint: "/notifications/updates", method: "GET")
        return try await client.execute(request)
    }
    
    /// Get quick summary (for badges)
    func getSummary() async throws -> NotificationSummary {
        let request = client.request(endpoint: "/notifications/summary", method: "GET")
        return try await client.execute(request)
    }
    
    /// Mark all notifications as read
    func markRead() async throws {
        let request = client.request(endpoint: "/notifications/mark-read", method: "POST")
        let _: MarkReadResponse = try await client.execute(request)
    }
}

struct NotificationSummary: Codable {
    let hasUnread: Bool
    let pendingFriendRequests: Int
    let pendingAllianceRequests: Int
    let pendingTradeRequests: Int
    let pendingDuelRequests: Int
    let propertyBadgeCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case hasUnread = "has_unread"
        case pendingFriendRequests = "pending_friend_requests"
        case pendingAllianceRequests = "pending_alliance_requests"
        case pendingTradeRequests = "pending_trade_requests"
        case pendingDuelRequests = "pending_duel_requests"
        case propertyBadgeCount = "property_badge_count"
    }
}

struct MarkReadResponse: Codable {
    let success: Bool
}

