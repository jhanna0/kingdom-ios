import Foundation

/// Trades API - Player-to-player trading (Merchant skill required)
class TradesAPI {
    private let client = APIClient.shared
    
    // MARK: - List Trades
    
    /// Get all trade offers (incoming, outgoing, history)
    func listTrades() async throws -> TradeListResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/trades/list")
        return try await client.execute(request)
    }
    
    /// Get count of pending incoming trade offers (for badge)
    func getPendingCount() async throws -> TradePendingCountResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/trades/pending-count")
        return try await client.execute(request)
    }
    
    // MARK: - Create Trade Offer
    
    /// Create a new trade offer to a friend
    func createOffer(
        recipientId: Int,
        offerType: String,
        itemType: String?,
        itemQuantity: Int?,
        goldAmount: Int,
        message: String?
    ) async throws -> TradeActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let body = CreateTradeOfferRequest(
            recipientId: recipientId,
            offerType: offerType,
            itemType: itemType,
            itemQuantity: itemQuantity,
            goldAmount: goldAmount,
            message: message
        )
        
        let request = try client.request(endpoint: "/trades/create", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    /// Create an item offer (shorthand)
    func offerItem(
        to recipientId: Int,
        itemType: String,
        quantity: Int,
        price: Int,
        message: String? = nil
    ) async throws -> TradeActionResponse {
        return try await createOffer(
            recipientId: recipientId,
            offerType: "item",
            itemType: itemType,
            itemQuantity: quantity,
            goldAmount: price,
            message: message
        )
    }
    
    /// Send gold to a friend (shorthand)
    func sendGold(
        to recipientId: Int,
        amount: Int,
        message: String? = nil
    ) async throws -> TradeActionResponse {
        return try await createOffer(
            recipientId: recipientId,
            offerType: "gold",
            itemType: nil,
            itemQuantity: nil,
            goldAmount: amount,
            message: message
        )
    }
    
    // MARK: - Respond to Trade Offers
    
    /// Accept a trade offer
    func acceptOffer(offerId: Int) async throws -> TradeActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/trades/\(offerId)/accept", method: "POST")
        return try await client.execute(request)
    }
    
    /// Decline a trade offer
    func declineOffer(offerId: Int) async throws -> TradeActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/trades/\(offerId)/decline", method: "POST")
        return try await client.execute(request)
    }
    
    /// Cancel a trade offer you sent
    func cancelOffer(offerId: Int) async throws -> TradeActionResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/trades/\(offerId)/cancel", method: "POST")
        return try await client.execute(request)
    }
    
    // MARK: - Get Tradeable Items
    
    /// Get items the player can trade (with quantities)
    func getTradeableItems() async throws -> TradeableItemsResponse {
        guard client.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        let request = client.request(endpoint: "/trades/tradeable-items")
        return try await client.execute(request)
    }
}
