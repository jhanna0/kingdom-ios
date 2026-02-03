import SwiftUI

/// Treasury management - backend provides FROM/TO options
struct TreasuryManagementView: View {
    let kingdom: EmpireKingdomSummary
    @ObservedObject var player: Player
    let uiConfig: EmpireUIConfig
    let onComplete: () -> Void
    
    @State private var selectedFrom: TreasuryLocationOption?
    @State private var selectedTo: TreasuryLocationOption?
    @State private var amount: String = "0"
    @State private var isLoading = false
    @State private var resultMessage: String?
    @State private var isError = false
    
    // Available balance from selected FROM option
    private var availableBalance: Int {
        selectedFrom?.balance ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Balances Header
                balancesHeader
                
                // Intel warning
                intelWarning
                
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
            // Default to first options from backend
            selectedFrom = kingdom.treasuryFromOptions.first
            selectedTo = kingdom.treasuryToOptions.first { $0.id != selectedFrom?.id }
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
    
    // MARK: - Intel Warning
    
    private var intelWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("Treasury movements can be exposed during intelligence operations")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(KingdomTheme.Colors.inkLight, lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - FROM Selector
    
    private var fromSelector: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("From")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            VStack(spacing: KingdomTheme.Spacing.small) {
                ForEach(kingdom.treasuryFromOptions) { option in
                    optionButton(option: option, isSelected: selectedFrom?.id == option.id) {
                        selectedFrom = option
                        // Auto-switch TO if it conflicts
                        if selectedTo?.id == option.id {
                            selectedTo = kingdom.treasuryToOptions.first { $0.id != option.id }
                        }
                        resultMessage = nil
                    }
                }
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
                ForEach(kingdom.treasuryToOptions) { option in
                    let isDisabled = option.id == selectedFrom?.id
                    optionButton(option: option, isSelected: selectedTo?.id == option.id, isDisabled: isDisabled) {
                        selectedTo = option
                        resultMessage = nil
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Option Button
    
    private func optionButton(
        option: TreasuryLocationOption,
        isSelected: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isDisabled ? "minus.circle" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(FontStyles.iconMedium)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : (isSelected ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkLight))
                
                Image(systemName: option.icon)
                    .font(FontStyles.iconSmall)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkMedium)
                
                Text(option.label)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(isDisabled ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(option.balance) gold")
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
        guard let from = selectedFrom, let to = selectedTo else { return "Move Gold" }
        
        if from.type == "personal" && to.type == "current_kingdom" {
            return "Deposit"
        } else if from.type == "current_kingdom" && to.type == "personal" {
            return "Withdraw"
        } else {
            return "Transfer"
        }
    }
    
    private var actionIcon: String {
        guard let from = selectedFrom else { return "arrow.right.circle.fill" }
        
        if from.type == "personal" {
            return "arrow.up.circle.fill"
        } else if selectedTo?.type == "personal" {
            return "arrow.down.circle.fill"
        } else {
            return "arrow.left.arrow.right.circle.fill"
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
                        .font(FontStyles.iconSmall)
                }
                Text(isLoading ? "Processing..." : actionLabel)
                    .font(FontStyles.labelBold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(.white)
        }
        .brutalistBadge(backgroundColor: Color(red: 0.2, green: 0.6, blue: 0.3).opacity(isValidInput ? 1.0 : 0.4), cornerRadius: 10)
        .disabled(!isValidInput || isLoading)
        .padding(.horizontal)
    }
    
    private var isValidInput: Bool {
        guard let from = selectedFrom, let to = selectedTo else { return false }
        guard let amountValue = Int(amount), amountValue > 0 else { return false }
        guard amountValue <= from.balance else { return false }
        guard from.id != to.id else { return false }
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
        guard let from = selectedFrom, let to = selectedTo else { return }
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        
        isLoading = true
        resultMessage = nil
        
        do {
            // Determine action based on from/to types
            if from.type == "current_kingdom" && to.type == "personal" {
                // Withdraw
                let response = try await APIClient.shared.withdrawFromTreasury(kingdomId: kingdom.id, amount: amountValue)
                resultMessage = response.message
                isError = false
                player.gold = response.personalGoldNew
                
            } else if from.type == "personal" && to.type == "current_kingdom" {
                // Deposit
                let response = try await APIClient.shared.depositToTreasury(kingdomId: kingdom.id, amount: amountValue)
                resultMessage = response.message
                isError = false
                player.gold = response.personalGoldRemaining
                
            } else if from.type == "current_kingdom" && (to.type == "other_kingdom" || to.type == "current_kingdom") {
                // Transfer between kingdoms
                let response = try await APIClient.shared.transferFunds(
                    sourceKingdomId: from.id,
                    targetKingdomId: to.id,
                    amount: amountValue
                )
                resultMessage = response.message
                isError = false
                
            } else {
                resultMessage = "Invalid transfer"
                isError = true
            }
            
            // Clear amount on success
            amount = "0"
            
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
