import SwiftUI

enum PropertyDestination: Hashable {
    case market(Kingdom?)
    case tiers(Property?)
}

/// Main Property View - Shows YOUR property directly, not buried behind clicks
struct MyPropertiesView: View {
    @ObservedObject var player: Player
    var currentKingdom: Kingdom?
    @State private var property: Property?
    @State private var activeContract: PropertyAPI.PropertyUpgradeContract?
    @State private var availableRooms: [PropertyAPI.PropertyRoom] = []
    @State private var upgradeStatus: PropertyAPI.PropertyUpgradeStatus?
    @State private var isLoading = true
    @State private var isPurchasingUpgrade = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var navigationPath = NavigationPath()
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    if isLoading {
                        loadingView
                    } else if let property = property, property.tier >= 1 {
                        // YOUR PROPERTY - Front and center (only if actually built, tier >= 1)
                        // Rooms are now inside the property card
                        propertyHeaderSection(property: property)
                        
                        // Unified upgrade section (progress OR button + tiers)
                        if property.tier < TierManager.shared.propertyMaxTier {
                            upgradeSection(property: property)
                        } else {
                            maxLevelSection
                        }
                    } else if activeContract != nil {
                        // Building property (tier 0 or no property yet, but contract exists)
                        constructionOnlyView
                    } else {
                        // No property at all
                        emptyStateView
                    }
                }
                .padding()
            }
            .parchmentBackground()
            .navigationTitle("My Property")
            .navigationBarTitleDisplayMode(.inline)
            .parchmentNavigationBar()
            .navigationDestination(for: PropertyDestination.self) { destination in
                switch destination {
                case .market(let kingdom):
                    PropertyMarketView(
                        player: player,
                        kingdom: kingdom,
                        onPurchaseComplete: {
                            navigationPath = NavigationPath()
                            loadData()
                        }
                    )
                case .tiers(let prop):
                    PropertyTiersView(player: player, property: prop)
                }
            }
            .onAppear {
                loadData()
            }
            .refreshable {
                loadData()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading property...")
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Property Header (Your cozy home - Tamagotchi vibes!)
    
    private func propertyHeaderSection(property: Property) -> some View {
        VStack(spacing: 0) {
            // Sky/roof area with property name
            ZStack {
                // Gradient sky background
                LinearGradient(
                    colors: [
                        Color(red: 0.7, green: 0.85, blue: 0.95),
                        Color(red: 0.85, green: 0.92, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Decorative clouds
                HStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .offset(y: -5)
                    Spacer()
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: 5)
                    Spacer()
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(y: -8)
                }
                .padding(.horizontal, 20)
                
                // Property name floating
                VStack(spacing: 4) {
                    Text(property.tier >= 2 ? "My House" : property.tierName)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Location tag
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10, weight: .bold))
                        if let location = property.location {
                            Text("\(location.capitalized)")
                            Text("•")
                        }
                        Text(property.kingdomName)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.8))
                    )
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Ground area - your home!
            ZStack {
                // Grass background
                Color(red: 0.6, green: 0.8, blue: 0.5)
                
                // Grass texture at top
                VStack {
                    HStack(spacing: 3) {
                        ForEach(0..<20, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(red: 0.5, green: 0.7, blue: 0.4))
                                .frame(width: 4, height: CGFloat.random(in: 8...14))
                                .offset(y: -4)
                        }
                    }
                    Spacer()
                }
                
                // The house/property itself
                VStack(spacing: 0) {
                    // Main building
                    ZStack {
                        // Building shadow
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 124, height: 104)
                            .offset(x: 4, y: 4)
                        
                        // Building body
                        RoundedRectangle(cornerRadius: 16)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .frame(width: 120, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        // Icon inside - house for tier 2+, land icon for tier 1
                        Image(systemName: property.tier >= 2 ? "house.fill" : "rectangle.dashed")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    .offset(y: 10)
                    
                    // Little path/doorstep
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.75, green: 0.65, blue: 0.5))
                        .frame(width: 40, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black, lineWidth: 1.5)
                        )
                        .offset(y: 5)
                }
                
                // Little decorations
                HStack {
                    // Left tree/bush
                    VStack(spacing: -4) {
                        Circle()
                            .fill(Color(red: 0.4, green: 0.65, blue: 0.35))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.55, green: 0.4, blue: 0.3))
                            .frame(width: 8, height: 15)
                    }
                    .offset(y: 20)
                    
                    Spacer()
                    
                    // Right flowers
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1))
                        Circle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1))
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1))
                    }
                    .offset(y: 35)
                }
                .padding(.horizontal, 25)
            }
            .frame(height: 160)
            
            // Footer - rooms & progress
            VStack(spacing: 14) {
                // Your rooms - inside your home!
                if !availableRooms.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(availableRooms, id: \.id) { room in
                            inlineRoomButton(room)
                        }
                    }
                }
                
                // Divider
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 1)
                
                // Progress bar with tier info
                HStack {
                    Text(property.tierDescription)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        ForEach(1...TierManager.shared.propertyMaxTier, id: \.self) { tier in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tier <= property.tier ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkDark.opacity(0.15))
                                .frame(width: 20, height: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.black, lineWidth: tier <= property.tier ? 1 : 0.5)
                                )
                        }
                    }
                }
            }
            .padding()
            .background(KingdomTheme.Colors.parchmentLight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black, lineWidth: 3)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
                .offset(x: 3, y: 3)
        )
    }
    
    // MARK: - Inline Room Button (inside property card)
    
    @ViewBuilder
    private func inlineRoomButton(_ room: PropertyAPI.PropertyRoom) -> some View {
        if room.route == "/workshop" {
            NavigationLink(destination: WorkshopView()) {
                inlineRoomContent(room)
            }
            .buttonStyle(.plain)
        } else {
            inlineRoomContent(room)
        }
    }
    
    private func inlineRoomContent(_ room: PropertyAPI.PropertyRoom) -> some View {
        HStack(spacing: 12) {
            Image(systemName: room.icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorFromString(room.color))
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1.5)
                    }
                )
            
            Text(room.name)
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchment)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1.5)
            }
        )
    }
    
    // MARK: - Unified Upgrade Section
    
    private func upgradeSection(property: Property) -> some View {
        let nextTierName = TierManager.shared.propertyTierName(property.tier + 1)
        
        return VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header: Icon + Title/Description (ActionCard pattern)
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: tierIcon(property.tier + 1))
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(nextTierName)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(TierManager.shared.propertyTierDescription(property.tier + 1))
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            // Cost row (reuses ActionCostRewardRow styling)
            if let status = upgradeStatus {
                ActionCostRewardRow(costs: buildUpgradeCostItems(status: status), rewards: [])
            }
            
            // Button or progress
            if let contract = activeContract {
                constructionProgressView(contract: contract)
            } else if let status = upgradeStatus {
                Button(action: purchaseUpgrade) {
                    HStack(spacing: 8) {
                        if isPurchasingUpgrade {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "hammer.fill")
                            Text("Upgrade")
                        }
                    }
                }
                .buttonStyle(.brutalist(
                    backgroundColor: status.can_afford ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
                    foregroundColor: .white,
                    fullWidth: true
                ))
                .disabled(!status.can_afford || isPurchasingUpgrade)
            }
            
            // Optional: View all tiers link (kept away from button/progress)
            NavigationLink(value: PropertyDestination.tiers(property)) {
                Text("View all tiers →")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }

    private func buildUpgradeCostItems(status: PropertyAPI.PropertyUpgradeStatus) -> [CostItem] {
        var items: [CostItem] = []
        
        // If can't afford overall, all icons go red
        let canAfford = status.can_afford
        
        if let goldCost = status.gold_cost, goldCost > 0 {
            items.append(CostItem(
                icon: "g.circle.fill",
                amount: goldCost,
                canAfford: canAfford
            ))
        }
        
        if status.actions_required > 0 {
            items.append(CostItem(
                icon: "hammer.fill",
                amount: status.actions_required,
                canAfford: canAfford
            ))
        }
        
        if let perActionCosts = status.per_action_costs {
            for cost in perActionCosts where cost.amount > 0 {
                items.append(CostItem(
                    icon: cost.icon,
                    amount: cost.amount,
                    canAfford: canAfford
                ))
            }
        }
        
        return items
    }
    
    // MARK: - Construction Progress
    
    private func constructionProgressView(contract: PropertyAPI.PropertyUpgradeContract) -> some View {
        let progress = Float(contract.actions_completed) / Float(contract.actions_required)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                
                Text("Building in Progress")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        
                        Spacer()
                        
                        Text("\(contract.actions_completed)/\(contract.actions_required)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
            // Progress bar with animated stripes
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(KingdomTheme.Colors.inkDark.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(KingdomTheme.Colors.buttonSuccess)
                                
                                AnimatedStripes()
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.black, lineWidth: 1.5)
                            }
                            .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                        }
                    }
                    .frame(height: 20)
                
                    HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    
                    Text("Complete work actions in the Actions tab")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
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
    }
    
    // MARK: - Max Level Section
    
    private var maxLevelSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(FontStyles.iconExtraLarge)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 16)
            
            Text("Maximum Level")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Your property is fully upgraded!")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Construction Only View (Building first property)
    
    private var constructionOnlyView: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            if let contract = activeContract {
                // Header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: tierIcon(contract.to_tier))
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
                    Text("Building \(contract.target_tier_name)")
                        .font(FontStyles.displaySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let location = contract.location, let kingdom = contract.kingdom_name {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(FontStyles.iconMini)
                            Text("\(location.capitalized) Side • \(kingdom)")
                                .font(FontStyles.labelMedium)
                        }
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                
                // Progress card
                constructionProgressView(contract: contract)
            }
            
            // View all tiers
            NavigationLink(value: PropertyDestination.tiers(nil)) {
            HStack(spacing: 12) {
                Image(systemName: "list.number")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("View All Tiers")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                        Text("See what you're building toward")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding()
        }
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Header
            VStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                
                Text("No Property Yet")
                    .font(FontStyles.displaySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Clear the land and build your estate to unlock powerful benefits")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            
            // Buy Land Button
            NavigationLink(value: PropertyDestination.market(currentKingdom)) {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Buy Land")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if let kingdom = currentKingdom {
                            Text("Purchase in \(kingdom.name)")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else {
                            Text("Enter a kingdom first")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
            }
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            
            // View All Tiers
            NavigationLink(value: PropertyDestination.tiers(nil)) {
                HStack(spacing: 12) {
                    Image(systemName: "list.number")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("View All Tiers")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("See what you can build")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
            }
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
    }
    
    // MARK: - Helpers
    
    private func tierIcon(_ tier: Int) -> String {
        switch tier {
        case 1: return "rectangle.dashed"
        case 2: return "house.fill"
        case 3: return "hammer.fill"
        case 4: return "building.columns.fill"
        case 5: return "crown.fill"
        default: return "building.fill"
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "buttonPrimary": return KingdomTheme.Colors.buttonPrimary
        case "buttonSuccess": return KingdomTheme.Colors.buttonSuccess
        case "buttonDanger": return KingdomTheme.Colors.buttonDanger
        case "buttonWarning": return KingdomTheme.Colors.buttonWarning
        default: return KingdomTheme.Colors.buttonPrimary
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            await MainActor.run { isLoading = true }
            
            do {
                let status = try await propertyAPI.getPropertyStatus()
                
                await MainActor.run {
                    // Get the first property (players can only have one)
                    if let firstProperty = status.properties.first {
                        property = firstProperty.toProperty()
                        availableRooms = firstProperty.available_rooms ?? []
                    } else {
                        property = nil
                        availableRooms = []
                    }
                    
                    // Get active contract
                    activeContract = status.property_upgrade_contracts?.first { $0.status == "in_progress" }
                    
                    isLoading = false
                }
                
                // Load upgrade status if we have a property
                if let prop = property, prop.tier < TierManager.shared.propertyMaxTier {
                    let upStatus = try await propertyAPI.getPropertyUpgradeStatus(propertyId: prop.id)
                    await MainActor.run {
                        upgradeStatus = upStatus
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
                print("❌ Failed to load property: \(error)")
            }
        }
    }
    
    private func purchaseUpgrade() {
        guard let prop = property else { return }
        
        Task {
            await MainActor.run {
                isPurchasingUpgrade = true
            }
            
            do {
                _ = try await propertyAPI.purchasePropertyUpgrade(propertyId: prop.id)
                
                // Refresh player state
                let playerState = try await KingdomAPIService.shared.player.loadState()
                
                await MainActor.run {
                    player.updateFromAPIState(playerState)
                    isPurchasingUpgrade = false
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                
                // Reload data
                loadData()
            } catch {
                await MainActor.run {
                    isPurchasingUpgrade = false
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
                print("❌ Failed to start upgrade: \(error)")
            }
        }
    }
}
