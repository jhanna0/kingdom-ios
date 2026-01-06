import Foundation

/// Market API - Grand Exchange style trading
class MarketAPI {
    private let client = APIClient.shared
    
    // MARK: - Market Info
    
    /// Get market information for current kingdom
    func getMarketInfo() async throws -> MarketInfo {
        let request = client.request(endpoint: "/market/info")
        return try await client.execute(request)
    }
    
    // MARK: - Orders
    
    /// Create a new buy or sell order
    func createOrder(
        orderType: OrderType,
        itemType: ItemType,
        pricePerUnit: Int,
        quantity: Int
    ) async throws -> CreateOrderResult {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = CreateOrderRequest(
            orderType: orderType,
            itemType: itemType,
            pricePerUnit: pricePerUnit,
            quantity: quantity
        )
        
        let request = try client.request(endpoint: "/market/orders", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    /// Get a specific order by ID
    func getOrder(id: Int) async throws -> MarketOrder {
        let request = client.request(endpoint: "/market/orders/\(id)")
        return try await client.execute(request)
    }
    
    /// Cancel an active order
    func cancelOrder(id: Int) async throws {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/market/orders/\(id)", method: "DELETE")
        try await client.executeVoid(request)
    }
    
    /// Get player's orders and transactions
    func getMyOrders() async throws -> PlayerOrdersResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/market/my-orders")
        return try await client.execute(request)
    }
    
    // MARK: - Order Book
    
    /// Get order book for an item (buy/sell orders at each price)
    func getOrderBook(itemType: ItemType) async throws -> OrderBook {
        let request = client.request(endpoint: "/market/orderbook/\(itemType.rawValue)")
        return try await client.execute(request)
    }
    
    // MARK: - Price History
    
    /// Get price history for an item
    func getPriceHistory(itemType: ItemType, hours: Int = 24) async throws -> PriceHistory {
        let request = client.request(endpoint: "/market/history/\(itemType.rawValue)?hours=\(hours)")
        return try await client.execute(request)
    }
    
    // MARK: - Recent Trades
    
    /// Get recent trades in the kingdom
    func getRecentTrades(itemType: ItemType? = nil, limit: Int = 50) async throws -> [MarketTransaction] {
        var endpoint = "/market/recent-trades?limit=\(limit)"
        if let itemType = itemType {
            endpoint += "&item_type=\(itemType.rawValue)"
        }
        
        let request = client.request(endpoint: endpoint)
        return try await client.execute(request)
    }
}

