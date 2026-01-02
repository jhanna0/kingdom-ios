import SwiftUI

/// Market view for purchasing land in the current kingdom - Brutalist style
struct PropertyMarketView: View {
    @ObservedObject var player: Player
    var kingdom: Kingdom?
    var onPurchaseComplete: (() -> Void)?
    @State private var selectedLocation: String = "north"
    @State private var showingPurchaseConfirmation = false
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
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
            Text("Clear the forest on the \(selectedLocation) side and claim this land? (Price determined by kingdom population)")
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
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkDark, cornerRadius: 16, shadowOffset: 4, borderWidth: 3)
                }
            }
        }
    }
    
    // MARK: - Resources Card
    
    private var resourcesCard: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Gold
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Text("\(player.gold)")
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                Text("GOLD")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
            
            // Reputation
            VStack(spacing: 6) {
                Text("\(player.reputation)")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(player.reputation >= 50 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                Text("REPUTATION")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    // MARK: - Location Selection Card
    
    private var locationSelectionCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "mappin.and.ellipse")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose Location")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Where would you like to build?")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Location grid - compass style
            VStack(spacing: 10) {
                // North
                locationButton(location: "north", icon: "arrow.up.circle.fill", label: "North")
                
                HStack(spacing: 10) {
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
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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
                    .font(FontStyles.iconMedium)
                    .foregroundColor(selectedLocation == location ? .white : KingdomTheme.Colors.inkDark)
                    .frame(width: 28)
                
                Text(label)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(selectedLocation == location ? .white : KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if selectedLocation == location {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .brutalistBadge(
            backgroundColor: selectedLocation == location ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.parchment,
            cornerRadius: 10,
            shadowOffset: selectedLocation == location ? 3 : 1,
            borderWidth: 2
        )
        .buttonStyle(.plain)
    }
    
    
    // MARK: - Purchase Card
    
    private var purchaseCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header with icon
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "tree.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 12, shadowOffset: 3, borderWidth: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear the Land")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let kingdom = kingdom {
                        Text("Build your home in \(kingdom.name)")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Price info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Price")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text("~500g")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                
                Spacer()
                
                Text("Varies by population")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding()
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
            
            // Requirements warnings
            VStack(alignment: .leading, spacing: 8) {
                if kingdom == nil {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                        
                        Text("Must be inside a kingdom to purchase land")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                }
                
                if !hasReputation {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                        
                        Text("Need 50+ reputation (you have \(player.reputation))")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                }
            }
            
            if let error = purchaseError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(FontStyles.iconSmall)
                    Text(error)
                        .font(FontStyles.labelMedium)
                }
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
            
            // Purchase button
            Button(action: {
                showingPurchaseConfirmation = true
            }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "tree.fill")
                            .font(FontStyles.iconSmall)
                        Text("Purchase Land")
                            .font(FontStyles.bodyMediumBold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .brutalistBadge(
                backgroundColor: (kingdom != nil && hasReputation) ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
                cornerRadius: 12,
                shadowOffset: (kingdom != nil && hasReputation) ? 3 : 0,
                borderWidth: 2
            )
            .disabled(kingdom == nil || !hasReputation || isPurchasing)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private var hasReputation: Bool {
        player.reputation >= 50
    }
    
    // MARK: - Helper Functions
    
    private func purchaseProperty() async {
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
                Task {
                    await player.loadFromAPI()
                }
                isPurchasing = false
                dismiss()
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
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
}

#Preview {
    PropertyMarketView(player: Player(), kingdom: nil)
}
