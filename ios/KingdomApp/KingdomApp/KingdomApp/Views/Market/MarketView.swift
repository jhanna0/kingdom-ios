import SwiftUI
import Combine

struct MarketView: View {
    @StateObject private var viewModel = MarketViewModel()
    @State private var selectedItemType: ItemType = .iron
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Kingdom Context
                    if let info = viewModel.marketInfo {
                        kingdomHeader(info)
                    }
                    
                    // Create Order Button - ALWAYS ENABLED
                    NavigationLink(destination: CreateOrderView(viewModel: viewModel, itemType: selectedItemType)) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Create New Order")
                                .font(FontStyles.headingMedium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                                    .offset(x: 4, y: 4)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(KingdomTheme.Colors.imperialGold)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black, lineWidth: 3)
                                    )
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Item Tabs
                    itemTabs
                    
                    // My Active Orders (always show the section)
                    myOrdersSection
                    
                    // Recent Trades
                    if !viewModel.recentTrades.isEmpty {
                        recentTradesSection
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Market")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await viewModel.loadMarket(itemType: selectedItemType)
        }
        .onChange(of: selectedItemType) { newItem in
            Task {
                await viewModel.loadRecentTrades(itemType: newItem)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") { }
        } message: {
            Text(viewModel.successMessage)
        }
    }
    
    // MARK: - Kingdom Header
    
    private func kingdomHeader(_ info: MarketInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.imperialGold,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.kingdomName)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Market Level \(info.marketLevel)")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            // Resources
            HStack(spacing: 16) {
                ResourceBadge(icon: "g.circle.fill", value: info.playerGold, color: KingdomTheme.Colors.goldLight)
                
                if let iron = info.playerResources["iron"] {
                    ResourceBadge(icon: "gearshape.fill", value: iron, color: .gray)
                }
                if let steel = info.playerResources["steel"] {
                    ResourceBadge(icon: "wrench.and.screwdriver.fill", value: steel, color: .blue)
                }
                if let wood = info.playerResources["wood"] {
                    ResourceBadge(icon: "tree.fill", value: wood, color: .brown)
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
        .padding(.top, KingdomTheme.Spacing.small)
    }
    
    // MARK: - Item Tabs
    
    private var itemTabs: some View {
        Group {
            if let availableItems = viewModel.marketInfo?.availableItems, !availableItems.isEmpty {
                HStack(spacing: 8) {
                    ForEach(availableItems, id: \.self) { item in
                        Button(action: { selectedItemType = item }) {
                            HStack(spacing: 6) {
                                Image(systemName: itemIcon(for: item))
                                    .font(.system(size: 14, weight: .bold))
                                Text(item.displayName)
                                    .font(FontStyles.labelLarge)
                            }
                            .foregroundColor(selectedItemType == item ? .white : KingdomTheme.Colors.inkDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                ZStack {
                                    if selectedItemType == item {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black)
                                            .offset(x: 2, y: 2)
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(itemColor(for: item))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 2)
                                            )
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(KingdomTheme.Colors.parchment)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 2)
                                            )
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(KingdomTheme.Spacing.medium)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - My Orders
    
    private var myOrdersSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("My Active Orders")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if viewModel.myActiveOrders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("No Active Orders")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Your orders will appear here")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.myActiveOrders) { order in
                        OrderRowView(order: order) {
                            Task {
                                await viewModel.cancelOrder(orderId: order.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Recent Trades
    
    private var recentTradesSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Recent Trades")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if viewModel.recentTrades.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("No Recent Trades")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Trade history will appear here")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentTrades.prefix(10)) { trade in
                        HStack(spacing: 12) {
                            Text("\(trade.quantity)x @ \(trade.pricePerUnit)g")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Text(trade.createdAt, style: .relative)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func itemIcon(for item: ItemType) -> String {
        switch item {
        case .iron: return "gearshape.fill"
        case .steel: return "wrench.and.screwdriver.fill"
        case .wood: return "tree.fill"
        }
    }
    
    private func itemColor(for item: ItemType) -> Color {
        switch item {
        case .iron: return .gray
        case .steel: return .blue
        case .wood: return .brown
        }
    }
}

// MARK: - Resource Badge

struct ResourceBadge: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text("\(value)")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black, lineWidth: 1)
        )
    }
}

// MARK: - Order Row

struct OrderRowView: View {
    let order: MarketOrder
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Order type badge
            Text(order.orderType == .buy ? "BUY" : "SELL")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(order.orderType == .buy ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text("\(order.quantityRemaining)/\(order.quantityOriginal) @ \(order.pricePerUnit)g")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(order.createdAt, style: .relative)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
    }
}

// MARK: - Create Order View

struct CreateOrderView: View {
    @ObservedObject var viewModel: MarketViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItemType: ItemType
    @State private var orderType: OrderType = .buy
    @State private var pricePerUnit: Int = 10
    @State private var quantity: Int = 1
    @State private var orderPlaced = false
    @State private var showCancelAlert = false
    
    init(viewModel: MarketViewModel, itemType: ItemType) {
        self.viewModel = viewModel
        _selectedItemType = State(initialValue: itemType)
    }
    
    var totalCost: Int {
        return pricePerUnit * quantity
    }
    
    var canAfford: Bool {
        guard orderType == .buy, let info = viewModel.marketInfo else {
            return true
        }
        return info.playerGold >= totalCost
    }
    
    var hasEnoughItems: Bool {
        guard orderType == .sell,
              let info = viewModel.marketInfo,
              let available = info.playerResources[selectedItemType.rawValue] else {
            return true
        }
        return available >= quantity
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    // Item Selector (only available items from backend)
                    if let availableItems = viewModel.marketInfo?.availableItems, !availableItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Item")
                                    .font(FontStyles.headingMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                HStack(spacing: 8) {
                                    ForEach(availableItems, id: \.self) { item in
                                        Button(action: { selectedItemType = item }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: itemIcon(for: item))
                                                    .font(.system(size: 14, weight: .bold))
                                                Text(item.displayName)
                                                    .font(FontStyles.labelLarge)
                                            }
                                            .foregroundColor(selectedItemType == item ? .white : KingdomTheme.Colors.inkDark)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedItemType == item
                                                    ? itemColor(for: item)
                                                    : KingdomTheme.Colors.parchmentLight
                                            )
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 2)
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No items available")
                                    .font(FontStyles.headingMedium)
                                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                if let message = viewModel.marketInfo?.message {
                                    Text(message)
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        }
                        
                        // Order Type Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Order Type")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            HStack(spacing: 12) {
                                ForEach(OrderType.allCases, id: \.self) { type in
                                    Button(action: { orderType = type }) {
                                        Text(type.rawValue.uppercased())
                                            .font(FontStyles.labelLarge)
                                            .foregroundColor(orderType == type ? .white : KingdomTheme.Colors.inkDark)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                orderType == type
                                                    ? (type == .buy ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                                                    : KingdomTheme.Colors.parchmentLight
                                            )
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        
                        // Price Per Unit
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Price Per Unit (gold)")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            HStack(spacing: 12) {
                                // Current price display
                                Text("\(pricePerUnit)g")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                
                                VStack(spacing: 8) {
                                    incrementButton("+100") { pricePerUnit = min(10000, pricePerUnit + 100) }
                                    incrementButton("+10") { pricePerUnit = min(10000, pricePerUnit + 10) }
                                    incrementButton("+1") { pricePerUnit = min(10000, pricePerUnit + 1) }
                                }
                                
                                VStack(spacing: 8) {
                                    incrementButton("-100") { pricePerUnit = max(1, pricePerUnit - 100) }
                                    incrementButton("-10") { pricePerUnit = max(1, pricePerUnit - 10) }
                                    incrementButton("-1") { pricePerUnit = max(1, pricePerUnit - 1) }
                                }
                            }
                        }
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        
                        // Quantity
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quantity (1-20)")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            HStack(spacing: 12) {
                                // Current quantity display
                                Text("\(quantity)")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                
                                VStack(spacing: 8) {
                                    incrementButton("+10") { quantity = min(20, quantity + 10) }
                                    incrementButton("+5") { quantity = min(20, quantity + 5) }
                                    incrementButton("+1") { quantity = min(20, quantity + 1) }
                                }
                                
                                VStack(spacing: 8) {
                                    incrementButton("-10") { quantity = max(1, quantity - 10) }
                                    incrementButton("-5") { quantity = max(1, quantity - 5) }
                                    incrementButton("-1") { quantity = max(1, quantity - 1) }
                                }
                            }
                        }
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        
                        // Total
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            HStack(spacing: 6) {
                                Text("\(quantity)")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Image(systemName: itemIcon(for: selectedItemType))
                                    .font(.title2)
                                    .foregroundColor(itemColor(for: selectedItemType))
                                Text("@")
                                    .font(FontStyles.labelLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text("\(pricePerUnit)g")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Text("=")
                                    .font(FontStyles.labelLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text("\(totalCost)g")
                                    .font(FontStyles.headingLarge)
                                    .fontWeight(.bold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        
                        // Validation Messages
                        if orderType == .buy && !canAfford {
                            Text("Not enough gold")
                                .font(FontStyles.labelLarge)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(KingdomTheme.Colors.buttonDanger, lineWidth: 2)
                                )
                        }
                        
                        if orderType == .sell && !hasEnoughItems {
                            Text("Not enough \(selectedItemType.displayName)")
                                .font(FontStyles.labelLarge)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(KingdomTheme.Colors.buttonDanger, lineWidth: 2)
                                )
                        }
                        
                        // Place Order Button
                        Button(action: {
                            Task {
                                await placeOrder()
                            }
                        }) {
                            Text("Place Order")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValid ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                        .disabled(!isValid)
                    }
                    .padding()
                }
            }
        
        .navigationTitle("Create Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if !orderPlaced {
                        showCancelAlert = true
                    } else {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
        }
        .alert("Leave Without Placing Order?", isPresented: $showCancelAlert) {
            Button("Stay", role: .cancel) { }
            Button("Leave", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your order has not been placed. Are you sure you want to go back?")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage)
        }
    }
    
    private func incrementButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60)
                .padding(.vertical, 6)
                .background(KingdomTheme.Colors.buttonPrimary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
                )
        }
    }
    
    var isValid: Bool {
        // Can't place order if no items available
        guard let items = viewModel.marketInfo?.availableItems, !items.isEmpty else {
            return false
        }
        
        if orderType == .buy {
            return canAfford
        } else {
            return hasEnoughItems
        }
    }
    
    func placeOrder() async {
        let success = await viewModel.createOrder(
            orderType: orderType,
            itemType: selectedItemType,
            pricePerUnit: pricePerUnit,
            quantity: quantity
        )
        
        if success {
            orderPlaced = true
            // Success alert will show, user taps OK to dismiss
        }
    }
    
    private func itemIcon(for item: ItemType) -> String {
        switch item {
        case .iron: return "gearshape.fill"
        case .steel: return "wrench.and.screwdriver.fill"
        case .wood: return "tree.fill"
        }
    }
    
    private func itemColor(for item: ItemType) -> Color {
        switch item {
        case .iron: return .gray
        case .steel: return .blue
        case .wood: return .brown
        }
    }
}

// MARK: - View Model

@MainActor
class MarketViewModel: ObservableObject {
    @Published var marketInfo: MarketInfo?
    @Published var myActiveOrders: [MarketOrder] = []
    @Published var recentTrades: [MarketTransaction] = []
    
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    private let api = MarketAPI()
    
    func loadMarket(itemType: ItemType) async {
        do {
            async let info = api.getMarketInfo()
            async let orders = api.getMyOrders()
            async let trades = api.getRecentTrades(itemType: itemType, limit: 20)
            
            let (infoResult, ordersResult, tradesResult) = try await (info, orders, trades)
            
            self.marketInfo = infoResult
            self.myActiveOrders = ordersResult.activeOrders
            self.recentTrades = tradesResult
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    func loadRecentTrades(itemType: ItemType) async {
        do {
            self.recentTrades = try await api.getRecentTrades(itemType: itemType, limit: 20)
        } catch {
            print("Failed to load recent trades: \(error)")
        }
    }
    
    func createOrder(orderType: OrderType, itemType: ItemType, pricePerUnit: Int, quantity: Int) async -> Bool {
        do {
            let result = try await api.createOrder(
                orderType: orderType,
                itemType: itemType,
                pricePerUnit: pricePerUnit,
                quantity: quantity
            )
            
            // Refresh data
            await loadMarket(itemType: itemType)
            
            // Show success message
            if result.fullyFilled {
                showSuccess(message: "Order filled instantly! Traded \(result.totalQuantityFilled) \(itemType.displayName) for \(result.totalGoldExchanged)g")
            } else if result.partiallyFilled {
                showSuccess(message: "Order partially filled. \(result.totalQuantityFilled) traded, \(result.quantityRemaining) remaining")
            } else {
                showSuccess(message: "Order placed")
            }
            
            return true
        } catch {
            showError(message: error.localizedDescription)
            return false
        }
    }
    
    func cancelOrder(orderId: Int) async {
        do {
            try await api.cancelOrder(id: orderId)
            
            // Refresh orders - just reload with current selected item
            let orders = try await api.getMyOrders()
            self.myActiveOrders = orders.activeOrders
            
            showSuccess(message: "Order cancelled")
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccess(message: String) {
        successMessage = message
        showSuccess = true
    }
}
