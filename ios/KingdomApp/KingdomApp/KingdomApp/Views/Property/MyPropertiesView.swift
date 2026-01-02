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
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigationPath = NavigationPath()
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.xLarge) {
                    // Properties list or empty state
                    if properties.isEmpty {
                        emptyStateView
                    } else {
                        propertySection
                    }
                    
                    // ALWAYS show tier benefits - whether user owns property or not
                    propertyBenefitsSection
                }
                .padding(.vertical)
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
                .padding(.horizontal)
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
        .padding(.horizontal)
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
            .padding(.horizontal)
            
            // Buy Land Button - prominent
            NavigationLink(value: PropertyDestination.market(currentKingdom)) {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                    
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
            .padding(.horizontal)
        }
    }
    
    // MARK: - Property Benefits Section (ALWAYS visible)
    
    private var propertyBenefitsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Section header
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "star.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Property Benefits")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Unlock by upgrading your property")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            // All tier benefits
            VStack(spacing: 12) {
                tierBenefitRow(
                    tier: 1,
                    icon: "square.dashed",
                    name: "Land",
                    benefit: "-50% travel cost to this kingdom",
                    isUnlocked: currentPropertyTier >= 1
                )
                
                tierBenefitRow(
                    tier: 2,
                    icon: "house.fill",
                    name: "House",
                    benefit: "Set as home base for respawning",
                    isUnlocked: currentPropertyTier >= 2
                )
                
                tierBenefitRow(
                    tier: 3,
                    icon: "hammer.fill",
                    name: "Workshop",
                    benefit: "Unlock crafting • -15% craft time",
                    isUnlocked: currentPropertyTier >= 3
                )
                
                tierBenefitRow(
                    tier: 4,
                    icon: "building.columns.fill",
                    name: "Beautiful Property",
                    benefit: "Tax exemption - pay 0% taxes",
                    isUnlocked: currentPropertyTier >= 4
                )
                
                tierBenefitRow(
                    tier: 5,
                    icon: "crown.fill",
                    name: "Estate",
                    benefit: "50% chance to survive conquest",
                    isUnlocked: currentPropertyTier >= 5
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private var currentPropertyTier: Int {
        properties.first?.tier ?? 0
    }
    
    private func tierBenefitRow(tier: Int, icon: String, name: String, benefit: String, isUnlocked: Bool) -> some View {
        HStack(spacing: 14) {
            // Tier icon
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .brutalistBadge(
                    backgroundColor: isUnlocked ? tierColor(for: tier) : KingdomTheme.Colors.inkLight,
                    cornerRadius: 10,
                    shadowOffset: isUnlocked ? 2 : 0,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Tier \(tier)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(isUnlocked ? tierColor(for: tier) : KingdomTheme.Colors.inkMedium)
                    
                    Text("•")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text(name)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(isUnlocked ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                }
                
                Text(benefit)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(isUnlocked ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.gold)
            } else {
                Image(systemName: "lock.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding(12)
        .background(isUnlocked ? tierColor(for: tier).opacity(0.08) : Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isUnlocked ? tierColor(for: tier).opacity(0.3) : KingdomTheme.Colors.inkDark.opacity(0.1), lineWidth: 1.5)
        )
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
        case 3: return KingdomTheme.Colors.goldWarm
        case 4: return KingdomTheme.Colors.gold
        case 5: return KingdomTheme.Colors.gold
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
                    .foregroundColor(KingdomTheme.Colors.gold)
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
                let fetchedProperties = try await propertyAPI.getPlayerProperties()
                await MainActor.run {
                    properties = fetchedProperties
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    properties = []
                }
                print("❌ Failed to load properties: \(error)")
            }
        }
    }
}
