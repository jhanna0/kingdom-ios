import SwiftUI

/// Detailed view of a single property with upgrade options
struct PropertyDetailView: View {
    @ObservedObject var player: Player
    @State private var property: Property
    @State private var isUpgrading = false
    @State private var showUpgradeSuccess = false
    @Environment(\.dismiss) var dismiss
    
    private let propertyAPI = PropertyAPI()
    
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
            // Visual representation
            tierVisual
                .padding(.bottom, 8)
            
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
                        .fill(tier <= property.tier ? tierColor : KingdomTheme.Colors.inkDark.opacity(0.2))
                        .frame(width: 12, height: 12)
                }
            }
            
            Text("Tier \(property.tier) of 5")
                .font(.caption.bold())
                .foregroundColor(tierColor)
            
            // Current value
            Text("Estimated Value: \(property.currentValue) gold")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Tier Visual
    
    private var tierVisual: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [tierColor.opacity(0.2), tierColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
            
            // Tier-specific illustration
            switch property.tier {
            case 1:
                // T1: Empty lot
                VStack(spacing: 8) {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 70, weight: .light))
                        .foregroundColor(tierColor)
                    Text("Vacant Lot")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
                }
                
            case 2:
                // T2: Simple house
                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 70))
                        .foregroundColor(tierColor)
                    Text("Simple House")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
                }
                
            case 3:
                // T3: House with workshop
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 55))
                        .foregroundColor(tierColor)
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 45))
                        .foregroundColor(tierColor.opacity(0.8))
                        .offset(y: 15)
                }
                
            case 4:
                // T4: Beautiful property
                VStack(spacing: 8) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 70))
                        .foregroundColor(tierColor)
                    Text("Luxurious Estate")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
                }
                
            case 5:
                // T5: Estate with crown
                VStack(spacing: -8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 35))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 60))
                        .foregroundColor(tierColor)
                }
                
            default:
                Image(systemName: "questionmark")
                    .font(.system(size: 70))
                    .foregroundColor(tierColor)
            }
        }
    }
    
    private var tierColor: Color {
        switch property.tier {
        case 1: return KingdomTheme.Colors.buttonSecondary
        case 2: return KingdomTheme.Colors.buttonPrimary
        case 3: return KingdomTheme.Colors.goldWarm
        case 4: return KingdomTheme.Colors.gold
        case 5: return KingdomTheme.Colors.gold
        default: return KingdomTheme.Colors.inkDark
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
            locked.append(("Residence", 2))
        }
        if property.tier < 3 {
            locked.append(("Crafting", 3))
        }
        if property.tier < 4 {
            locked.append(("No taxes", 4))
        }
        if property.tier < 5 {
            locked.append(("Conquest protection", 5))
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
        case 2: return "Residence"
        case 3: return "Crafting"
        case 4: return "No taxes"
        case 5: return "Conquest protection"
        default: return ""
        }
    }
    
    // MARK: - Helper Functions
    
    private func upgradeProperty() {
        guard player.gold >= property.upgradeCost else { return }
        
        Task {
            isUpgrading = true
            
            do {
                let upgradedProperty = try await propertyAPI.upgradeProperty(propertyId: property.id)
                
                await MainActor.run {
                    // Update local state
                    property = upgradedProperty
                    player.gold -= property.upgradeCost
                    isUpgrading = false
                    showUpgradeSuccess = true
                    
                    // Hide success message after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showUpgradeSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    isUpgrading = false
                }
                print("❌ Failed to upgrade property: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


