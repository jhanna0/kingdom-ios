import SwiftUI

enum PropertyDestination: Hashable {
    case detail(Property)
    case market
}

/// View showing all properties owned by the player
struct MyPropertiesView: View {
    @ObservedObject var player: Player
    @State private var properties: [Property] = []
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                // Header with stats
                statsCard
                
                // Properties list
                if properties.isEmpty {
                    emptyStateView
                } else {
                    propertiesSection
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("My Properties")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: PropertyDestination.market) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Buy")
                    }
                }
                .buttonStyle(.toolbar)
            }
        }
        .navigationDestination(for: PropertyDestination.self) { destination in
            switch destination {
            case .detail(let property):
                PropertyDetailView(player: player, property: property)
            case .market:
                PropertyMarketView(player: player)
            }
        }
        .onAppear {
            loadProperties()
        }
        }
    }
    
    // MARK: - Stats Card
    
    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(properties.count)")
                        .font(.title.bold().monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text(properties.count == 1 ? "Property Owned" : "Properties Owned")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(totalValue) gold")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("Total Value")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Properties Section
    
    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Properties")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            ForEach(properties) { property in
                NavigationLink(value: PropertyDestination.detail(property)) {
                    PropertyCard(
                        property: property,
                        showOwner: false
                    )
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            
            Text("No Properties Yet")
                .font(.title3.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Purchase land in kingdoms to unlock travel benefits, then upgrade to unlock crafting and tax exemptions!")
                .font(.body)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            NavigationLink(value: PropertyDestination.market) {
                HStack(spacing: 8) {
                    Image(systemName: "map")
                    Text("Buy Land")
                }
            }
            .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonPrimary))
            .padding(.top, 8)
            
            // Requirements hint
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 40)
                
                Text("Requirements:")
                    .font(.caption.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                requirementRow(
                    icon: "star.fill",
                    text: "50+ reputation in kingdom",
                    met: player.reputation >= 50
                )
                
                requirementRow(
                    icon: "dollarsign.circle.fill",
                    text: "Enough gold for purchase",
                    met: player.gold >= 500
                )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func requirementRow(icon: String, text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(met ? .green : .red)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Spacer()
            
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(met ? .green : .red)
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalValue: Int {
        properties.reduce(0) { $0 + $1.currentValue }
    }
    
    // MARK: - Helper Functions
    
    private func loadProperties() {
        // TODO: Load from API or local storage
        // For now, use sample data - filter by converting playerId to String
        let playerIdString = String(player.playerId)
        properties = Property.samples.filter { $0.ownerId == playerIdString }
        
        // If no properties match, show sample properties for demo purposes
        if properties.isEmpty {
            properties = Property.samples
        }
    }
}

// MARK: - Preview

struct MyPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MyPropertiesView(player: {
                let p = Player(name: "Test Player")
                p.gold = 1000
                p.reputation = 150
                return p
            }())
        }
    }
}

