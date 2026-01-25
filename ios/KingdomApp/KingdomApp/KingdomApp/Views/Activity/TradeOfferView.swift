import SwiftUI
import Combine

/// View for creating a new trade offer to a friend
/// Requires Merchant skill tier 1 for both sender and recipient
struct TradeOfferView: View {
    let recipientId: Int
    let recipientName: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TradeOfferViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    MedievalLoadingView(status: "Loading...")
                } else if !viewModel.hasMerchantSkill {
                    noMerchantSkillView
                } else {
                    ScrollView {
                        VStack(spacing: KingdomTheme.Spacing.large) {
                            // Header
                            headerSection
                            
                            // Offer Type Selector
                            offerTypeSection
                            
                            // Item Selection (if item offer)
                            if viewModel.offerType == "item" {
                                itemSelectionSection
                            }
                            
                            // Gold Amount
                            goldAmountSection
                            
                            // Message
                            messageSection
                            
                            // Summary
                            summarySection
                            
                            // Create Offer Button
                            createOfferButton
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Trade with \(recipientName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .task {
                await viewModel.loadTradeableItems()
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
    }
    
    // MARK: - No Merchant Skill View
    
    private var noMerchantSkillView: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text("Merchant Skill Required")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("You need Merchant skill tier 1 to trade with other players. Train your Merchant skill to unlock trading!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { dismiss() }) {
                Text("Got It")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: KingdomTheme.Spacing.small) {
            HStack(spacing: 12) {
                Text(String(recipientName.prefix(1)).uppercased())
                    .font(FontStyles.headingMedium)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 14)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sending to")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text(recipientName)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Offer Type Section
    
    private var offerTypeSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("What do you want to send?")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack(spacing: 12) {
                // Item offer
                Button(action: { viewModel.offerType = "item" }) {
                    VStack(spacing: 4) {
                        Image(systemName: "cube.fill")
                            .font(FontStyles.iconMedium)
                        Text("Item")
                            .font(FontStyles.labelBold)
                    }
                    .foregroundColor(viewModel.offerType == "item" ? .white : KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.offerType == "item" ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                }
                
                // Gold gift
                Button(action: { viewModel.offerType = "gold" }) {
                    VStack(spacing: 4) {
                        Image(systemName: "g.circle.fill")
                            .font(FontStyles.iconMedium)
                        Text("Gold")
                            .font(FontStyles.labelBold)
                    }
                    .foregroundColor(viewModel.offerType == "gold" ? .white : KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.offerType == "gold" ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Item Selection Section
    
    private var itemSelectionSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Select Item")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if viewModel.tradeableItems.isEmpty {
                Text("You don't have any items to trade")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.tradeableItems) { item in
                            itemButton(for: item)
                        }
                    }
                }
                
                // Quantity selector
                if viewModel.selectedItem != nil {
                    quantitySelector
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private func itemButton(for item: TradeableItem) -> some View {
        let isSelected = viewModel.selectedItem?.itemId == item.itemId
        
        return Button(action: {
            viewModel.selectedItem = item
            viewModel.itemQuantity = min(1, item.quantity)
        }) {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(FontStyles.iconMedium)
                Text(item.displayName)
                    .font(FontStyles.labelSmall)
                Text("x\(item.quantity)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : KingdomTheme.Colors.inkMedium)
            }
            .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.parchment)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
    }
    
    private var quantitySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quantity")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                if let item = viewModel.selectedItem {
                    Text("You have: \(item.quantity)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.itemQuantity = max(1, viewModel.itemQuantity - 1) }) {
                    Image(systemName: "minus")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 8)
                }
                
                Text("\(viewModel.itemQuantity)")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(minWidth: 60)
                
                Button(action: {
                    if let max = viewModel.selectedItem?.quantity {
                        viewModel.itemQuantity = min(max, viewModel.itemQuantity + 1)
                    }
                }) {
                    Image(systemName: "plus")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 8)
                }
                
                Spacer()
                
                // Max button
                if let max = viewModel.selectedItem?.quantity, max > 1 {
                    Button(action: { viewModel.itemQuantity = max }) {
                        Text("Max")
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 8)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Gold Amount Section
    
    private var goldAmountSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            HStack {
                Text(viewModel.offerType == "gold" ? "Amount to Send" : "Price (0 = gift)")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("You have: \(viewModel.playerGold)g")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            HStack(spacing: 12) {
                // Current amount display
                HStack(spacing: 4) {
                    Text("\(viewModel.goldAmount)")
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Image(systemName: "g.circle.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 2)
                )
                
                VStack(spacing: 6) {
                    incrementButton("+100") { viewModel.goldAmount = min(viewModel.maxGold, viewModel.goldAmount + 100) }
                    incrementButton("+10") { viewModel.goldAmount = min(viewModel.maxGold, viewModel.goldAmount + 10) }
                    incrementButton("+1") { viewModel.goldAmount = min(viewModel.maxGold, viewModel.goldAmount + 1) }
                }
                
                VStack(spacing: 6) {
                    incrementButton("-100") { viewModel.goldAmount = max(viewModel.minGold, viewModel.goldAmount - 100) }
                    incrementButton("-10") { viewModel.goldAmount = max(viewModel.minGold, viewModel.goldAmount - 10) }
                    incrementButton("-1") { viewModel.goldAmount = max(viewModel.minGold, viewModel.goldAmount - 1) }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private func incrementButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50)
                .padding(.vertical, 6)
                .background(KingdomTheme.Colors.buttonPrimary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
                )
        }
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Message (optional)")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            TextField("Add a note...", text: $viewModel.message)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 2)
                )
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Summary")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack(spacing: 8) {
                if viewModel.offerType == "gold" {
                    Image(systemName: "g.circle.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                    Text("Sending \(viewModel.goldAmount)g to \(recipientName)")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                } else if let item = viewModel.selectedItem {
                    Image(systemName: item.icon)
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    if viewModel.goldAmount > 0 {
                        Text("\(viewModel.itemQuantity) \(item.displayName) for \(viewModel.goldAmount)g")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    } else {
                        Text("\(viewModel.itemQuantity) \(item.displayName) as a gift")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                } else {
                    Text("Select an item to trade")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Create Offer Button
    
    private var createOfferButton: some View {
        Button(action: {
            Task {
                await viewModel.createOffer(recipientId: recipientId)
                if viewModel.showSuccess {
                    NotificationCenter.default.post(name: .playerStateDidChange, object: nil)
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(FontStyles.iconSmall)
                Text("Send Offer")
                    .font(FontStyles.headingMedium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isValid ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 3)
                        )
                }
            )
        }
        .disabled(!viewModel.isValid || viewModel.isProcessing)
        .padding(.horizontal)
    }
}

// MARK: - View Model

@MainActor
class TradeOfferViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isProcessing = false
    @Published var hasMerchantSkill = true
    
    @Published var offerType: String = "item"
    @Published var tradeableItems: [TradeableItem] = []
    @Published var selectedItem: TradeableItem?
    @Published var itemQuantity: Int = 1
    @Published var goldAmount: Int = 0
    @Published var playerGold: Int = 0
    @Published var message: String = ""
    
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    private let api = KingdomAPIService.shared
    
    var minGold: Int {
        offerType == "gold" ? 1 : 0
    }
    
    var maxGold: Int {
        if offerType == "gold" {
            return playerGold
        } else {
            return 10000 // No limit for pricing items
        }
    }
    
    var isValid: Bool {
        if offerType == "gold" {
            return goldAmount > 0 && goldAmount <= playerGold
        } else {
            guard let item = selectedItem else { return false }
            return itemQuantity > 0 && itemQuantity <= item.quantity
        }
    }
    
    func loadTradeableItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.trades.getTradeableItems()
            tradeableItems = response.items
            playerGold = response.gold
            hasMerchantSkill = true
            
            // Select first item by default
            if let first = tradeableItems.first {
                selectedItem = first
            }
        } catch {
            print("❌ Failed to load tradeable items: \(error)")
            hasMerchantSkill = false
            errorMessage = error.localizedDescription
        }
    }
    
    func createOffer(recipientId: Int) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let response = try await api.trades.createOffer(
                recipientId: recipientId,
                offerType: offerType,
                itemType: offerType == "item" ? selectedItem?.itemId : nil,
                itemQuantity: offerType == "item" ? itemQuantity : nil,
                goldAmount: goldAmount,
                message: message.isEmpty ? nil : message
            )
            
            successMessage = response.message
            showSuccess = true
        } catch {
            print("❌ Failed to create trade offer: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    TradeOfferView(recipientId: 1, recipientName: "TestPlayer")
}
