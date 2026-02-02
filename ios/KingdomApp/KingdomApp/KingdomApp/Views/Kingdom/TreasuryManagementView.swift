import SwiftUI

/// Treasury management view for rulers - SERVER-DRIVEN UI
/// All icons, colors, labels, action definitions come from backend config
struct TreasuryManagementView: View {
    let kingdom: EmpireKingdomSummary
    let allKingdoms: [EmpireKingdomSummary]
    @ObservedObject var player: Player
    let uiConfig: EmpireUIConfig
    let onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedActionId: String = "withdraw"
    @State private var amount: String = ""
    @State private var selectedTargetKingdomId: String?
    @State private var isLoading = false
    @State private var resultMessage: String?
    @State private var isError = false
    
    // Get selected action config from server config
    private var selectedAction: TreasuryActionConfig? {
        uiConfig.treasuryActions.first { $0.id == selectedActionId }
    }
    
    // Other kingdoms for transfer target
    var otherKingdoms: [EmpireKingdomSummary] {
        allKingdoms.filter { $0.id != kingdom.id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Kingdom Info Header
                    kingdomHeader
                    
                    // Action Selector - from config
                    actionSelector
                    
                    // Amount Input
                    amountInput
                    
                    // Transfer Target (if transfer selected and requires it)
                    if selectedAction?.requiresMultipleKingdoms == true {
                        transferTargetSelector
                    }
                    
                    // Quick Amount Buttons - from config
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
            .navigationTitle("Treasury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            // Default to first action
            if let first = uiConfig.treasuryActions.first {
                selectedActionId = first.id
            }
            // Default transfer target to first other kingdom
            if selectedTargetKingdomId == nil, let first = otherKingdoms.first {
                selectedTargetKingdomId = first.id
            }
        }
    }
    
    // MARK: - Kingdom Header
    
    private var kingdomHeader: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "building.columns.fill")
                .font(FontStyles.iconExtraLarge)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 16, shadowOffset: 3, borderWidth: 3)
            
            Text(kingdom.name)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack(spacing: KingdomTheme.Spacing.large) {
                VStack(spacing: 2) {
                    Text("\(kingdom.treasuryGold)")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Text("Treasury")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 30)
                
                VStack(spacing: 2) {
                    Text("\(player.gold)")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Text("Your Gold")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Action Selector - SERVER DRIVEN
    
    private var actionSelector: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Action")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal)
            
            HStack(spacing: KingdomTheme.Spacing.small) {
                ForEach(uiConfig.treasuryActions) { action in
                    // Skip transfer if only one kingdom
                    if action.requiresMultipleKingdoms && otherKingdoms.isEmpty {
                        EmptyView()
                    } else {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedActionId = action.id
                                resultMessage = nil
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: action.icon)
                                    .font(FontStyles.iconMedium)
                                Text(action.label)
                                    .font(FontStyles.labelMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(selectedActionId == action.id ? .white : KingdomTheme.Colors.inkMedium)
                        }
                        .brutalistBadge(
                            backgroundColor: selectedActionId == action.id ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.parchmentLight,
                            cornerRadius: 10,
                            shadowOffset: selectedActionId == action.id ? 3 : 1,
                            borderWidth: 2
                        )
                    }
                }
            }
            .padding(.horizontal)
            
            if let action = selectedAction {
                Text(action.description)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
            }
        }
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
                
                if !amount.isEmpty {
                    Button(action: { amount = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            
            // Show max available
            Text(maxAvailableText)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.horizontal)
    }
    
    private var maxAvailableText: String {
        guard let action = selectedAction else { return "" }
        
        switch action.source {
        case "treasury":
            return "Available: \(kingdom.treasuryGold) gold"
        case "personal":
            return "Available: \(player.gold) gold"
        default:
            return ""
        }
    }
    
    // MARK: - Transfer Target Selector
    
    private var transferTargetSelector: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("Transfer To")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if otherKingdoms.isEmpty {
                Text(uiConfig.transferNoKingdomsMessage)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            } else {
                ForEach(otherKingdoms) { targetKingdom in
                    Button(action: {
                        selectedTargetKingdomId = targetKingdom.id
                    }) {
                        HStack {
                            Image(systemName: selectedTargetKingdomId == targetKingdom.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedTargetKingdomId == targetKingdom.id ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkLight)
                            
                            Text(targetKingdom.name)
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Text("\(targetKingdom.treasuryGold) gold")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding()
                    }
                    .brutalistCard(backgroundColor: selectedTargetKingdomId == targetKingdom.id ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Amount Buttons - SERVER DRIVEN
    
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
                
                // Max button with label from config
                Button(action: { amount = "\(maxAmount)" }) {
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
    
    private var maxAmount: Int {
        guard let action = selectedAction else { return 0 }
        
        switch action.source {
        case "treasury":
            return kingdom.treasuryGold
        case "personal":
            return player.gold
        default:
            return 0
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button(action: { Task { await performAction() } }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let action = selectedAction {
                    Image(systemName: action.icon)
                        .font(FontStyles.iconMedium)
                }
                Text(isLoading ? "Processing..." : (selectedAction?.label ?? "Submit"))
                    .font(FontStyles.bodyMediumBold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
        }
        .brutalistBadge(backgroundColor: isValidInput ? uiConfig.color("buttonSuccess") : KingdomTheme.Colors.inkLight, cornerRadius: 12)
        .disabled(!isValidInput || isLoading)
        .padding(.horizontal)
    }
    
    private var isValidInput: Bool {
        guard let amountValue = Int(amount), amountValue > 0 else { return false }
        guard let action = selectedAction else { return false }
        
        switch action.source {
        case "treasury":
            if action.requiresMultipleKingdoms {
                return amountValue <= kingdom.treasuryGold && selectedTargetKingdomId != nil && !otherKingdoms.isEmpty
            }
            return amountValue <= kingdom.treasuryGold
        case "personal":
            return amountValue <= player.gold
        default:
            return false
        }
    }
    
    // MARK: - Result Card
    
    private func resultCard(message: String, isError: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(FontStyles.iconMedium)
                .foregroundColor(isError ? uiConfig.color("royalCrimson") : uiConfig.color("buttonSuccess"))
            
            Text(message)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
        .padding(.horizontal)
    }
    
    // MARK: - Perform Action
    
    @MainActor
    private func performAction() async {
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        guard let action = selectedAction else { return }
        
        isLoading = true
        resultMessage = nil
        
        do {
            switch action.id {
            case "withdraw":
                let response = try await APIClient.shared.withdrawFromTreasury(kingdomId: kingdom.id, amount: amountValue)
                resultMessage = response.message
                isError = false
                player.gold = response.personalGoldNew
                
            case "deposit":
                let response = try await APIClient.shared.depositToTreasury(kingdomId: kingdom.id, amount: amountValue)
                resultMessage = response.message
                isError = false
                player.gold = response.personalGoldRemaining
                
            case "transfer":
                guard let targetId = selectedTargetKingdomId else { return }
                let response = try await APIClient.shared.transferFunds(
                    sourceKingdomId: kingdom.id,
                    targetKingdomId: targetId,
                    amount: amountValue
                )
                resultMessage = response.message
                isError = false
                
            default:
                resultMessage = "Unknown action"
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
