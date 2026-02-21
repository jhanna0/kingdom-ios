import Foundation
import StoreKit
import Combine

/// StoreKit 2 service for in-app purchases (Apple Pay)
/// Handles product loading, purchasing, and server verification
@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()
    
    // MARK: - Published State
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var subscriptionProducts: [Product] = []  // Subscription products
    @Published private(set) var productConfigs: [String: ServerProduct] = [:]  // Server-side product info
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastPurchaseResult: PurchaseResult?
    @Published private(set) var isSubscriber: Bool? = nil  // nil = loading, true/false = confirmed
    
    /// Server-side product configuration
    struct ServerProduct: Decodable {
        let id: String
        let name: String
        let type: String?
        let gold: Int
        let meat: Int
        let books: Int
        let price_usd: Double
        let icon: String
        let color: String
        // Subscription-specific fields (server-driven)
        let subtitle: String?
        let subscriptionDescription: String?
        let benefits: [String]?
        
        enum CodingKeys: String, CodingKey {
            case id, name, type, gold, meat, books, price_usd, icon, color
            case subtitle
            case subscriptionDescription = "description"
            case benefits
        }
        
        var description: String {
            var parts: [String] = []
            if gold > 0 { parts.append("\(gold.formatted()) Gold") }
            if meat > 0 { parts.append("\(meat.formatted()) Meat") }
            if books > 0 { parts.append("\(books) Book\(books == 1 ? "" : "s")") }
            return parts.joined(separator: " + ")
        }
    }
    
    enum PurchaseResult {
        case success(gold: Int, meat: Int)
        case cancelled
        case pending
        case failed(String)
    }
    
    // MARK: - Private
    
    private var updateListenerTask: Task<Void, Error>?
    private let client = APIClient.shared
    
    // MARK: - Initialization
    
    private init() {
        // Start listening for transactions (handles interrupted purchases, Ask to Buy, etc.)
        updateListenerTask = listenForTransactions()
        
        // Load products on init
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    /// Load products - fetches config from server, then prices from App Store
    func loadProducts() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch product config from our server (source of truth for what's available)
            let serverProducts = try await fetchServerProducts()
            
            // Store server configs for display info
            productConfigs = Dictionary(uniqueKeysWithValues: serverProducts.map { ($0.id, $0) })
            
            // 2. Get prices from App Store using server-provided IDs
            let productIDs = serverProducts.map { $0.id }
            let storeProducts = try await Product.products(for: Set(productIDs))
            
            // Separate consumables and subscriptions
            var consumables: [Product] = []
            var subscriptions: [Product] = []
            
            for product in storeProducts {
                if product.type == .autoRenewable {
                    subscriptions.append(product)
                } else {
                    consumables.append(product)
                }
            }
            
            // Sort by price
            products = consumables.sorted { $0.price < $1.price }
            subscriptionProducts = subscriptions.sorted { $0.price < $1.price }
            
            print("🛒 Loaded \(products.count) consumables and \(subscriptionProducts.count) subscriptions from App Store")
            for product in products {
                print("   - \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
            
            if products.isEmpty {
                errorMessage = "No products available. Please try again later."
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load store. Please check your connection."
        }
        
        isLoading = false
    }
    
    /// Fetch available products from our server
    private func fetchServerProducts() async throws -> [ServerProduct] {
        struct ProductsResponse: Decodable {
            let products: [ServerProduct]
        }
        
        let request = client.request(endpoint: "/store/products", method: "GET")
        let response: ProductsResponse = try await client.execute(request)
        return response.products
    }
    
    /// Get server config for a product (for display info)
    func getProductConfig(_ productID: String) -> ServerProduct? {
        return productConfigs[productID]
    }
    
    // MARK: - Purchase
    
    /// Purchase a product
    func purchase(_ product: Product) async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        errorMessage = nil
        lastPurchaseResult = nil
        
        do {
            // Start the purchase - this shows the Apple Pay sheet
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction locally
                let transaction = try checkVerified(verification)
                
                // Send to our server for verification and resource granting
                let success = await deliverProduct(transaction)
                
                // Always finish a transaction (even if our server fails)
                await transaction.finish()
                
                isLoading = false
                return success
                
            case .userCancelled:
                print("🛒 User cancelled purchase")
                lastPurchaseResult = .cancelled
                isLoading = false
                return false
                
            case .pending:
                // Ask to Buy - transaction will complete later
                print("🛒 Purchase pending (Ask to Buy)")
                errorMessage = "Purchase is pending parental approval"
                lastPurchaseResult = .pending
                isLoading = false
                return false
                
            @unknown default:
                print("🛒 Unknown purchase result")
                lastPurchaseResult = .failed("Unknown error")
                isLoading = false
                return false
            }
        } catch StoreKitError.userCancelled {
            print("🛒 User cancelled purchase (StoreKitError)")
            lastPurchaseResult = .cancelled
            isLoading = false
            return false
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = "Purchase failed. Please try again."
            lastPurchaseResult = .failed(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Deliver Product (Server Verification)
    
    /// Send transaction to our server for verification and resource granting
    private func deliverProduct(_ transaction: Transaction) async -> Bool {
        let config = productConfigs[transaction.productID]
        
        print("🛒 Delivering product: \(config?.name ?? transaction.productID)")
        print("   Transaction ID: \(transaction.id)")
        print("   Original ID: \(transaction.originalID)")
        
        do {
            let response = try await redeemPurchase(
                productID: transaction.productID,
                transactionID: String(transaction.id),
                originalTransactionID: String(transaction.originalID)
            )
            
            if response.success {
                print("✅ Purchase verified and redeemed!")
                print("   Gold: +\(response.gold_granted) (total: \(response.new_gold_total))")
                print("   Meat: +\(response.meat_granted) (total: \(response.new_meat_total))")
                
                lastPurchaseResult = .success(gold: response.gold_granted, meat: response.meat_granted)
                
                // Notify the app to refresh player state
                NotificationCenter.default.post(name: .purchaseCompleted, object: nil, userInfo: [
                    "display_message": response.display_message ?? "Purchase complete!",
                    "gold_granted": response.gold_granted,
                    "meat_granted": response.meat_granted,
                    "books_granted": response.books_granted
                ])
                
                return true
            } else {
                print("❌ Server rejected purchase: \(response.message ?? "Unknown error")")
                errorMessage = response.message ?? "Failed to redeem purchase"
                lastPurchaseResult = .failed(response.message ?? "Server error")
                return false
            }
        } catch {
            print("❌ Failed to redeem purchase with server: \(error)")
            errorMessage = "Failed to add resources. Please contact support if charged."
            lastPurchaseResult = .failed("Server communication failed")
            return false
        }
    }
    
    // MARK: - Backend API
    
    private func redeemPurchase(
        productID: String,
        transactionID: String,
        originalTransactionID: String
    ) async throws -> RedeemResponse {
        struct RedeemRequest: Encodable {
            let product_id: String
            let transaction_id: String
            let original_transaction_id: String
        }
        
        let body = RedeemRequest(
            product_id: productID,
            transaction_id: transactionID,
            original_transaction_id: originalTransactionID
        )
        
        let request = try client.request(endpoint: "/store/redeem", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transactions that weren't completed during purchase flow
    /// This handles: interrupted purchases, Ask to Buy approvals, subscription renewals
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)
                    
                    if let transaction = transaction {
                        // Handle subscription renewals
                        if transaction.productType == .autoRenewable {
                            await self?.deliverSubscription(transaction)
                            await self?.checkSubscriptionStatus()
                        } else {
                            await self?.deliverProduct(transaction)
                        }
                        await transaction.finish()
                    }
                } catch {
                    print("❌ Transaction update failed verification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    /// Verify a transaction result from StoreKit
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("❌ Transaction verification failed: \(error)")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases (for non-consumables and subscriptions)
    /// Note: Our starter pack is consumable, so it won't restore resources
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sync with the App Store
            try await AppStore.sync()
            print("✅ App Store sync completed")
            
            // Process any unfinished transactions
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    
                    // Handle subscription entitlements
                    if transaction.productType == .autoRenewable {
                        await deliverSubscription(transaction)
                    } else {
                        await deliverProduct(transaction)
                    }
                    await transaction.finish()
                } catch {
                    print("⚠️ Failed to process restored transaction: \(error)")
                }
            }
            
            // Update subscription status
            await checkSubscriptionStatus()
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases"
        }
        
        isLoading = false
    }
    
    // MARK: - Subscription Handling
    
    /// Check subscription status from both StoreKit and backend
    func checkSubscriptionStatus() async {
        // First check StoreKit entitlements
        var hasActiveEntitlement = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    // Check if not expired
                    if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                        hasActiveEntitlement = true
                        // Sync with backend
                        await deliverSubscription(transaction)
                    }
                }
            } catch {
                print("⚠️ Failed to verify entitlement: \(error)")
            }
        }
        
        // Also check backend status (in case subscription was managed elsewhere)
        do {
            let request = client.request(endpoint: "/store/subscription-status", method: "GET")
            let response: SubscriptionStatusResponse = try await client.execute(request)
            
            await MainActor.run {
                self.isSubscriber = response.is_subscriber
            }
            
            print("⭐ Subscription status: \(response.is_subscriber ? "Active" : "Inactive")")
        } catch {
            print("❌ Failed to check subscription status: \(error)")
            // Fall back to StoreKit entitlement check
            await MainActor.run {
                self.isSubscriber = hasActiveEntitlement
            }
            return
        }
    }
    
    /// Purchase a subscription product
    func purchaseSubscription(_ product: Product) async -> Bool {
        guard product.type == .autoRenewable else {
            print("❌ Product is not a subscription")
            return false
        }
        
        guard !isLoading else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Send to backend (new purchase, not sync)
                let success = await deliverSubscription(transaction, isNewPurchase: true)
                
                await transaction.finish()
                
                if success {
                    await checkSubscriptionStatus()
                }
                
                isLoading = false
                return success
                
            case .userCancelled:
                print("🛒 User cancelled subscription purchase")
                lastPurchaseResult = .cancelled
                isLoading = false
                return false
                
            case .pending:
                print("🛒 Subscription pending approval")
                errorMessage = "Subscription is pending approval"
                lastPurchaseResult = .pending
                isLoading = false
                return false
                
            @unknown default:
                lastPurchaseResult = .failed("Unknown error")
                isLoading = false
                return false
            }
        } catch {
            print("❌ Subscription purchase failed: \(error)")
            errorMessage = "Subscription purchase failed"
            lastPurchaseResult = .failed(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    /// Deliver subscription to backend
    /// - Parameter isNewPurchase: true if this is a fresh purchase, false if sync/restore
    private func deliverSubscription(_ transaction: Transaction, isNewPurchase: Bool = false) async -> Bool {
        print("⭐ Delivering subscription: \(transaction.productID)")
        print("   Transaction ID: \(transaction.id)")
        print("   Expires: \(transaction.expirationDate?.description ?? "N/A")")
        
        guard let expirationDate = transaction.expirationDate else {
            print("❌ Subscription has no expiration date")
            return false
        }
        
        do {
            let response = try await redeemSubscription(
                productID: transaction.productID,
                transactionID: String(transaction.id),
                originalTransactionID: String(transaction.originalID),
                expiresAt: expirationDate
            )
            
            if response.success {
                print("✅ Subscription activated!")
                
                await MainActor.run {
                    self.isSubscriber = true
                }
                
                // Only notify for new purchases, not syncs
                if isNewPurchase {
                    NotificationCenter.default.post(name: .subscriptionActivated, object: nil)
                }
                
                return true
            } else {
                print("❌ Server rejected subscription: \(response.message)")
                return false
            }
        } catch {
            print("❌ Failed to redeem subscription: \(error)")
            return false
        }
    }
    
    /// Redeem subscription with backend
    private func redeemSubscription(
        productID: String,
        transactionID: String,
        originalTransactionID: String,
        expiresAt: Date
    ) async throws -> SubscriptionRedeemResponse {
        struct RedeemSubscriptionRequest: Encodable {
            let product_id: String
            let transaction_id: String
            let original_transaction_id: String
            let expires_at: String
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let body = RedeemSubscriptionRequest(
            product_id: productID,
            transaction_id: transactionID,
            original_transaction_id: originalTransactionID,
            expires_at: formatter.string(from: expiresAt)
        )
        
        let request = try client.request(endpoint: "/store/redeem-subscription", method: "POST", body: body)
        return try await client.execute(request)
    }
    
    // MARK: - Check Pending Transactions
    
    /// Check for any pending transactions (called on app launch)
    func checkPendingTransactions() async {
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                print("📦 Found unfinished transaction: \(transaction.productID)")
                await deliverProduct(transaction)
                await transaction.finish()
            } catch {
                print("⚠️ Unfinished transaction failed verification: \(error)")
            }
        }
    }
    
    // MARK: - Book Usage
    
    /// Use a book to reduce cooldown on a slot
    /// - Parameters:
    ///   - slot: "personal" (training), "building", or "crafting"
    ///   - actionType: Optional specific action type for validation
    func useBook(on slot: String, actionType: String? = nil) async -> UseBookResponse? {
        struct UseBookRequest: Encodable {
            let slot: String
            let action_type: String?
        }
        
        do {
            let body = UseBookRequest(slot: slot, action_type: actionType)
            let request = try client.request(endpoint: "/store/use-book", method: "POST", body: body)
            let response: UseBookResponse = try await client.execute(request)
            
            if response.success {
                NotificationCenter.default.post(name: .bookUsed, object: nil, userInfo: [
                    "slot": slot,
                    "books_remaining": response.books_remaining
                ])
            }
            
            return response
        } catch {
            print("❌ Failed to use book: \(error)")
            errorMessage = "Failed to use book"
            return nil
        }
    }
    
    /// Get current book count from server
    func getBookCount() async -> Int {
        do {
            let request = client.request(endpoint: "/store/books", method: "GET")
            let response: BookCountResponse = try await client.execute(request)
            return response.books
        } catch {
            print("❌ Failed to get book count: \(error)")
            return 0
        }
    }
    
    /// Get book info for cooldown skip popup
    func getBookInfo() async -> BookInfoResponse? {
        do {
            let request = client.request(endpoint: "/store/book-info", method: "GET")
            return try await client.execute(request)
        } catch {
            print("❌ Failed to get book info: \(error)")
            return nil
        }
    }
}

// MARK: - Response Models

struct RedeemResponse: Decodable {
    let success: Bool
    let message: String?
    let display_message: String?  // Server-driven UI message
    let gold_granted: Int
    let meat_granted: Int
    let books_granted: Int
    let new_gold_total: Int
    let new_meat_total: Int
    let new_book_total: Int
}

struct UseBookResponse: Decodable {
    let success: Bool
    let message: String
    let books_remaining: Int
    let cooldown_reduced_minutes: Int
    let new_cooldown_seconds: Int
}

struct BookCountResponse: Decodable {
    let books: Int
}

struct BookInfoResponse: Decodable {
    let books_owned: Int
    let description: String
    let effect: String  // "skip_cooldown" or "reduce_cooldown"
    let effect_description: String  // Human-readable for button, e.g. "Skip cooldown"
    let cooldown_reduction_minutes: Int?  // nil if skip_cooldown
    let eligible_slots: [String]
    let can_purchase: Bool
    let purchase_product_id: String?
}

struct SubscriptionStatusResponse: Decodable {
    let is_subscriber: Bool
    let product_id: String?
    let expires_at: String?
}

struct SubscriptionRedeemResponse: Decodable {
    let success: Bool
    let message: String
    let is_subscriber: Bool
    let expires_at: String?
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case failedVerification
    case productNotFound
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction could not be verified"
        case .productNotFound:
            return "Product not available"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let purchaseCompleted = Notification.Name("purchaseCompleted")
    static let bookUsed = Notification.Name("bookUsed")
    static let openStore = Notification.Name("openStore")
    static let subscriptionActivated = Notification.Name("subscriptionActivated")
}
