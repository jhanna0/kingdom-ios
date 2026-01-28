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
                        
                        // Item Selection (gold is first item)
                        itemSelectionSection
                        
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
    
    // MARK: - Item Selection Section
    
    private var itemSelectionSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("What to Send")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Gold as first item
                    goldItemButton
                    
                    // Regular items
                    ForEach(viewModel.tradeableItems) { item in
                        itemButton(for: item)
                    }
                }
                .padding(4) // Prevent border clipping on all sides
            }
            
            // Quantity selector
            quantitySelector
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private var goldItemButton: some View {
        let isSelected = viewModel.selectedItemId == "gold"
        
        return Button(action: {
            viewModel.selectedItemId = "gold"
            viewModel.quantity = 1
        }) {
            VStack(spacing: 4) {
                Image(systemName: "g.circle.fill")
                    .font(FontStyles.iconMedium)
                Text("Gold")
                    .font(FontStyles.labelSmall)
                Text("x\(viewModel.playerGold)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : KingdomTheme.Colors.inkMedium)
            }
            .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkDark)
            .frame(height: 72)
            .padding(.horizontal, 14)
            .background(isSelected ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.parchment)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
    }
    
    private func itemButton(for item: TradeableItem) -> some View {
        let isSelected = viewModel.selectedItemId == item.itemId
        
        return Button(action: {
            viewModel.selectedItemId = item.itemId
            viewModel.quantity = 1
        }) {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(FontStyles.iconMedium)
                Text(item.displayName)
                    .font(FontStyles.labelSmall)
                    .lineLimit(1)
                Text("x\(item.quantity)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : KingdomTheme.Colors.inkMedium)
            }
            .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkDark)
            .frame(height: 72)
            .padding(.horizontal, 14)
            .background(isSelected ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.parchment)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
    }
    
    private var quantitySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quantity")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                Text("Available: \(viewModel.maxQuantity)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            HStack(spacing: 12) {
                Text("\(viewModel.quantity)")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                VStack(spacing: 6) {
                    stepperButton("+1") { viewModel.incrementQuantity(1) }
                    stepperButton("-1") { viewModel.decrementQuantity(1) }
                }
                
                VStack(spacing: 6) {
                    stepperButton("+10") { viewModel.incrementQuantity(10) }
                    stepperButton("-10") { viewModel.decrementQuantity(10) }
                }
                
                VStack(spacing: 6) {
                    stepperButton("+100") { viewModel.incrementQuantity(100) }
                    stepperButton("-100") { viewModel.decrementQuantity(100) }
                }
            }
        }
    }
    
    private func stepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 32)
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
            
            TextField("Add a note...", text: $viewModel.message, prompt: Text("Add a note...").foregroundColor(KingdomTheme.Colors.inkMedium))
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
        HStack(spacing: 12) {
            Image(systemName: viewModel.selectedItemId == "gold" ? "g.circle.fill" : (viewModel.selectedTradeableItem?.icon ?? "cube.fill"))
                .font(FontStyles.iconMedium)
                .foregroundColor(viewModel.selectedItemId == "gold" ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.inkMedium)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sending to \(recipientName)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text(summaryText)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private var summaryText: String {
        if viewModel.selectedItemId == "gold" {
            return "\(viewModel.quantity) Gold"
        } else if let item = viewModel.selectedTradeableItem {
            return "\(viewModel.quantity) \(item.displayName)"
        }
        return "Nothing selected"
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
    
    @Published var tradeableItems: [TradeableItem] = []
    @Published var selectedItemId: String = "gold"
    @Published var quantity: Int = 1
    @Published var playerGold: Int = 0
    @Published var message: String = ""
    
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    private let api = KingdomAPIService.shared
    
    var selectedTradeableItem: TradeableItem? {
        tradeableItems.first { $0.itemId == selectedItemId }
    }
    
    var maxQuantity: Int {
        if selectedItemId == "gold" {
            return playerGold
        } else if let item = selectedTradeableItem {
            return item.quantity
        }
        return 0
    }
    
    var isValid: Bool {
        quantity > 0 && quantity <= maxQuantity
    }
    
    func incrementQuantity(_ delta: Int) {
        quantity = min(maxQuantity, quantity + delta)
    }
    
    func decrementQuantity(_ delta: Int) {
        quantity = max(1, quantity - delta)
    }
    
    func loadTradeableItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.trades.getTradeableItems()
            tradeableItems = response.items
            playerGold = response.gold
            hasMerchantSkill = true
            selectedItemId = "gold"
            quantity = 1
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
            let isGold = selectedItemId == "gold"
            let response = try await api.trades.createOffer(
                recipientId: recipientId,
                offerType: isGold ? "gold" : "item",
                itemType: isGold ? nil : selectedItemId,
                itemQuantity: isGold ? nil : quantity,
                goldAmount: isGold ? quantity : 0,
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
