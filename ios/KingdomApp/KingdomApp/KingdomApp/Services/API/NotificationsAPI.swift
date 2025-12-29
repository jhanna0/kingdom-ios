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
}

struct NotificationSummary: Codable {
    let readyContracts: Int
    let activeContracts: Int
    let skillPoints: Int
    let unreadNotifications: Int
    
    enum CodingKeys: String, CodingKey {
        case readyContracts = "ready_contracts"
        case activeContracts = "active_contracts"
        case skillPoints = "skill_points"
        case unreadNotifications = "unread_notifications"
    }
}

