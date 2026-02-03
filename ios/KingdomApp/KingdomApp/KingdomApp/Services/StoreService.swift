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
    @Published private(set) var productConfigs: [String: ServerProduct] = [:]  // Server-side product info
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastPurchaseResult: PurchaseResult?
    
    /// Server-side product configuration
    struct ServerProduct: Decodable {
        let id: String
        let name: String
        let gold: Int
        let meat: Int
        let books: Int
        let price_usd: Double
        let icon: String
        let color: String
        
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
            
            // Sort by price
            products = storeProducts.sorted { $0.price < $1.price }
            
            print("🛒 Loaded \(products.count) products from App Store (server configured \(serverProducts.count))")
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
                    "gold": response.gold_granted,
                    "meat": response.meat_granted
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
                        // Deliver the product
                        await self?.deliverProduct(transaction)
                        
                        // Finish the transaction
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
                    await deliverProduct(transaction)
                    await transaction.finish()
                } catch {
                    print("⚠️ Failed to process restored transaction: \(error)")
                }
            }
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases"
        }
        
        isLoading = false
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
    /// - Parameter slot: "personal" (training), "building", or "crafting"
    func useBook(on slot: String) async -> UseBookResponse? {
        struct UseBookRequest: Encodable {
            let slot: String
        }
        
        do {
            let body = UseBookRequest(slot: slot)
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
}

// MARK: - Response Models

struct RedeemResponse: Decodable {
    let success: Bool
    let message: String?
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
}
