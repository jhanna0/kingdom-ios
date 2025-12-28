import SwiftUI

/// Market view for purchasing new properties
struct PropertyMarketView: View {
    @ObservedObject var player: Player
    @State private var availableProperties: [PropertyListing] = []
    @State private var selectedType: PropertyType = .house
    @State private var showingPurchaseConfirmation = false
    @State private var propertyToPurchase: PropertyListing?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player resources
                resourcesCard
                
                // Type selector
                typeSelector
                
                // Info about selected type
                typeInfoCard
                
                // Available listings
                availableListingsSection
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("Property Market")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.toolbar)
            }
        }
        .alert("Purchase Property", isPresented: $showingPurchaseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Purchase") {
                purchaseProperty()
            }
        } message: {
            if let property = propertyToPurchase {
                Text("Buy \(property.type.rawValue) in \(property.kingdomName) for \(property.price)💰?")
            }
        }
        .onAppear {
            loadAvailableProperties()
        }
    }
    
    // MARK: - Resources Card
    
    private var resourcesCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Gold")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                Text("\(player.gold)💰")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Reputation")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                Text("\(player.reputation)⭐")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(player.reputation >= 50 ? .green : .red)
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Type Selector
    
    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Type")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack(spacing: 12) {
                ForEach(PropertyType.allCases, id: \.self) { type in
                    Button(action: { selectedType = type }) {
                        VStack(spacing: 6) {
                            Text(type.icon)
                                .font(.system(size: 30))
                            
                            Text(type.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(selectedType == type ? .white : KingdomTheme.Colors.inkDark)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedType == type 
                                ? KingdomTheme.Colors.buttonPrimary 
                                : KingdomTheme.Colors.parchmentLight
                        )
                        .cornerRadius(KingdomTheme.CornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.large)
                                .stroke(
                                    selectedType == type 
                                        ? KingdomTheme.Colors.buttonPrimary 
                                        : KingdomTheme.Colors.inkDark.opacity(0.3),
                                    lineWidth: KingdomTheme.BorderWidth.regular
                                )
                        )
                    }
                }
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Type Info Card
    
    private var typeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedType.icon)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedType.rawValue)
                        .font(.title3.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Base Price: \(selectedType.basePrice)💰")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
            }
            
            Divider()
            
            Text("Benefits by Tier:")
                .font(.subheadline.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            switch selectedType {
            case .house:
                houseTierInfo
            case .shop:
                shopTierInfo
            case .personalMine:
                mineTierInfo
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var houseTierInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            tierInfoRow(tier: 1, description: "Badge 'Citizen' + 10 rep bonus")
            tierInfoRow(tier: 2, description: "50% travel costs + instant travel")
            tierInfoRow(tier: 3, description: "🌱 Garden: 10% faster actions")
            tierInfoRow(tier: 4, description: "🏛️ Beautiful: 50% tax reduction")
            tierInfoRow(tier: 5, description: "🛡️ Fortified: 50% survive conquest")
        }
    }
    
    private var shopTierInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            tierInfoRow(tier: 1, description: "💰 10 gold per day")
            tierInfoRow(tier: 2, description: "💰 25 gold per day")
            tierInfoRow(tier: 3, description: "💰 50 gold per day")
            tierInfoRow(tier: 4, description: "💰 100 gold per day")
            tierInfoRow(tier: 5, description: "💰 200 gold per day")
        }
    }
    
    private var mineTierInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            tierInfoRow(tier: 1, description: "⚒️ 5 iron/day, no taxes")
            tierInfoRow(tier: 2, description: "⚒️ 10 iron + 🛡️ 2 steel/day")
            tierInfoRow(tier: 3, description: "⚒️ 15 iron + 🛡️ 5 steel/day")
            tierInfoRow(tier: 4, description: "⚒️ 20 iron + 🛡️ 10 steel/day")
            tierInfoRow(tier: 5, description: "⚒️ 25 iron + 🛡️ 15 steel/day")
        }
    }
    
    private func tierInfoRow(tier: Int, description: String) -> some View {
        HStack(spacing: 8) {
            Text("Tier \(tier)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(KingdomTheme.Colors.gold)
                .cornerRadius(4)
            
            Text(description)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Spacer()
        }
    }
    
    // MARK: - Available Listings
    
    private var availableListingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available in Nearby Kingdoms")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            let filteredListings = availableProperties.filter { $0.type == selectedType }
            
            if filteredListings.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredListings) { listing in
                    PropertyListingCard(
                        listing: listing,
                        playerGold: player.gold,
                        playerReputation: player.reputation,
                        onPurchase: {
                            propertyToPurchase = listing
                            showingPurchaseConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            
            Text("No properties available")
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Helper Functions
    
    private func loadAvailableProperties() {
        // TODO: Load from API
        // For now, generate sample listings
        availableProperties = [
            PropertyListing(
                id: UUID().uuidString,
                type: .house,
                kingdomId: "kingdom1",
                kingdomName: "Ashford",
                price: 500,
                kingdomPopulation: 10
            ),
            PropertyListing(
                id: UUID().uuidString,
                type: .house,
                kingdomId: "kingdom2",
                kingdomName: "Riverwatch",
                price: 650,
                kingdomPopulation: 20
            ),
            PropertyListing(
                id: UUID().uuidString,
                type: .shop,
                kingdomId: "kingdom1",
                kingdomName: "Ashford",
                price: 1000,
                kingdomPopulation: 10
            ),
            PropertyListing(
                id: UUID().uuidString,
                type: .personalMine,
                kingdomId: "kingdom2",
                kingdomName: "Riverwatch",
                price: 2100,
                kingdomPopulation: 20
            )
        ]
    }
    
    private func purchaseProperty() {
        guard let listing = propertyToPurchase else { return }
        guard player.gold >= listing.price else { return }
        guard player.reputation >= 50 else { return }
        
        player.gold -= listing.price
        
        // TODO: Create property via API
        // For now, just deduct gold
        
        dismiss()
    }
}

// MARK: - Property Listing Model

struct PropertyListing: Identifiable {
    let id: String
    let type: PropertyType
    let kingdomId: String
    let kingdomName: String
    let price: Int
    let kingdomPopulation: Int
}

// MARK: - Property Listing Card

struct PropertyListingCard: View {
    let listing: PropertyListing
    let playerGold: Int
    let playerReputation: Int
    let onPurchase: () -> Void
    
    private var canAfford: Bool {
        playerGold >= listing.price
    }
    
    private var hasReputation: Bool {
        playerReputation >= 50
    }
    
    private var canPurchase: Bool {
        canAfford && hasReputation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(listing.type.icon)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.kingdomName)
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(listing.kingdomPopulation) citizens")
                            .font(.caption)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(listing.price)💰")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(canAfford ? KingdomTheme.Colors.gold : .red)
                    
                    Text("Tier 1")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
            }
            
            if !canPurchase {
                VStack(alignment: .leading, spacing: 6) {
                    if !hasReputation {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text("Need 50+ reputation")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                    
                    if !canAfford {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text("Need \(listing.price - playerGold) more gold")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Button(action: onPurchase) {
                HStack {
                    Image(systemName: "cart.fill")
                    Text("Purchase Land")
                }
            }
            .buttonStyle(.medieval(color: canPurchase ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkDark.opacity(0.3), fullWidth: true))
            .disabled(!canPurchase)
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Preview

struct PropertyMarketView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PropertyMarketView(player: {
                let p = Player(name: "Test Player")
                p.gold = 1500
                p.reputation = 150
                return p
            }())
        }
    }
}

