import Foundation

// MARK: - Trade Offer Models

struct TradeOffer: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let senderName: String
    let recipientId: Int
    let recipientName: String
    let offerType: String  // "item" or "gold"
    let itemType: String?
    let itemDisplayName: String?
    let itemIcon: String?
    let itemQuantity: Int?
    let goldAmount: Int
    let status: TradeOfferStatus
    let message: String?
    let createdAt: String
    let expiresAt: String
    let isIncoming: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case senderName = "sender_name"
        case recipientId = "recipient_id"
        case recipientName = "recipient_name"
        case offerType = "offer_type"
        case itemType = "item_type"
        case itemDisplayName = "item_display_name"
        case itemIcon = "item_icon"
        case itemQuantity = "item_quantity"
        case goldAmount = "gold_amount"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isIncoming = "is_incoming"
    }
    
    /// Description of what's being offered
    var offerDescription: String {
        if offerType == "gold" {
            return "\(goldAmount)g"
        } else if let itemName = itemDisplayName, let qty = itemQuantity {
            if goldAmount > 0 {
                return "\(qty) \(itemName) for \(goldAmount)g"
            } else {
                return "\(qty) \(itemName) (gift)"
            }
        }
        return "Unknown offer"
    }
    
    /// Time remaining until expiry
    var timeRemaining: String {
        // Parse ISO date string and calculate time remaining
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try with fractional seconds first, then without
        if let date = formatter.date(from: expiresAt) {
            return TimeFormatter.timeAgo(from: date)
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: expiresAt) {
            return TimeFormatter.timeAgo(from: date)
        }
        
        return "Unknown"
    }
}

enum TradeOfferStatus: String, Codable {
    case pending
    case accepted
    case declined
    case cancelled
    case expired
}

// MARK: - API Request Models

struct CreateTradeOfferRequest: Codable {
    let recipientId: Int
    let offerType: String
    let itemType: String?
    let itemQuantity: Int?
    let goldAmount: Int
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case recipientId = "recipient_id"
        case offerType = "offer_type"
        case itemType = "item_type"
        case itemQuantity = "item_quantity"
        case goldAmount = "gold_amount"
        case message
    }
}

// MARK: - API Response Models

struct TradeListResponse: Codable {
    let success: Bool
    let incoming: [TradeOffer]
    let outgoing: [TradeOffer]
    let history: [TradeOffer]
}

struct TradeActionResponse: Codable {
    let success: Bool
    let message: String
    let goldExchanged: Int?
    let itemExchanged: String?
    let itemQuantity: Int?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case goldExchanged = "gold_exchanged"
        case itemExchanged = "item_exchanged"
        case itemQuantity = "item_quantity"
    }
}

struct TradePendingCountResponse: Codable {
    let count: Int
    let hasMerchantSkill: Bool
    
    enum CodingKeys: String, CodingKey {
        case count
        case hasMerchantSkill = "has_merchant_skill"
    }
}

struct TradeableItem: Codable, Identifiable {
    let itemId: String
    let displayName: String
    let icon: String
    let color: String
    let quantity: Int
    
    var id: String { itemId }
    
    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case displayName = "display_name"
        case icon
        case color
        case quantity
    }
}

struct TradeableItemsResponse: Codable {
    let success: Bool
    let items: [TradeableItem]
    let gold: Int
}
