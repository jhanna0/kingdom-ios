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
                // Header with property icon and name
                headerCard
                
                // Location info
                locationCard
                
                // Current benefits
                benefitsCard
                
                // Pending income (if applicable)
                if property.type == .shop || property.type == .personalMine {
                    incomeCard
                }
                
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
        .navigationTitle(property.type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            Text(property.icon)
                .font(.system(size: 80))
            
            Text(property.type.rawValue)
                .font(.title2.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Tier stars
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { tier in
                    Image(systemName: tier <= property.tier ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(tier <= property.tier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                }
            }
            
            Text("Tier \(property.tier) of 5")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.gold)
            
            // Current value
            Text("Value: \(property.currentValue)💰")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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
            Text("Current Benefits")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            switch property.type {
            case .house:
                houseBenefitsList
            case .shop:
                shopBenefitsList
            case .personalMine:
                mineBenefitsList
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var houseBenefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(
                icon: "arrow.down.circle.fill",
                title: "Travel Cost Reduction",
                value: "\(Int(property.travelCostReduction * 100))% off"
            )
            
            benefitRow(
                icon: "airplane",
                title: "Instant Travel",
                value: "To \(property.kingdomName)"
            )
            
            if property.tier >= 3 {
                benefitRow(
                    icon: "bolt.fill",
                    title: "Garden Bonus",
                    value: "10% faster actions"
                )
            } else {
                benefitRow(
                    icon: "lock.fill",
                    title: "Garden Bonus",
                    value: "Unlock at Tier 3",
                    locked: true
                )
            }
            
            if property.tier >= 4 {
                benefitRow(
                    icon: "percent",
                    title: "Beautiful Estate",
                    value: "50% tax reduction"
                )
            } else {
                benefitRow(
                    icon: "lock.fill",
                    title: "Beautiful Estate",
                    value: "Unlock at Tier 4",
                    locked: true
                )
            }
            
            if property.tier >= 5 {
                benefitRow(
                    icon: "shield.fill",
                    title: "Fortified Home",
                    value: "50% survive conquest"
                )
            } else {
                benefitRow(
                    icon: "lock.fill",
                    title: "Fortified Home",
                    value: "Unlock at Tier 5",
                    locked: true
                )
            }
        }
    }
    
    private var shopBenefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(
                icon: "dollarsign.circle.fill",
                title: "Daily Income",
                value: "\(property.dailyGoldIncome)💰 per day"
            )
            
            benefitRow(
                icon: "building.2.fill",
                title: "Passive Earnings",
                value: "Collect anytime"
            )
            
            benefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Investment",
                value: "Growing asset"
            )
        }
    }
    
    private var mineBenefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(
                icon: "hammer.fill",
                title: "Iron Production",
                value: "\(property.dailyIronYield) iron/day"
            )
            
            if property.tier >= 2 {
                benefitRow(
                    icon: "shield.lefthalf.filled",
                    title: "Steel Production",
                    value: "\(property.dailySteelYield) steel/day"
                )
            } else {
                benefitRow(
                    icon: "lock.fill",
                    title: "Steel Production",
                    value: "Unlock at Tier 2",
                    locked: true
                )
            }
            
            benefitRow(
                icon: "checkmark.shield.fill",
                title: "Tax Free",
                value: "No ruler taxes"
            )
            
            benefitRow(
                icon: "calendar",
                title: "Passive Mining",
                value: "Automatic collection"
            )
        }
    }
    
    private func benefitRow(icon: String, title: String, value: String, locked: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(locked ? KingdomTheme.Colors.inkDark.opacity(0.3) : KingdomTheme.Colors.gold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(locked ? KingdomTheme.Colors.inkDark.opacity(0.5) : KingdomTheme.Colors.inkDark)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(locked ? KingdomTheme.Colors.inkDark.opacity(0.4) : KingdomTheme.Colors.inkDark.opacity(0.7))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Income Card
    
    private var incomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Income")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if property.type == .shop {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(property.pendingGoldIncome)💰")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        Text("Ready to collect")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: collectIncome) {
                        Text("Collect")
                    }
                    .buttonStyle(.medievalSubtle(color: KingdomTheme.Colors.buttonPrimary))
                    .disabled(property.pendingGoldIncome == 0)
                }
            } else if property.type == .personalMine {
                VStack(spacing: 8) {
                    HStack {
                        Text("⚒️ \(property.pendingIronIncome) Iron")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                    }
                    
                    if property.tier >= 2 {
                        HStack {
                            Text("🛡️ \(property.pendingSteelIncome) Steel")
                                .font(.subheadline.bold())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                        }
                    }
                    
                    Button(action: collectIncome) {
                        Text("Collect Resources")
                    }
                    .buttonStyle(.medievalSubtle(color: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
                    .disabled(property.pendingIronIncome == 0)
                }
            }
        }
        .padding()
        .parchmentCard(
            backgroundColor: KingdomTheme.Colors.gold.opacity(0.1),
            borderColor: KingdomTheme.Colors.gold,
            hasShadow: false
        )
    }
    
    // MARK: - Upgrade Card
    
    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upgrade to Tier \(property.tier + 1)")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("\(property.upgradeCost)💰")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(player.gold >= property.upgradeCost ? KingdomTheme.Colors.gold : .red)
            }
            
            Text("Unlock new benefits and increase property value")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Button(action: upgradeProperty) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Upgrade Property")
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
            Text("Future Upgrades")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Benefits you'll unlock at higher tiers:")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 8) {
                switch property.type {
                case .house:
                    if property.tier < 3 {
                        futureBenefitRow(tier: 3, description: "🌱 Plant garden: 10% faster actions")
                    }
                    if property.tier < 4 {
                        futureBenefitRow(tier: 4, description: "🏛️ Beautiful estate: 50% tax reduction")
                    }
                    if property.tier < 5 {
                        futureBenefitRow(tier: 5, description: "🛡️ Fortified: 50% survive conquest")
                    }
                case .shop:
                    ForEach((property.tier + 1)...5, id: \.self) { tier in
                        let income = shopIncomeAtTier(tier)
                        futureBenefitRow(tier: tier, description: "💰 \(income) gold per day")
                    }
                case .personalMine:
                    ForEach((property.tier + 1)...5, id: \.self) { tier in
                        let (iron, steel) = mineYieldAtTier(tier)
                        futureBenefitRow(tier: tier, description: "⚒️ \(iron) iron, 🛡️ \(steel) steel per day")
                    }
                }
            }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func futureBenefitRow(tier: Int, description: String) -> some View {
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
    
    // MARK: - Helper Functions
    
    private func collectIncome() {
        let income = property.collectIncome()
        
        // Update player resources
        player.gold += income.gold
        // TODO: Add iron and steel to player inventory system when implemented
        // player.iron += income.iron
        // player.steel += income.steel
        
        // TODO: Show success feedback with collected amounts
        print("Collected: \(income.gold) gold, \(income.iron) iron, \(income.steel) steel")
    }
    
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
    
    private func shopIncomeAtTier(_ tier: Int) -> Int {
        switch tier {
        case 1: return 10
        case 2: return 25
        case 3: return 50
        case 4: return 100
        case 5: return 200
        default: return 0
        }
    }
    
    private func mineYieldAtTier(_ tier: Int) -> (iron: Int, steel: Int) {
        let iron = [5, 10, 15, 20, 25][tier - 1]
        let steel = [0, 2, 5, 10, 15][tier - 1]
        return (iron, steel)
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

