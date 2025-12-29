import SwiftUI

/// Detailed view of a single property with upgrade options
struct PropertyDetailView: View {
    @ObservedObject var player: Player
    @State private var property: Property
    @Environment(\.dismiss) var dismiss
    
    init(player: Player, property: Property) {
        self.player = player
        self._property = State(initialValue: property)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with property tier and name
                headerCard
                
                // Location info
                locationCard
                
                // Current benefits
                benefitsCard
                
                // Upgrade section
                if property.tier < 5 {
                    upgradeCard
                } else {
                    maxLevelCard
                }
                
                // Future tier benefits preview
                if property.tier < 5 {
                    futureBenefitsCard
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle(property.tierName)
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            // Property icon based on tier
            Image(systemName: tierIcon)
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.gold)
            
            Text(property.tierName)
                .font(.title.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(property.tierDescription)
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                .multilineTextAlignment(.center)
            
            // Tier progress
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { tier in
                    Circle()
                        .fill(tier <= property.tier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.2))
                        .frame(width: 12, height: 12)
                }
            }
            
            Text("Tier \(property.tier) of 5")
                .font(.caption.bold())
                .foregroundColor(KingdomTheme.Colors.gold)
            
            // Current value
            Text("Estimated Value: \(property.currentValue) gold")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var tierIcon: String {
        switch property.tier {
        case 1: return "map"
        case 2: return "house"
        case 3: return "hammer"
        case 4: return "building.columns"
        case 5: return "crown"
        default: return "map"
        }
    }
    
    // MARK: - Location Card
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(property.kingdomName)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Kingdom")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Implement fast travel
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane")
                        Text("Travel")
                    }
                }
                .buttonStyle(.medievalSubtle(color: KingdomTheme.Colors.buttonPrimary))
            }
            
            Text("Purchased \(formatDate(property.purchasedAt))")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Benefits Card
    
    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Benefits")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if property.currentBenefits.isEmpty {
                Text("No benefits at this tier")
                    .font(.subheadline)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(property.currentBenefits, id: \.self) { benefit in
                        benefitRow(benefit: benefit, active: true)
                    }
                }
            }
            
            // Show locked benefits
            let lockedBenefits = getLockedBenefits()
            if !lockedBenefits.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                Text("Locked Benefits")
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(lockedBenefits, id: \.benefit) { item in
                        benefitRow(benefit: item.benefit, active: false, unlockTier: item.tier)
                    }
                }
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func benefitRow(benefit: String, active: Bool, unlockTier: Int? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: active ? "checkmark.circle.fill" : "lock.fill")
                .font(.body)
                .foregroundColor(active ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                .frame(width: 20)
            
            Text(benefit)
                .font(.subheadline)
                .foregroundColor(active ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkDark.opacity(0.5))
            
            Spacer()
            
            if let tier = unlockTier {
                Text("T\(tier)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(KingdomTheme.Colors.inkDark.opacity(0.4))
                    .cornerRadius(4)
            }
        }
    }
    
    private func getLockedBenefits() -> [(benefit: String, tier: Int)] {
        var locked: [(String, Int)] = []
        
        if property.tier < 2 {
            locked.append(("Personal residence", 2))
        }
        if property.tier < 3 {
            locked.append(("Can craft weapons and armor", 3))
            locked.append(("15% faster crafting", 3))
        }
        if property.tier < 4 {
            locked.append(("Tax exemption in \(property.kingdomName)", 4))
        }
        if property.tier < 5 {
            locked.append(("50% chance to survive conquest", 5))
        }
        
        return locked
    }
    
    
    // MARK: - Upgrade Card
    
    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to \(nextTierName)")
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(nextTierDescription)
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                Text("\(property.upgradeCost) gold")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(player.gold >= property.upgradeCost ? KingdomTheme.Colors.gold : .red)
            }
            
            Button(action: upgradeProperty) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Upgrade to Tier \(property.tier + 1)")
                }
            }
            .buttonStyle(.medieval(
                color: player.gold >= property.upgradeCost ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkDark.opacity(0.3),
                fullWidth: true
            ))
            .disabled(player.gold < property.upgradeCost)
            
            if player.gold < property.upgradeCost {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text("Need \(property.upgradeCost - player.gold) more gold")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var nextTierName: String {
        switch property.tier + 1 {
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"
        default: return "Next Tier"
        }
    }
    
    private var nextTierDescription: String {
        switch property.tier + 1 {
        case 2: return "Build a personal residence"
        case 3: return "Add workshop for crafting"
        case 4: return "Luxurious estate with tax exemption"
        case 5: return "Fortified estate with maximum protection"
        default: return ""
        }
    }
    
    // MARK: - Max Level Card
    
    private var maxLevelCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.gold)
            
            Text("Maximum Level")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("This property is fully upgraded with all benefits unlocked!")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .parchmentCard(
            backgroundColor: KingdomTheme.Colors.gold.opacity(0.1),
            borderColor: KingdomTheme.Colors.gold,
            hasShadow: false
        )
    }
    
    // MARK: - Future Benefits Card
    
    private var futureBenefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upgrade Path")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("What you'll unlock at higher tiers:")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach((property.tier + 1)...5, id: \.self) { tier in
                    futureTierRow(tier: tier)
                }
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func futureTierRow(tier: Int) -> some View {
        HStack(spacing: 12) {
            Text("T\(tier)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(KingdomTheme.Colors.gold)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tierNameFor(tier))
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(tierBenefitsFor(tier))
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            }
            
            Spacer()
        }
    }
    
    private func tierNameFor(_ tier: Int) -> String {
        switch tier {
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"
        default: return "Tier \(tier)"
        }
    }
    
    private func tierBenefitsFor(_ tier: Int) -> String {
        switch tier {
        case 2: return "Personal residence"
        case 3: return "Craft weapons & armor, 15% faster crafting"
        case 4: return "Tax exemption in \(property.kingdomName)"
        case 5: return "50% survive conquest"
        default: return ""
        }
    }
    
    // MARK: - Helper Functions
    
    private func upgradeProperty() {
        guard player.gold >= property.upgradeCost else { return }
        
        player.gold -= property.upgradeCost
        _ = property.upgrade()
        
        // TODO: Show success feedback and animation
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct PropertyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PropertyDetailView(
                player: {
                    let p = Player(name: "Test Player")
                    p.gold = 1000
                    return p
                }(),
                property: Property.samples[0]
            )
        }
    }
}

