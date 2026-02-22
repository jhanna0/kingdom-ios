import Foundation
import SwiftUI

// MARK: - Server-Driven Subscriber Customization

/// Achievement title data from server
struct APITitleData: Codable {
    let achievementId: Int
    let displayName: String
    let icon: String
    
    enum CodingKeys: String, CodingKey {
        case achievementId = "achievement_id"
        case displayName = "display_name"
        case icon
    }
}

/// Style preset (background + text color combo)
struct APIStylePreset: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let backgroundColor: String  // hex
    let textColor: String        // hex
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case backgroundColor = "background_color"
        case textColor = "text_color"
    }
    
    var backgroundColorValue: Color {
        Color(hex: backgroundColor) ?? .gray
    }
    
    var textColorValue: Color {
        Color(hex: textColor) ?? .white
    }
}

/// Subscriber customization (style presets)
struct APISubscriberCustomization: Codable {
    let iconStyle: APIStylePreset?
    let cardStyle: APIStylePreset?
    let selectedTitle: APITitleData?
    
    enum CodingKeys: String, CodingKey {
        case iconStyle = "icon_style"
        case cardStyle = "card_style"
        case selectedTitle = "selected_title"
    }
    
    // Convenience computed properties for backwards compatibility
    // Default colors match the parchment/ink theme
    var iconBackgroundColorValue: Color {
        iconStyle?.backgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    var iconTextColorValue: Color {
        iconStyle?.textColorValue ?? KingdomTheme.Colors.inkDark
    }
    
    var cardBackgroundColorValue: Color {
        cardStyle?.backgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    var cardTextColorValue: Color {
        cardStyle?.textColorValue ?? KingdomTheme.Colors.inkDark
    }
}

// MARK: - Friend Models

struct Friend: Codable, Identifiable {
    let id: Int
    let userId: Int
    let friendUserId: Int
    let friendUsername: String
    let friendDisplayName: String
    let status: FriendshipStatus
    let createdAt: String
    let updatedAt: String
    
    // Activity data (if accepted)
    let isOnline: Bool?
    let level: Int?
    let currentKingdomId: String?
    let currentKingdomName: String?
    let lastSeen: String?
    let activity: FriendActivity?
    
    // Subscriber customization (server-driven)
    let subscriberCustomization: APISubscriberCustomization?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendUserId = "friend_user_id"
        case friendUsername = "friend_username"
        case friendDisplayName = "friend_display_name"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isOnline = "is_online"
        case level
        case currentKingdomId = "current_kingdom_id"
        case currentKingdomName = "current_kingdom_name"
        case lastSeen = "last_seen"
        case activity
        case subscriberCustomization = "subscriber_customization"
    }
    
    var displayName: String {
        friendDisplayName
    }
    
    var isAccepted: Bool {
        status == .accepted
    }
}

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case blocked
}

struct FriendActivity: Codable {
    let icon: String
    let displayText: String
    let color: String
    
    enum CodingKeys: String, CodingKey {
        case icon
        case displayText = "display_text"
        case color
    }
}

// MARK: - API Request/Response Models

struct FriendRequest: Codable {
    let username: String?
    let userId: Int?
    
    enum CodingKeys: String, CodingKey {
        case username
        case userId = "user_id"
    }
}

struct FriendListResponse: Codable {
    let success: Bool
    let friends: [Friend]
    let pendingReceived: [Friend]
    let pendingSent: [Friend]
    
    enum CodingKeys: String, CodingKey {
        case success
        case friends
        case pendingReceived = "pending_received"
        case pendingSent = "pending_sent"
    }
}

/// Consolidated response for FriendsView - all data in one API call
struct FriendsDashboardResponse: Codable {
    let success: Bool
    // Friends
    let friends: [Friend]
    let pendingReceived: [Friend]
    let pendingSent: [Friend]
    // Trades
    let incomingTrades: [TradeOffer]
    let outgoingTrades: [TradeOffer]
    let tradeHistory: [TradeOffer]
    let hasMerchantSkill: Bool
    // Alliances
    let pendingAlliancesSent: [AllianceResponse]
    let pendingAlliancesReceived: [AllianceResponse]
    let isRuler: Bool
    // Friend Activity
    let friendActivities: [ActivityLogEntry]
    
    enum CodingKeys: String, CodingKey {
        case success
        case friends
        case pendingReceived = "pending_received"
        case pendingSent = "pending_sent"
        case incomingTrades = "incoming_trades"
        case outgoingTrades = "outgoing_trades"
        case tradeHistory = "trade_history"
        case hasMerchantSkill = "has_merchant_skill"
        case pendingAlliancesSent = "pending_alliances_sent"
        case pendingAlliancesReceived = "pending_alliances_received"
        case isRuler = "is_ruler"
        case friendActivities = "friend_activities"
    }
}

struct AddFriendResponse: Codable {
    let success: Bool
    let message: String
    let friend: Friend?
}

struct FriendActionResponse: Codable {
    let success: Bool
    let message: String
}

struct SearchUsersResponse: Codable {
    let success: Bool
    let users: [UserSearchResult]
}

struct UserSearchResult: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let level: Int
    let friendshipStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case level
        case friendshipStatus = "friendship_status"
    }
}

