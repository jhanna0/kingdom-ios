import SwiftUI

/// Detailed view of a single property with upgrade options
struct PropertyDetailView: View {
    @ObservedObject var player: Player
    @State private var property: Property
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var propertyUpgradeContracts: [PropertyUpgradeContract] = []
    @State private var isLoadingContracts = true
    @State private var upgradeStatus: PropertyAPI.PropertyUpgradeStatus?
    @State private var isLoadingUpgradeStatus = true
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
    init(player: Player, property: Property) {
        self.player = player
        self._property = State(initialValue: property)
    }
    
    // Active upgrade contract for this property
    private var activeContract: PropertyUpgradeContract? {
        propertyUpgradeContracts.first { 
            $0.propertyId == property.id && $0.status != "completed" 
        }
    }
    
    // Check if ANY property upgrade is in progress (block multiple upgrades)
    private var hasAnyPropertyUpgradeInProgress: Bool {
        propertyUpgradeContracts.contains { $0.status != "completed" }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with property tier and name
                headerCard
                
                // Location info
                locationCard
                
                // Upgrade section
                if property.tier < TierManager.shared.propertyMaxTier {
                    upgradeCard
                } else {
                    maxLevelCard
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle(property.tierName)
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .task {
            await loadPropertyContracts()
            await loadUpgradeStatus()
        }
        .refreshable {
            await loadPropertyContracts()
            await refreshProperty()
            await loadUpgradeStatus()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            // Visual representation
            tierVisual
                .padding(.bottom, 8)
            
            Text(property.tierName)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(property.tierDescription)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            // Tier progress with brutalist style (dynamic from backend)
            HStack(spacing: 8) {
                ForEach(1...TierManager.shared.propertyMaxTier, id: \.self) { tier in
                    Circle()
                        .fill(tier <= property.tier ? tierColor : KingdomTheme.Colors.inkDark.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: tier <= property.tier ? 1.5 : 0.5)
                        )
                }
            }
            
            Text("Tier \(property.tier) of 5")
                .font(FontStyles.labelBold)
                .foregroundColor(tierColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Tier Visual (FULLY DYNAMIC from backend)
    
    private var tierVisual: some View {
        ZStack {
            // Background with brutalist style
            RoundedRectangle(cornerRadius: 12)
                .fill(tierColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2)
                )
                .frame(height: 120)
            
            // Icon and name from backend
            VStack(spacing: 8) {
                Image(systemName: TierManager.shared.propertyTierIcon(property.tier))
                    .font(.system(size: 60))
                    .foregroundColor(tierColor)
                Text(TierManager.shared.propertyTierName(property.tier))
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
    }
    
    private var tierColor: Color {
        // Consistent green for all property tiers
        return KingdomTheme.Colors.buttonSuccess
    }
    
    // MARK: - Location Card
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(property.kingdomName)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Purchased \(formatDate(property.purchasedAt))")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    
    // MARK: - Upgrade Card
    
    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to \(nextTierName)")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(nextTierDescription)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            // Cost breakdown from backend
            if let status = upgradeStatus {
                VStack(alignment: .leading, spacing: 8) {
                    // Gold cost (paid upfront to start)
                    if let goldCost = status.gold_cost, goldCost > 0 {
                        HStack(spacing: 8) {
                            Text("To start:")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 11))
                                Text("\(goldCost)")
                                    .font(FontStyles.labelBold)
                            }
                            .foregroundColor(status.can_afford ? KingdomTheme.Colors.inkDark : .red)
                        }
                    }
                    
                    // Per-action costs (required during each work action)
                    if let perActionCosts = status.per_action_costs, !perActionCosts.isEmpty {
                        HStack(spacing: 8) {
                            Text("Per action:")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            ForEach(perActionCosts, id: \.resource) { cost in
                                HStack(spacing: 2) {
                                    Image(systemName: cost.icon)
                                        .font(.system(size: 11))
                                    Text("\(cost.amount)")
                                        .font(FontStyles.labelBold)
                                }
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            }
                            
                            Text("(\(status.actions_required) actions)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    
                    // Total resources needed (for reference)
                    if let totalCosts = status.total_costs, !totalCosts.isEmpty {
                        HStack(spacing: 8) {
                            Text("Total resources:")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            ForEach(totalCosts, id: \.resource) { cost in
                                HStack(spacing: 2) {
                                    Image(systemName: cost.icon)
                                        .font(.system(size: 11))
                                    Text("\(cost.total_amount)")
                                        .font(FontStyles.labelBold)
                                }
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Show active contract if one exists
            if let contract = activeContract {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        
                        Text("Upgrade In Progress")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                    
                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Building \(contract.targetTierName)")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Text("\(contract.actionsCompleted) / \(contract.actionsRequired)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                    .frame(height: 8)
                                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                
                                Rectangle()
                                    .fill(KingdomTheme.Colors.buttonSuccess)
                                    .frame(width: geometry.size.width * contract.progress, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    
                    Text("Complete work actions in the Actions page to finish this upgrade")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            } else if isPurchasing {
                // Show purchasing state with loading indicator
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: KingdomTheme.Colors.buttonSuccess))
                            .scaleEffect(1.2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Starting Upgrade...")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Creating contract...")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                // No active contract - show purchase button
                if isLoadingUpgradeStatus {
                    ProgressView()
                        .padding()
                } else if let status = upgradeStatus {
                    // Button shows gold cost
                    let goldCost = status.gold_cost ?? 0
                    Button(action: purchaseUpgrade) {
                        HStack(spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Start Upgrade (\(goldCost)g)")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: (status.can_afford && !hasAnyPropertyUpgradeInProgress) ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    .disabled(!status.can_afford || hasAnyPropertyUpgradeInProgress)
                    .transition(.opacity)
                    
                    // Explain the per-action resource system
                    if let perActionCosts = status.per_action_costs, !perActionCosts.isEmpty {
                        let perActionStr = perActionCosts.map { "\($0.amount) \($0.display_name.lowercased())" }.joined(separator: ", ")
                        Text("Each work action will require \(perActionStr)")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    } else {
                        Text("Complete work actions in the Actions page to finish")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    // Show if not enough gold
                    if !status.can_afford {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(FontStyles.iconMini)
                            Text("Need \(goldCost - (status.player_gold ?? 0)) more gold")
                                .font(FontStyles.labelSmall)
                        }
                        .foregroundColor(.red)
                    }
                    
                    if hasAnyPropertyUpgradeInProgress {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(FontStyles.iconMini)
                            Text("You already have a property upgrade in progress")
                                .font(FontStyles.labelSmall)
                        }
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    private var nextTierName: String {
        TierManager.shared.propertyTierName(property.tier + 1)
    }
    
    private var nextTierDescription: String {
        TierManager.shared.propertyTierDescription(property.tier + 1)
    }
    
    // MARK: - Max Level Card
    
    private var maxLevelCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(FontStyles.iconExtraLarge)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 16)
            
            Text("Maximum Level")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("This property is fully upgraded with all benefits unlocked!")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.buttonSuccess.opacity(0.1))
    }
    
    
    private func tierNameFor(_ tier: Int) -> String {
        TierManager.shared.propertyTierName(tier)
    }
    
    private func tierBenefitsFor(_ tier: Int) -> String {
        // Return first benefit as summary, or empty string
        TierManager.shared.propertyTierBenefits(tier).first ?? ""
    }
    
    // MARK: - Helper Functions
    
    private func loadPropertyContracts() async {
        print("🔍 PropertyDetailView: loadPropertyContracts() CALLED")
        do {
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            print("✅ PropertyDetailView: Got action status response")
            await MainActor.run {
                propertyUpgradeContracts = status.propertyUpgradeContracts ?? []
                isLoadingContracts = false
            }
        } catch {
            await MainActor.run {
                isLoadingContracts = false
            }
        }
    }
    
    private func refreshProperty() async {
        do {
            let updatedProperty = try await propertyAPI.getProperty(propertyId: property.id)
            await MainActor.run {
                property = updatedProperty
            }
        } catch {
            print("Failed to refresh property: \(error)")
        }
    }
    
    private func loadUpgradeStatus() async {
        do {
            let status = try await propertyAPI.getPropertyUpgradeStatus(propertyId: property.id)
            await MainActor.run {
                upgradeStatus = status
                isLoadingUpgradeStatus = false
            }
        } catch {
            print("Failed to load upgrade status: \(error)")
            await MainActor.run {
                isLoadingUpgradeStatus = false
            }
        }
    }
    
    private func purchaseUpgrade() {
        // Backend will validate gold and all requirements
        guard !hasAnyPropertyUpgradeInProgress else {
            errorMessage = "You already have a property upgrade in progress. Complete it before starting a new one."
            showError = true
            return
        }
        
        Task {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPurchasing = true
                }
            }
            
            do {
                let response = try await propertyAPI.purchasePropertyUpgrade(propertyId: property.id)
                
                // Refresh player state to get updated gold
                let playerState = try await KingdomAPIService.shared.player.loadState()
                
                // Reload contracts and upgrade status
                await loadPropertyContracts()
                await loadUpgradeStatus()
                
                await MainActor.run {
                    player.updateFromAPIState(playerState)
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPurchasing = false
                    }
                    
                    // Haptic feedback for success
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Started upgrade to \(response.message): \(response.actionsRequired) actions required")
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPurchasing = false
                    }
                    
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    // Haptic feedback for error
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
                print("❌ Failed to purchase upgrade: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


