import SwiftUI

/// Market view for purchasing land in kingdoms
struct PropertyMarketView: View {
    @ObservedObject var player: Player
    @State private var availableKingdoms: [KingdomListing] = []
    @State private var showingPurchaseConfirmation = false
    @State private var kingdomToPurchase: KingdomListing?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player resources
                resourcesCard
                
                // Info about land ownership
                landInfoCard
                
                // Available kingdoms
                availableKingdomsSection
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("Buy Land")
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
        .alert("Purchase Land", isPresented: $showingPurchaseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Purchase") {
                purchaseProperty()
            }
        } message: {
            if let kingdom = kingdomToPurchase {
                Text("Buy land in \(kingdom.kingdomName) for \(kingdom.price) gold?")
            }
        }
        .onAppear {
            loadAvailableKingdoms()
        }
    }
    
    // MARK: - Resources Card
    
    private var resourcesCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Gold")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                Text("\(player.gold) gold")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Reputation")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                Text("\(player.reputation)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(player.reputation >= 50 ? .green : .red)
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Land Info Card
    
    private var landInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .font(.system(size: 40))
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Purchase Land")
                        .font(.title3.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Start your property empire")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
            }
            
            Divider()
            
            Text("What You Get:")
                .font(.subheadline.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(alignment: .leading, spacing: 8) {
                benefitRow(text: "50% reduced travel costs to this kingdom")
                benefitRow(text: "Instant travel from anywhere")
                benefitRow(text: "Upgrade to unlock more benefits")
            }
            
            Text("Upgrade your land to build a house, workshop, and more!")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                .padding(.top, 4)
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func benefitRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 14)
            
            Text(text)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    
    // MARK: - Available Kingdoms
    
    private var availableKingdomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available in Nearby Kingdoms")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if availableKingdoms.isEmpty {
                emptyStateView
            } else {
                ForEach(availableKingdoms) { kingdom in
                    KingdomListingCard(
                        kingdom: kingdom,
                        playerGold: player.gold,
                        playerReputation: player.reputation,
                        onPurchase: {
                            kingdomToPurchase = kingdom
                            showingPurchaseConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            
            Text("No land available nearby")
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Helper Functions
    
    private func loadAvailableKingdoms() {
        // TODO: Load from API
        // For now, generate sample listings
        availableKingdoms = [
            KingdomListing(
                id: UUID().uuidString,
                kingdomId: "kingdom1",
                kingdomName: "Ashford",
                price: 500,
                kingdomPopulation: 10
            ),
            KingdomListing(
                id: UUID().uuidString,
                kingdomId: "kingdom2",
                kingdomName: "Riverwatch",
                price: 650,
                kingdomPopulation: 20
            ),
            KingdomListing(
                id: UUID().uuidString,
                kingdomId: "kingdom3",
                kingdomName: "Ironhold",
                price: 750,
                kingdomPopulation: 30
            )
        ]
    }
    
    private func purchaseProperty() {
        guard let kingdom = kingdomToPurchase else { return }
        guard player.gold >= kingdom.price else { return }
        guard player.reputation >= 50 else { return }
        
        player.gold -= kingdom.price
        
        // TODO: Create property via API
        // For now, just deduct gold
        
        dismiss()
    }
}

// MARK: - Kingdom Listing Model

struct KingdomListing: Identifiable {
    let id: String
    let kingdomId: String
    let kingdomName: String
    let price: Int
    let kingdomPopulation: Int
}

// MARK: - Kingdom Listing Card

struct KingdomListingCard: View {
    let kingdom: KingdomListing
    let playerGold: Int
    let playerReputation: Int
    let onPurchase: () -> Void
    
    private var canAfford: Bool {
        playerGold >= kingdom.price
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
                Image(systemName: "map")
                    .font(.system(size: 32))
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kingdom.kingdomName)
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(kingdom.kingdomPopulation) citizens")
                            .font(.caption)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(kingdom.price) gold")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(canAfford ? KingdomTheme.Colors.gold : .red)
                    
                    Text("Land (T1)")
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
                            Text("Need \(kingdom.price - playerGold) more gold")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Button(action: onPurchase) {
                HStack {
                    Image(systemName: "map")
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

