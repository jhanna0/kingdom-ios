import SwiftUI

enum PropertyDestination: Hashable {
    case detail(Property)
    case market(Kingdom?)
}

/// View showing all properties owned by the player
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
    
    // MARK: - Property Section
    
    private var propertySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let property = properties.first {
                // Property overview card
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
        .padding(.horizontal)
    }
    
    private func propertyActionButton(property: Property) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tierIconName(for: property.tier))
                .font(.title3)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(property.tier < 5 ? "Upgrade Property" : "View Property")
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(property.tier < 5 ? "Upgrade to Tier \(property.tier + 1): \(tierName(for: property.tier + 1))" : "Maximum tier reached")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("T\(property.tier)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            }
        }
        .padding()
        .background(KingdomTheme.Colors.inkDark.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 1)
        )
    }
    
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
        case 5: return "shield.fill"
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
            
            // Buy Land Card
            NavigationLink(value: PropertyDestination.market(currentKingdom)) {
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


