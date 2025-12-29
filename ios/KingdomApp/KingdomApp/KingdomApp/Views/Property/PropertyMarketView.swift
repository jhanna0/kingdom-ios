import SwiftUI

/// Market view for purchasing land in the current kingdom
struct PropertyMarketView: View {
    @ObservedObject var player: Player
    @State private var selectedLocation: String = "north"
    @State private var showingPurchaseConfirmation = false
    @State private var landPrice: Int = 500
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Player resources
                resourcesCard
                
                // Location selection
                locationSelectionCard
                
                // Purchase card
                purchaseCard
            }
            .padding(.vertical)
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
                Task {
                    await purchaseProperty()
                }
            }
        } message: {
            Text("Clear the forest on the \(selectedLocation) side and claim this land for \(landPrice) gold?")
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
        .padding(.horizontal)
    }
    
    // MARK: - Location Selection Card
    
    private var locationSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Location")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Where would you like to build?")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            // Location grid - 2x2
            VStack(spacing: 12) {
                // North
                locationButton(location: "north", icon: "arrow.up.circle.fill", label: "North")
                
                HStack(spacing: 12) {
                    // West
                    locationButton(location: "west", icon: "arrow.left.circle.fill", label: "West")
                    
                    // East
                    locationButton(location: "east", icon: "arrow.right.circle.fill", label: "East")
                }
                
                // South
                locationButton(location: "south", icon: "arrow.down.circle.fill", label: "South")
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private func locationButton(location: String, icon: String, label: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedLocation = location
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(selectedLocation == location ? .white : KingdomTheme.Colors.inkDark)
                    .frame(width: 28)
                
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(selectedLocation == location ? .white : KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                // Always reserve space for checkmark
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .opacity(selectedLocation == location ? 1 : 0)
                    .frame(width: 20)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedLocation == location ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.parchment)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selectedLocation == location ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.border,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    
    // MARK: - Purchase Card
    
    private var purchaseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "tree.fill")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                .frame(maxWidth: .infinity)
            
            Text("Clear the Land")
                .font(.title2.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Build your home in \(player.currentKingdom ?? "this kingdom")")
                .font(.body)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Divider()
            
            HStack {
                Text("Price")
                    .font(.subheadline)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                Spacer()
                
                Text("\(landPrice) gold")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(canAfford ? KingdomTheme.Colors.gold : .red)
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
                            Text("Need \(landPrice - player.gold) more gold")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Button(action: {
                showingPurchaseConfirmation = true
            }) {
                HStack {
                    Image(systemName: "tree.fill")
                    Text("Purchase Land")
                }
            }
            .buttonStyle(.medieval(color: canPurchase ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkDark.opacity(0.3), fullWidth: true))
            .disabled(!canPurchase)
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private var canAfford: Bool {
        player.gold >= landPrice
    }
    
    private var hasReputation: Bool {
        player.reputation >= 50
    }
    
    private var canPurchase: Bool {
        canAfford && hasReputation
    }
    
    // MARK: - Helper Functions
    
    private func purchaseProperty() async {
        guard player.gold >= landPrice else { return }
        guard player.reputation >= 50 else { return }
        
        // TODO: Call API to purchase property with location
        // let property = try await propertyAPI.purchaseLand(kingdomId: kingdom.id, location: selectedLocation)
        
        // For now, just deduct gold locally
        await MainActor.run {
            player.gold -= landPrice
            dismiss()
        }
    }
}


