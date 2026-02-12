import SwiftUI
import StoreKit

/// In-app purchase store view - Medieval themed
struct StoreView: View {
    @StateObject private var store = StoreService.shared
    @EnvironmentObject var player: Player
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingResult = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var resultIsSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    headerSection
                    currentResourcesSection
                    productsSection
                    termsSection
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .parchmentBackground()
            .navigationTitle("Royal Treasury")
            .navigationBarTitleDisplayMode(.large)
            .parchmentNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.toolbar(color: KingdomTheme.Colors.buttonPrimary))
                }
            }
            .alert(resultTitle, isPresented: $showingResult) {
                Button("OK") { }
            } message: {
                Text(resultMessage)
            }
            .onReceive(NotificationCenter.default.publisher(for: .purchaseCompleted)) { notification in
                Task { await player.loadFromAPI() }
                
                if let displayMessage = notification.userInfo?["display_message"] as? String {
                    // Check if anything was actually granted
                    let granted = (notification.userInfo?["gold_granted"] as? Int ?? 0) +
                                  (notification.userInfo?["meat_granted"] as? Int ?? 0) +
                                  (notification.userInfo?["books_granted"] as? Int ?? 0)
                    
                    resultTitle = "Success!"
                    resultMessage = displayMessage
                    resultIsSuccess = granted > 0  // Only dismiss if something was granted
                    showingResult = true
                }
            }
            .task {
                await store.checkPendingTransactions()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.imperialGold,
                    cornerRadius: 12,
                    shadowOffset: 3,
                    borderWidth: 3
                )
            
            Text("Royal Treasury")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Boost your character with some time savers")
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.vertical, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Current Resources
    
    private var currentResourcesSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("What you have")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                StoreResourceBadge(icon: "g.circle.fill", value: player.gold, color: KingdomTheme.Colors.imperialGold, label: "Gold")
                StoreResourceBadge(icon: "flame.fill", value: meatAmount, color: KingdomTheme.Colors.buttonDanger, label: "Meat")
                StoreResourceBadge(icon: "book.fill", value: bookAmount, color: KingdomTheme.Colors.buttonPrimary, label: "Books")
                Spacer()
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
    }
    
    private var meatAmount: Int {
        player.resourcesData.first(where: { $0.key == "meat" })?.amount ?? 0
    }
    
    private var bookAmount: Int {
        player.resourcesData.first(where: { $0.key == "book" })?.amount ?? 0
    }
    
    // MARK: - Products
    
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Available")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if store.isLoading && store.products.isEmpty {
                loadingView
            } else if store.products.isEmpty {
                emptyView
            } else {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    ForEach(store.products, id: \.id) { product in
                        StoreProductCard(product: product, store: store) {
                            await purchaseProduct(product)
                        }
                    }
                    
                    // Subscriptions at the end
                    ForEach(store.subscriptionProducts, id: \.id) { product in
                        SubscriptionCard(product: product, store: store) {
                            await purchaseSubscription(product)
                        }
                    }
                    
                }
            }
            
            if let error = store.errorMessage {
                HStack(spacing: KingdomTheme.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    Text(error)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding(.top, KingdomTheme.Spacing.small)
            }
        }
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: KingdomTheme.Spacing.small) {
                ProgressView()
                    .tint(KingdomTheme.Colors.loadingTint)
                Text("Loading wares...")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(KingdomTheme.Spacing.large)
            Spacer()
        }
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var emptyView: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "bag.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.disabled,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            Text("Market Closed")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Button("Try Again") {
                Task { await store.loadProducts() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity)
        .padding(KingdomTheme.Spacing.large)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            HStack(spacing: KingdomTheme.Spacing.small) {
                Image(systemName: "arrow.clockwise")
                Text("Restore Purchases")
            }
            .font(FontStyles.bodySmall)
            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
        }
        .disabled(store.isLoading)
    }
    
    // MARK: - Terms
    
    private var termsSection: some View {
        VStack(spacing: KingdomTheme.Spacing.small) {
            Text("Payment will be charged to your Apple ID account. Review our Terms of Service below:\n")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .multilineTextAlignment(.center)
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Link("Terms of Use", destination: URL(string: "http://legal.kingdoms.ninja/terms")!)
                Text("•")
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Link("Privacy Policy", destination: URL(string: "http://legal.kingdoms.ninja/")!)
            }
            .font(FontStyles.labelTiny)
            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
        }
        .padding(.top, KingdomTheme.Spacing.small)
    }
    
    
    // MARK: - Purchase
    
    private func purchaseProduct(_ product: Product) async {
        let success = await store.purchase(product)
        if !success {
            if case .failed(let message) = store.lastPurchaseResult {
                resultTitle = "Purchase Failed"
                resultMessage = message
                resultIsSuccess = false
                showingResult = true
            }
        }
    }
    
    private func purchaseSubscription(_ product: Product) async {
        let success = await store.purchaseSubscription(product)
        if success {
            resultTitle = "Thank you!"
            resultMessage = "You can now customize your profile (bottom of character sheet) with themes and titles."
            resultIsSuccess = true
            showingResult = true
        } else if case .failed(let message) = store.lastPurchaseResult {
            resultTitle = "Purchase Failed"
            resultMessage = message
            resultIsSuccess = false
            showingResult = true
        }
    }
}

// MARK: - Store Resource Badge (matches InventoryGridItem style)

private struct StoreResourceBadge: View {
    let icon: String
    let value: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .brutalistBadge(
                        backgroundColor: color,
                        cornerRadius: 8,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                Text(value.abbreviated())
                    .font(FontStyles.captionMedium)
                    .foregroundColor(value.valueColor())
                    .padding(.horizontal, 4)
                    .frame(minWidth: 18, minHeight: 18)
                    .brutalistBadge(
                        backgroundColor: .black,
                        cornerRadius: 9,
                        shadowOffset: 1,
                        borderWidth: 1.5
                    )
                    .offset(x: 4, y: -4)
            }
            
            Text(label)
                .font(FontStyles.captionLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
        }
        .frame(width: 60)
        .padding(.vertical, 6)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
    }
}

// MARK: - Store Product Card

private struct StoreProductCard: View {
    let product: Product
    @ObservedObject var store: StoreService
    let onPurchase: () async -> Void
    
    @State private var isPurchasing = false
    
    private var config: StoreService.ServerProduct? {
        store.getProductConfig(product.id)
    }
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            productIcon
            productDetails
            Spacer()
            priceButton
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var productIcon: some View {
        Image(systemName: config?.icon ?? "bag.fill")
            .font(.system(size: 22))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .brutalistBadge(
                backgroundColor: KingdomTheme.Colors.color(fromThemeName: config?.color ?? "royalBlue"),
                cornerRadius: 10,
                shadowOffset: 2,
                borderWidth: 2
            )
    }
    
    private var productDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(config?.name ?? product.displayName)
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            Text(config?.description ?? product.description)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    private var priceButton: some View {
        Button {
            Task {
                isPurchasing = true
                await onPurchase()
                isPurchasing = false
            }
        } label: {
            Group {
                if isPurchasing || store.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(product.displayPrice)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.white)
                }
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KingdomTheme.Colors.buttonSuccess)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || store.isLoading)
    }
}

// MARK: - Subscription Card (matches StoreProductCard style)

private struct SubscriptionCard: View {
    let product: Product
    @ObservedObject var store: StoreService
    let onPurchase: () async -> Void
    
    @State private var isPurchasing = false
    
    private var config: StoreService.ServerProduct? {
        store.getProductConfig(product.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            // Top row: Icon + Name + Button
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: config?.icon ?? "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.imperialGold,
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(config?.name ?? product.displayName)
                            .font(FontStyles.headingSmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if store.isSubscriber {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        }
                    }
                    
                    Text(config?.subtitle ?? product.description)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                if !store.isSubscriber {
                    Button {
                        Task {
                            isPurchasing = true
                            await onPurchase()
                            isPurchasing = false
                        }
                    } label: {
                        Group {
                            if isPurchasing || store.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(product.displayPrice)
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(minWidth: 60)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                    .offset(x: 2, y: 2)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(KingdomTheme.Colors.buttonSuccess)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing || store.isLoading)
                }
            }
            
            // Description below
            Text(config?.subscriptionDescription ?? product.description)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.top, KingdomTheme.Spacing.small)
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

#Preview {
    StoreView()
        .environmentObject(Player())
}
