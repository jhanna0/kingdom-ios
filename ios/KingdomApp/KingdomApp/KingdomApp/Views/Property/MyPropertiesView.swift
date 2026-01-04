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
        let progress = Float(contract.actions_completed) / Float(contract.actions_required)
        
        return VStack(spacing: 0) {
            // Top section - Icon badge with construction overlay
            HStack(spacing: 14) {
                // Property icon in brutalist badge with construction overlay
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tierIconName(for: contract.to_tier))
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.buttonSuccess,
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    // Construction indicator
                    Circle()
                        .fill(KingdomTheme.Colors.buttonWarning)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contract.target_tier_name)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let location = contract.location, let kingdomName = contract.kingdom_name {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(FontStyles.iconMini)
                            Text("\(location.capitalized) Side • \(kingdomName)")
                                .font(FontStyles.labelMedium)
                        }
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
                
                // Building badge
                HStack(spacing: 4) {
                    Image(systemName: "hammer.fill")
                        .font(FontStyles.iconMini)
                    Text("Building")
                        .font(FontStyles.labelSmall)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .offset(x: 1, y: 1)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    }
                )
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
                }
                
                // Instruction text
                    HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    
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
                // Property card - tap to view details
                NavigationLink(value: PropertyDestination.detail(property)) {
                    PropertyCard(property: property)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - View All Tiers Button
    
    private var viewAllTiersButton: some View {
        NavigationLink(destination: PropertyTiersView(player: player, property: properties.first)) {
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

