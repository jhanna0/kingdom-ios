import SwiftUI

/// Market view for purchasing land in the current kingdom
struct PropertyMarketView: View {
    @ObservedObject var player: Player
    var kingdom: Kingdom?
    var onPurchaseComplete: (() -> Void)?
    @State private var selectedLocation: String = "north"
    @State private var showingPurchaseConfirmation = false
    @State private var landPrice: Int = 500
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
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
        .onAppear {
            // Calculate land price based on kingdom population
            if let kingdom = kingdom {
                landPrice = Property.purchasePrice(kingdomPopulation: kingdom.checkedInPlayers)
            }
        }
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
        .alert("Error", isPresented: .constant(purchaseError != nil)) {
            Button("OK") {
                purchaseError = nil
            }
        } message: {
            if let error = purchaseError {
                Text(error)
            }
        }
        .overlay {
            if isPurchasing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        
                        Text("Purchasing land...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(KingdomTheme.Colors.inkDark)
                    .cornerRadius(16)
                }
            }
        }
        .onAppear {
            calculateLandPrice()
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
            
            Text("Build your home in \(kingdom?.name ?? "this kingdom")")
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
                    if kingdom == nil {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text("Must be inside a kingdom to purchase land")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                    
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
            
            if let error = purchaseError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
            
            Button(action: {
                showingPurchaseConfirmation = true
            }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "tree.fill")
                        Text("Purchase Land")
                    }
                }
            }
            .buttonStyle(.medieval(color: canPurchase ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkDark.opacity(0.3), fullWidth: true))
            .disabled(!canPurchase || isPurchasing)
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
        kingdom != nil && canAfford && hasReputation
    }
    
    // MARK: - Helper Functions
    
    private func purchaseProperty() async {
        guard player.gold >= landPrice else { return }
        guard player.reputation >= 50 else { return }
        guard let kingdom = kingdom else {
            await MainActor.run {
                purchaseError = "No kingdom selected"
            }
            return
        }
        
        await MainActor.run {
            isPurchasing = true
            purchaseError = nil
        }
        
        do {
            let property = try await propertyAPI.purchaseLand(
                kingdomId: kingdom.id,
                kingdomName: kingdom.name,
                location: selectedLocation
            )
            
            print("✅ Successfully purchased property: \(property.tierName) in \(kingdom.name)")
            
            await MainActor.run {
                // Update player gold from backend response
                player.gold -= landPrice
                isPurchasing = false
                
                // Dismiss to go back to MyPropertiesView
                dismiss()
            }
            
            // Small delay to let dismiss complete, then trigger reload
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                // Trigger reload in parent view
                onPurchaseComplete?()
            }
        } catch {
            await MainActor.run {
                isPurchasing = false
                purchaseError = error.localizedDescription
            }
            print("❌ Failed to purchase property: \(error)")
        }
    }
    
    private func calculateLandPrice() {
        if let kingdom = kingdom {
            let populationMultiplier = 1.0 + (Double(kingdom.checkedInPlayers) / 50.0)
            landPrice = Int(500.0 * populationMultiplier)
        }
    }
}

#Preview {
    PropertyMarketView(player: Player(), kingdom: nil)
}
