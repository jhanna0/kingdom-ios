import SwiftUI

enum PropertyDestination: Hashable {
    case detail(Property)
    case market(Kingdom?)
}

/// View showing all properties owned by the player - Brutalist style
struct MyPropertiesView: View {
    @ObservedObject var player: Player
    var currentKingdom: Kingdom?
    @State private var properties: [Property] = []
    @State private var activeContracts: [PropertyAPI.PropertyUpgradeContract] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigationPath = NavigationPath()
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.xLarge) {
                    // Active contracts (construction OR upgrade)
                    if !activeContracts.isEmpty {
                        contractsSection
                    }
                    
                    // Properties list
                    if !properties.isEmpty {
                        propertySection
                    }
                    
                    // Empty state (only if no properties AND no contracts)
                    if properties.isEmpty && activeContracts.isEmpty {
                        emptyStateView
                    }
                    
                    // Always show View All Tiers button
                    viewAllTiersButton
                }
                .padding()
            }
            .parchmentBackground()
            .navigationTitle("My Property")
            .navigationBarTitleDisplayMode(.inline)
            .parchmentNavigationBar()
            .navigationDestination(for: PropertyDestination.self) { destination in
                switch destination {
                case .detail(let property):
                    PropertyDetailView(player: player, property: property)
                case .market(let kingdom):
                    PropertyMarketView(
                        player: player,
                        kingdom: kingdom,
                        onPurchaseComplete: {
                            // Pop back to root and reload
                            navigationPath = NavigationPath()
                            loadProperties()
                        }
                    )
                }
            }
            .onAppear {
                loadProperties()
            }
            .refreshable {
                loadProperties()
            }
        }
    }
    
    // MARK: - Active Contracts Section (VISUAL property cards showing construction)
    
    private var contractsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            ForEach(activeContracts, id: \.contract_id) { contract in
                propertyUnderConstructionCard(contract: contract)
            }
        }
    }
    
    private func propertyUnderConstructionCard(contract: PropertyAPI.PropertyUpgradeContract) -> some View {
        let targetTier = contract.to_tier
        let progress = Float(contract.actions_completed) / Float(contract.actions_required)
        
        return VStack(spacing: 0) {
            // Top section - Property visual with construction badge
            ZStack(alignment: .topTrailing) {
                // Property icon showcase
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tierColor(for: targetTier).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    // Show the ACTUAL property icon (square outline for land, etc)
                    tierIcon(for: targetTier)
                        .opacity(0.4 + (Double(progress) * 0.6)) // Fade in as construction progresses
                }
                .frame(height: 140)
                
                // Construction badge overlay
                HStack(spacing: 4) {
                    Image(systemName: "hammer.fill")
                        .font(FontStyles.iconMini)
                    Text("Building")
                        .font(FontStyles.labelBold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonWarning,
                    cornerRadius: 6,
                    shadowOffset: 3,
                    borderWidth: 2
                )
                .padding(12)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Property details
            VStack(spacing: KingdomTheme.Spacing.medium) {
                // Title and location
                VStack(spacing: 6) {
                    Text(contract.target_tier_name)
                        .font(FontStyles.displaySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let location = contract.location, let kingdomName = contract.kingdom_name {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(FontStyles.iconMini)
                            Text("\(location.capitalized) Side")
                                .font(FontStyles.labelMedium)
                            Text("•")
                                .font(FontStyles.labelMedium)
                            Text(kingdomName)
                                .font(FontStyles.labelMedium)
                        }
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Divider
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 1)
                
                // Progress section
                VStack(spacing: 10) {
                    HStack(alignment: .center) {
                        Text("Construction Progress")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Spacer()
                        
                        Text("\(contract.actions_completed)/\(contract.actions_required)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
                    // Animated progress bar with stripes
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(KingdomTheme.Colors.inkDark.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            
                            // Progress fill with animated stripes
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(KingdomTheme.Colors.buttonWarning)
                                
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
                }
                
                // Instruction text
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    
                    Text("Complete work actions in the Actions tab")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Property Section (when user owns property)
    
    private var propertySection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            if let property = properties.first {
                // Property overview card - brutalist style
                propertyOverviewCard(property: property)
                
                // Action button - navigate to detail/upgrade
                NavigationLink(value: PropertyDestination.detail(property)) {
                    propertyActionButton(property: property)
                }
            }
        }
    }
    
    private func propertyOverviewCard(property: Property) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Tier visual with brutalist style
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tierColor(for: property.tier).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .frame(height: 100)
                
                tierIcon(for: property.tier)
            }
            
            // Tier name and progress
            VStack(spacing: 8) {
                Text(property.tierName)
                    .font(FontStyles.displaySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let location = property.location {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(FontStyles.iconMini)
                        Text("\(location.capitalized) Side • \(property.kingdomName)")
                            .font(FontStyles.labelMedium)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                // Tier progress dots with brutalist style
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { tier in
                        Circle()
                            .fill(tier <= property.tier ? tierColor(for: property.tier) : KingdomTheme.Colors.inkDark.opacity(0.15))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: tier <= property.tier ? 1.5 : 0.5)
                            )
                    }
                }
                
                Text("Tier \(property.tier) of 5")
                    .font(FontStyles.labelBold)
                    .foregroundColor(tierColor(for: property.tier))
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func propertyActionButton(property: Property) -> some View {
        HStack(spacing: 14) {
            Image(systemName: tierIconName(for: property.tier))
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .brutalistBadge(
                    backgroundColor: tierColor(for: property.tier),
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(property.tier < 5 ? "Upgrade Property" : "View Property")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(property.tier < 5 ? "Next: Tier \(property.tier + 1) - \(tierName(for: property.tier + 1))" : "Maximum tier reached")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("T\(property.tier)")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(tierColor(for: property.tier))
                
                Image(systemName: "chevron.right")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment)
    }
    
    // MARK: - View All Tiers Button
    
    private var viewAllTiersButton: some View {
        NavigationLink(destination: PropertyTiersView(player: player, property: properties.first)) {
            HStack(spacing: 12) {
                Image(systemName: "list.number")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("View All Tiers")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("See upgrade path & benefits")
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Header with brutalist style
            VStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                
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
            
            // Buy Land Button - prominent
            NavigationLink(value: PropertyDestination.market(currentKingdom)) {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                    
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
        }
    }
    
    // MARK: - Helper Functions
    
    private func tierName(for tier: Int) -> String {
        switch tier {
        case 1: return "Land"
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"
        default: return "Property"
        }
    }
    
    private func tierIconName(for tier: Int) -> String {
        switch tier {
        case 1: return "rectangle.dashed"
        case 2: return "house.fill"
        case 3: return "hammer.fill"
        case 4: return "building.columns.fill"
        case 5: return "crown.fill"
        default: return "building.fill"
        }
    }
    
    private func tierColor(for tier: Int) -> Color {
        switch tier {
        case 1: return KingdomTheme.Colors.buttonSecondary
        case 2: return KingdomTheme.Colors.buttonPrimary
        case 3: return KingdomTheme.Colors.inkMedium
        case 4: return KingdomTheme.Colors.inkMedium
        case 5: return KingdomTheme.Colors.inkMedium
        default: return KingdomTheme.Colors.inkDark
        }
    }
    
    @ViewBuilder
    private func tierIcon(for tier: Int) -> some View {
        switch tier {
        case 1:
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(tierColor(for: tier))
        case 2:
            Image(systemName: "house.fill")
                .font(.system(size: 50))
                .foregroundColor(tierColor(for: tier))
        case 3:
            HStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tierColor(for: tier))
                Image(systemName: "hammer.fill")
                    .font(.system(size: 35))
                    .foregroundColor(tierColor(for: tier).opacity(0.8))
                    .offset(y: 10)
            }
        case 4:
            Image(systemName: "building.columns.fill")
                .font(.system(size: 50))
                .foregroundColor(tierColor(for: tier))
        case 5:
            VStack(spacing: -5) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 25))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 45))
                    .foregroundColor(tierColor(for: tier))
            }
        default:
            Image(systemName: "questionmark")
                .font(.system(size: 50))
                .foregroundColor(tierColor(for: tier))
        }
    }
    
    private func loadProperties() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let status = try await propertyAPI.getPropertyStatus()
                await MainActor.run {
                    properties = status.properties.map { $0.toProperty() }
                    
                    // Get all in-progress contracts (construction OR upgrades)
                    activeContracts = status.property_upgrade_contracts?.filter { $0.status == "in_progress" } ?? []
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    properties = []
                    activeContracts = []
                }
                print("❌ Failed to load property status: \(error)")
            }
        }
    }
}

