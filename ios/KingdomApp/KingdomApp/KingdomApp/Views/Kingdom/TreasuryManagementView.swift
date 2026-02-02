import SwiftUI

/// Simplified treasury management - just pick FROM and TO
enum GoldLocation: Hashable {
    case personal
    case kingdom(String) // kingdom ID
}

struct TreasuryManagementView: View {
    let kingdom: EmpireKingdomSummary
    let allKingdoms: [EmpireKingdomSummary]
    @ObservedObject var player: Player
    let uiConfig: EmpireUIConfig
    let onComplete: () -> Void
    
    @State private var fromLocation: GoldLocation = .kingdom("") // Will be set to current kingdom
    @State private var toLocation: GoldLocation = .personal
    @State private var amount: String = "0"
    @State private var isLoading = false
    @State private var resultMessage: String?
    @State private var isError = false
    
    // All kingdoms for selectors
    var otherKingdoms: [EmpireKingdomSummary] {
        allKingdoms.filter { $0.id != kingdom.id }
    }
    
    // Available balance based on FROM selection
    private var availableBalance: Int {
        switch fromLocation {
        case .personal:
            return player.gold
        case .kingdom(let id):
            return allKingdoms.first { $0.id == id }?.treasuryGold ?? 0
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Balances Header
                balancesHeader
                
                // FROM selector
                fromSelector
                
                // TO selector
                toSelector
                
                // Amount Input
                amountInput
                
                // Quick Amount Buttons
                quickAmountButtons
                
                // Submit Button
                submitButton
                
                // Result Message
                if let message = resultMessage {
                    resultCard(message: message, isError: isError)
                }
            }
            .padding(.bottom, KingdomTheme.Spacing.xLarge)
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationTitle("Move Gold")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            // Default: from treasury to personal (withdraw)
            fromLocation = .kingdom(kingdom.id)
            toLocation = .personal
        }
    }
    
    // MARK: - Balances Header
    
    private var balancesHeader: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Personal Gold
            VStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("\(player.gold)")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text("Your Gold")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.black)
                .frame(width: 2, height: 40)
            
            // Current Kingdom Treasury
            VStack(spacing: 4) {
                Image(systemName: "building.columns.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                Text("\(kingdom.treasuryGold)")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text(kingdom.name)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - FROM Selector
    
    private var fromSelector: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("From")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            VStack(spacing: KingdomTheme.Spacing.small) {
                // Personal gold option
                locationButton(
                    location: .personal,
                    icon: "person.fill",
                    label: "Your Gold",
                    balance: player.gold,
                    isSelected: fromLocation == .personal,
                    isFrom: true
                )
                
                // Current kingdom treasury
                locationButton(
                    location: .kingdom(kingdom.id),
                    icon: "building.columns.fill",
                    label: kingdom.name,
                    balance: kingdom.treasuryGold,
                    isSelected: fromLocation == .kingdom(kingdom.id),
                    isFrom: true
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - TO Selector
    
    private var toSelector: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("To")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            VStack(spacing: KingdomTheme.Spacing.small) {
                // Personal gold option (disabled if FROM is personal)
                locationButton(
                    location: .personal,
                    icon: "person.fill",
                    label: "Your Gold",
                    balance: player.gold,
                    isSelected: toLocation == .personal,
                    isFrom: false,
                    isDisabled: fromLocation == .personal
                )
                
                // Current kingdom treasury (disabled if FROM is this treasury)
                locationButton(
                    location: .kingdom(kingdom.id),
                    icon: "building.columns.fill",
                    label: kingdom.name,
                    balance: kingdom.treasuryGold,
                    isSelected: toLocation == .kingdom(kingdom.id),
                    isFrom: false,
                    isDisabled: fromLocation == .kingdom(kingdom.id)
                )
                
                // Other kingdoms (for transfers)
                ForEach(otherKingdoms) { otherKingdom in
                    locationButton(
                        location: .kingdom(otherKingdom.id),
                        icon: "building.columns",
                        label: otherKingdom.name,
                        balance: otherKingdom.treasuryGold,
                        isSelected: toLocation == .kingdom(otherKingdom.id),
                        isFrom: false,
                        isDisabled: fromLocation == .personal // Can only transfer from treasury
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Location Button
    
    private func locationButton(
        location: GoldLocation,
        icon: String,
        label: String,
        balance: Int,
        isSelected: Bool,
        isFrom: Bool,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isFrom {
                    fromLocation = location
                    // Auto-adjust TO if it conflicts
                    if toLocation == location {
                        toLocation = location == .personal ? .kingdom(kingdom.id) : .personal
                    }
                } else {
                    toLocation = location
                }
                resultMessage = nil
            }
        }) {
            HStack(spacing: 12) {
                // Radio indicator - show dash for disabled
                Image(systemName: isDisabled ? "minus.circle" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(FontStyles.iconMedium)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : (isSelected ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkLight))
                
                Image(systemName: icon)
                    .font(FontStyles.iconSmall)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkMedium)
                
                Text(label)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(balance) gold")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkMedium)
            }
            .padding(12)
        }
        .brutalistCard(backgroundColor: isSelected ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
        .disabled(isDisabled)
    }
    
    // MARK: - Amount Input
    
    private var amountInput: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Amount")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack {
                Image(systemName: "g.circle.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.goldLight)
                
                TextField("0", text: $amount)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .keyboardType(.numberPad)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .fontWeight(.semibold)
                        }
                    }
                
                if amount != "0" && !amount.isEmpty {
                    Button(action: { amount = "0" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            
            // Show max available from source

        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Amount Buttons
    
    private var quickAmountButtons: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Quick Select")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal)
            
            HStack(spacing: KingdomTheme.Spacing.small) {
                // Quick amounts from config
                ForEach(uiConfig.quickAmounts, id: \.self) { quickAmount in
                    Button(action: { amount = "\(quickAmount)" }) {
                        Text("\(quickAmount)")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
                }
                
                // Max button
                Button(action: { amount = "\(availableBalance)" }) {
                    Text(uiConfig.quickMaxLabel)
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 8)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Submit Button
    
    private var actionLabel: String {
        switch (fromLocation, toLocation) {
        case (.personal, .kingdom(let id)) where id == kingdom.id:
            return "Deposit"
        case (.kingdom(let id), .personal) where id == kingdom.id:
            return "Withdraw"
        case (.kingdom, .kingdom):
            return "Transfer"
        default:
            return "Move Gold"
        }
    }
    
    private var actionIcon: String {
        switch (fromLocation, toLocation) {
        case (.personal, .kingdom):
            return "arrow.up.circle.fill"
        case (.kingdom, .personal):
            return "arrow.down.circle.fill"
        case (.kingdom, .kingdom):
            return "arrow.left.arrow.right.circle.fill"
        default:
            return "arrow.right.circle.fill"
        }
    }
    
    private var submitButton: some View {
        Button(action: { Task { await performAction() } }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: actionIcon)
                        .font(FontStyles.iconMedium)
                }
                Text(isLoading ? "Processing..." : actionLabel)
                    .font(FontStyles.bodyMediumBold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
        }
        .brutalistBadge(backgroundColor: isValidInput ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkLight, cornerRadius: 12)
        .disabled(!isValidInput || isLoading)
        .padding(.horizontal)
    }
    
    private var isValidInput: Bool {
        guard let amountValue = Int(amount), amountValue > 0 else { return false }
        guard amountValue <= availableBalance else { return false }
        guard fromLocation != toLocation else { return false }
        return true
    }
    
    // MARK: - Result Card
    
    private func resultCard(message: String, isError: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(FontStyles.iconMedium)
                .foregroundColor(isError ? KingdomTheme.Colors.royalCrimson : KingdomTheme.Colors.buttonSuccess)
            
            Text(message)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    // MARK: - Perform Action
    
    @MainActor
    private func performAction() async {
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        
        isLoading = true
        resultMessage = nil
        
        do {
            switch (fromLocation, toLocation) {
            case (.kingdom(let fromId), .personal) where fromId == kingdom.id:
                // Withdraw from current kingdom treasury to personal
                let response = try await APIClient.shared.withdrawFromTreasury(kingdomId: kingdom.id, amount: amountValue)
                resultMessage = response.message
                isError = false
                player.gold = response.personalGoldNew
                
            case (.personal, .kingdom(let toId)) where toId == kingdom.id:
                // Deposit from personal to current kingdom treasury
                let response = try await APIClient.shared.depositToTreasury(kingdomId: kingdom.id, amount: amountValue)
                resultMessage = response.message
                isError = false
                player.gold = response.personalGoldRemaining
                
            case (.kingdom(let fromId), .kingdom(let toId)) where fromId == kingdom.id:
                // Transfer from current kingdom to another kingdom
                let response = try await APIClient.shared.transferFunds(
                    sourceKingdomId: kingdom.id,
                    targetKingdomId: toId,
                    amount: amountValue
                )
                resultMessage = response.message
                isError = false
                
            default:
                resultMessage = "Invalid transfer"
                isError = true
            }
            
            // Clear amount on success
            amount = ""
            
            // Delay then close and refresh
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            onComplete()
            
        } catch let error as APIError {
            if case .serverError(let message) = error {
                resultMessage = message
            } else {
                resultMessage = error.localizedDescription
            }
            isError = true
        } catch {
            resultMessage = error.localizedDescription
            isError = true
        }
        
        isLoading = false
    }
}
