import SwiftUI

enum PropertyDestination: Hashable {
    case detail(Property)
    case market
    case tierBenefits
}

/// View showing all properties owned by the player
struct MyPropertiesView: View {
    @ObservedObject var player: Player
    @State private var properties: [Property] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // Properties list
                if properties.isEmpty {
                    emptyStateView
                } else {
                    propertySection
                }
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
            case .market:
                PropertyMarketView(player: player)
            case .tierBenefits:
                TierBenefitsView()
            }
        }
        .onAppear {
            loadProperties()
        }
        }
    }
    
    // MARK: - Property Section
    
    private var propertySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let property = properties.first {
                // Property overview card
                propertyOverviewCard(property: property)
                
                // Benefits card
                benefitsCard(property: property)
                
                // Action buttons
                HStack(spacing: 12) {
                    NavigationLink(value: PropertyDestination.tierBenefits) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("View All Tiers")
                        }
                    }
                    .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSecondary, fullWidth: true))
                    
                    NavigationLink(value: PropertyDestination.detail(property)) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Upgrade")
                        }
                    }
                    .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
                }
            }
        }
    }
    
    private func propertyOverviewCard(property: Property) -> some View {
        VStack(spacing: 16) {
            // Tier visual
            ZStack {
                LinearGradient(
                    colors: [tierColor(for: property.tier).opacity(0.15), tierColor(for: property.tier).opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)
                .cornerRadius(8)
                
                tierIcon(for: property.tier)
            }
            
            // Tier name and progress
            VStack(spacing: 8) {
                Text(property.tierName)
                    .font(.title2.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let location = property.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text("\(location.capitalized) Side")
                            .font(.caption)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                }
                
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { tier in
                        Circle()
                            .fill(tier <= property.tier ? tierColor(for: property.tier) : KingdomTheme.Colors.inkDark.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text("Tier \(property.tier) of 5")
                    .font(.caption.bold())
                    .foregroundColor(tierColor(for: property.tier))
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func benefitsCard(property: Property) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Benefits")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(alignment: .leading, spacing: 10) {
                // Tier 1 benefits
                benefitRow(
                    icon: "airplane",
                    text: "Instant travel",
                    isActive: property.tier >= 1
                )
                
                // Tier 2 benefits
                benefitRow(
                    icon: "house.fill",
                    text: "Residence",
                    isActive: property.tier >= 2
                )
                
                // Tier 3 benefits
                benefitRow(
                    icon: "hammer.fill",
                    text: "Crafting",
                    isActive: property.tier >= 3
                )
                
                // Tier 4 benefits
                benefitRow(
                    icon: "dollarsign.circle.fill",
                    text: "No taxes",
                    isActive: property.tier >= 4
                )
                
                // Tier 5 benefits
                benefitRow(
                    icon: "shield.fill",
                    text: "Conquest protection",
                    isActive: property.tier >= 5
                )
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func benefitRow(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? icon : "lock.fill")
                .font(.body)
                .foregroundColor(isActive ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isActive ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkDark.opacity(0.5))
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 60))
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                
                Text("No Property")
                    .font(.title3.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Clear the land and build your estate")
                    .font(.body)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            .padding(.horizontal)
            
            // View Tiers Card
            NavigationLink(value: PropertyDestination.tierBenefits) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .font(.title2)
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .frame(width: 50, height: 50)
                        .background(KingdomTheme.Colors.gold.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Property Tiers")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("See all 5 tiers and benefits")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                }
                .padding()
                .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            }
            .padding(.horizontal)
            
            // Buy Land Card
            NavigationLink(value: PropertyDestination.market) {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        .frame(width: 50, height: 50)
                        .background(KingdomTheme.Colors.buttonPrimary.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buy Land")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("Purchase land in this kingdom")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                }
                .padding()
                .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    
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


