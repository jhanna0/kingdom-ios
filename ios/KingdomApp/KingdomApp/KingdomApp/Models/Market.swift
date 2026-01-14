import Foundation

// MARK: - Enums

enum OrderType: String, Codable, CaseIterable {
    case buy = "buy"
    case sell = "sell"
}

enum OrderStatus: String, Codable {
    case active = "active"
    case filled = "filled"
    case partiallyFilled = "partially_filled"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .filled: return "Filled"
        case .partiallyFilled: return "Partially Filled"
        case .cancelled: return "Cancelled"
        }
    }
}

// ItemType is now dynamic - fetched from /market/available-items
// No more hardcoded enum! Use MarketItem for display properties.
typealias ItemType = String

// MARK: - Dynamic Item Config (from /market/available-items)

struct MarketItem: Codable, Identifiable, Hashable {
    var id: String { itemId }
    let itemId: String
    let displayName: String
    let icon: String        // SF Symbol name
    let color: String       // SwiftUI color name
    let description: String
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case itemId = "id"
        case displayName = "display_name"
        case icon
        case color
        case description
        case category
    }
}

struct AvailableItemsResponse: Codable {
    let items: [MarketItem]
}

// MARK: - Models

struct MarketOrder: Codable, Identifiable {
    let id: Int
    let playerId: Int
    let kingdomId: String
    let orderType: OrderType
    let itemType: ItemType
    let pricePerUnit: Int
    let quantityRemaining: Int
    let quantityOriginal: Int
    let status: OrderStatus
    let createdAt: Date
    let updatedAt: Date
    let filledAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case playerId = "player_id"
        case kingdomId = "kingdom_id"
        case orderType = "order_type"
        case itemType = "item_type"
        case pricePerUnit = "price_per_unit"
        case quantityRemaining = "quantity_remaining"
        case quantityOriginal = "quantity_original"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case filledAt = "filled_at"
    }
}

struct MarketTransaction: Codable, Identifiable {
    let id: Int
    let kingdomId: String
    let itemType: ItemType
    let buyerId: Int
    let sellerId: Int
    let quantity: Int
    let pricePerUnit: Int
    let totalGold: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case kingdomId = "kingdom_id"
        case itemType = "item_type"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case quantity
        case pricePerUnit = "price_per_unit"
        case totalGold = "total_gold"
        case createdAt = "created_at"
    }
}

struct OrderBookEntry: Codable {
    let pricePerUnit: Int
    let totalQuantity: Int
    let numOrders: Int
    
    enum CodingKeys: String, CodingKey {
        case pricePerUnit = "price_per_unit"
        case totalQuantity = "total_quantity"
        case numOrders = "num_orders"
    }
}

struct OrderBook: Codable {
    let itemType: ItemType
    let kingdomId: String
    let buyOrders: [OrderBookEntry]
    let sellOrders: [OrderBookEntry]
    let highestBuyOffer: Int?
    let lowestSellOffer: Int?
    let spread: Int?
    
    enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case kingdomId = "kingdom_id"
        case buyOrders = "buy_orders"
        case sellOrders = "sell_orders"
        case highestBuyOffer = "highest_buy_offer"
        case lowestSellOffer = "lowest_sell_offer"
        case spread
    }
}

struct PriceHistoryEntry: Codable, Identifiable {
    var id: String { "\(timestamp)-\(price)" }
    let timestamp: Date
    let price: Int
    let quantity: Int
}

struct PriceHistory: Codable {
    let itemType: ItemType
    let kingdomId: String
    let transactions: [PriceHistoryEntry]
    let averagePrice: Double?
    let minPrice: Int?
    let maxPrice: Int?
    let totalVolume: Int
    
    enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case kingdomId = "kingdom_id"
        case transactions
        case averagePrice = "average_price"
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case totalVolume = "total_volume"
    }
}

struct CreateOrderResult: Codable {
    let orderCreated: Bool
    let order: MarketOrder?
    let instantMatches: [MarketTransaction]
    let totalQuantityFilled: Int
    let totalGoldExchanged: Int
    let fullyFilled: Bool
    let partiallyFilled: Bool
    let quantityRemaining: Int
    
    enum CodingKeys: String, CodingKey {
        case orderCreated = "order_created"
        case order
        case instantMatches = "instant_matches"
        case totalQuantityFilled = "total_quantity_filled"
        case totalGoldExchanged = "total_gold_exchanged"
        case fullyFilled = "fully_filled"
        case partiallyFilled = "partially_filled"
        case quantityRemaining = "quantity_remaining"
    }
}

struct PlayerOrdersResponse: Codable {
    let activeOrders: [MarketOrder]
    let recentFilled: [MarketOrder]
    let recentTransactions: [MarketTransaction]
    
    enum CodingKeys: String, CodingKey {
        case activeOrders = "active_orders"
        case recentFilled = "recent_filled"
        case recentTransactions = "recent_transactions"
    }
}

struct MarketInfo: Codable {
    let kingdomId: String
    let kingdomName: String
    let marketLevel: Int
    let canAccessMarket: Bool  // Requires home kingdom OR Merchant tier 3+
    let availableItems: [ItemType]
    let message: String?
    let playerGold: Int
    let playerResources: [String: Int]
    let totalActiveOrders: Int
    let totalTransactions24h: Int
    
    enum CodingKeys: String, CodingKey {
        case kingdomId = "kingdom_id"
        case kingdomName = "kingdom_name"
        case marketLevel = "market_level"
        case canAccessMarket = "can_access_market"
        case availableItems = "available_items"
        case message
        case playerGold = "player_gold"
        case playerResources = "player_resources"
        case totalActiveOrders = "total_active_orders"
        case totalTransactions24h = "total_transactions_24h"
    }
}

// MARK: - Request Bodies

struct CreateOrderRequest: Codable {
    let orderType: OrderType
    let itemType: ItemType
    let pricePerUnit: Int
    let quantity: Int
    
    enum CodingKeys: String, CodingKey {
        case orderType = "order_type"
        case itemType = "item_type"
        case pricePerUnit = "price_per_unit"
        case quantity
    }
}

