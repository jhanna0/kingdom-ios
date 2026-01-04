import SwiftUI
import MapKit

enum KingdomDetailDestination: Hashable {
    case build
    case taxRate
    case decree
}

struct KingdomDetailView: View {
    let kingdomId: String
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var decreeText = ""
    @State private var weather: WeatherData?
    
    // Get the live kingdom from viewModel
    private var kingdom: Kingdom {
        viewModel.kingdoms.first(where: { $0.id == kingdomId }) ?? viewModel.kingdoms.first!
    }
    
    var isRuler: Bool {
        kingdom.rulerId == player.playerId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Kingdom header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "crown.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
                    Text(kingdom.name)
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if isRuler {
                        Text("Your Kingdom")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 8)
                    } else {
                        Text("Ruled by \(kingdom.rulerName)")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                .padding()
                
                // Treasury - Kingdom's money
                VStack(spacing: 8) {
                    Text("Kingdom Treasury")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns.fill")
                            .font(FontStyles.iconLarge)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("\(kingdom.treasuryGold)")
                            .font(FontStyles.displaySmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Text("gold")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Text("Used for contracts & defenses")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                
                // WEATHER CARD - PROOF OF CONCEPT!
                SimpleWeatherCard(weather: weather)
                    .padding(.horizontal)
                
                // Active Kingdom Bonuses
                activeKingdomBonusesCard
                
                // Military strength / intelligence
                MilitaryStrengthCard(
                    strength: viewModel.militaryStrengthCache[kingdomId],
                    kingdom: kingdom,
                    player: player,
                    onGatherIntel: {
                        Task {
                            await handleGatherIntelligence()
                        }
                    }
                )
                .padding(.horizontal)
                .task {
                    // Load military strength when view appears
                    print("🎯 KingdomDetailView .task running for kingdom: \(kingdomId)")
                    print("🎯 Cache has data: \(viewModel.militaryStrengthCache[kingdomId] != nil)")
                    if viewModel.militaryStrengthCache[kingdomId] == nil {
                        print("🎯 Cache is nil, fetching...")
                        await viewModel.fetchMilitaryStrength(kingdomId: kingdomId)
                    } else {
                        print("🎯 Cache hit, not fetching")
                    }
                }
                
                // Kingdom Management (Ruler only) - Moved to top
                if isRuler {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                        .padding(.horizontal)
                    
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        Text("Kingdom Management")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        NavigationLink(value: KingdomDetailDestination.build) {
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "hammer.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalPurple, cornerRadius: 12, shadowOffset: 3, borderWidth: 2.5)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Manage Buildings")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Text("Upgrade economy & defenses")
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .padding(KingdomTheme.Spacing.medium)
                        }
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                        
                        NavigationLink(value: KingdomDetailDestination.taxRate) {
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "percent")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 12, shadowOffset: 3, borderWidth: 2.5)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Set Tax Rate")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Text("Current: \(kingdom.taxRate)%")
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .padding(KingdomTheme.Spacing.medium)
                        }
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                        
                        NavigationLink(value: KingdomDetailDestination.decree) {
                            HStack(spacing: KingdomTheme.Spacing.medium) {
                                Image(systemName: "scroll.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalCrimson, cornerRadius: 12, shadowOffset: 3, borderWidth: 2.5)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Make Decree")
                                        .font(FontStyles.bodyLargeBold)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Text("Announce to all subjects")
                                        .font(FontStyles.labelMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .padding(KingdomTheme.Spacing.medium)
                        }
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationDestination(for: KingdomDetailDestination.self) { destination in
            switch destination {
            case .build:
                BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)
            case .taxRate:
                TaxRateManagementView(kingdom: kingdom, viewModel: viewModel)
            case .decree:
                DecreeInputView(kingdom: kingdom, decreeText: $decreeText)
            }
        }
        .task {
            // Refresh kingdom data with upgrade costs when sheet opens
            await viewModel.refreshKingdom(id: kingdomId)
            
            // Load weather data
            await loadWeather()
        }
    }
    
    // MARK: - Active Kingdom Bonuses Card
    
    private var activeKingdomBonusesCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "sparkles")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Active Kingdom Bonuses")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Show bonuses from buildings
            let bonuses = getKingdomBonuses()
            
            if bonuses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 32))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("No Active Bonuses")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Upgrade kingdom buildings to provide bonuses to all citizens")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 10) {
                    ForEach(bonuses, id: \.self) { bonus in
                        kingdomBonusBadge(bonus)
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private func kingdomBonusBadge(_ bonus: KingdomBonus) -> some View {
        HStack(spacing: 12) {
            // Icon with color based on building type
            Image(systemName: bonus.icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(
                    backgroundColor: bonus.color,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                // Main text
                Text(bonus.description)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Source
                Text(bonus.source)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    private func getKingdomBonuses() -> [KingdomBonus] {
        var bonuses: [KingdomBonus] = []
        
        // Farm bonuses
        if kingdom.farmLevel > 0 {
            let reduction = getFarmReduction(kingdom.farmLevel)
            bonuses.append(KingdomBonus(
                description: "Citizens complete contracts \(reduction)% faster",
                source: "Farm Level \(kingdom.farmLevel)",
                icon: "leaf.fill",
                color: KingdomTheme.Colors.buttonSuccess
            ))
        }
        
        // Education bonuses
        if kingdom.educationLevel > 0 {
            let reduction = kingdom.educationLevel * 5
            bonuses.append(KingdomBonus(
                description: "-\(reduction)% training actions required",
                source: "Education Hall Level \(kingdom.educationLevel)",
                icon: "graduationcap.fill",
                color: KingdomTheme.Colors.royalBlue
            ))
        }
        
        // Wall bonuses
        if kingdom.wallLevel > 0 {
            let defenders = kingdom.wallLevel * 2
            bonuses.append(KingdomBonus(
                description: "+\(defenders) defenders during coups",
                source: "Walls Level \(kingdom.wallLevel)",
                icon: "building.2.fill",
                color: KingdomTheme.Colors.buttonDanger
            ))
        }
        
        // Vault bonuses
        if kingdom.vaultLevel > 0 {
            let protection = kingdom.vaultLevel * 20
            bonuses.append(KingdomBonus(
                description: "\(protection)% of treasury protected from looting",
                source: "Vault Level \(kingdom.vaultLevel)",
                icon: "lock.shield.fill",
                color: KingdomTheme.Colors.imperialGold
            ))
        }
        
        // Mine bonuses
        if kingdom.mineLevel > 0 {
            bonuses.append(KingdomBonus(
                description: "Unlocked materials: \(getMineMaterials(kingdom.mineLevel))",
                source: "Mine Level \(kingdom.mineLevel)",
                icon: "hammer.fill",
                color: KingdomTheme.Colors.buttonWarning
            ))
        }
        
        // Market bonuses
        if kingdom.marketLevel > 0 {
            let income = getMarketIncome(kingdom.marketLevel)
            bonuses.append(KingdomBonus(
                description: "+\(income)g/day from trade activity",
                source: "Market Level \(kingdom.marketLevel)",
                icon: "cart.fill",
                color: KingdomTheme.Colors.royalPurple
            ))
        }
        
        return bonuses
    }
    
    private func getFarmReduction(_ level: Int) -> Int {
        switch level {
        case 1: return 5
        case 2: return 10
        case 3: return 20
        case 4: return 25
        case 5: return 33
        default: return 0
        }
    }
    
    private func getMineMaterials(_ level: Int) -> String {
        switch level {
        case 1: return "Stone"
        case 2: return "Stone, Iron"
        case 3: return "Stone, Iron, Steel"
        case 4: return "Stone, Iron, Steel, Titanium"
        case 5: return "All materials (2x quantity)"
        default: return ""
        }
    }
    
    private func getMarketIncome(_ level: Int) -> Int {
        switch level {
        case 1: return 15
        case 2: return 35
        case 3: return 65
        case 4: return 100
        case 5: return 150
        default: return 0
        }
    }
    
    // MARK: - Weather Loading
    
    @MainActor
    private func loadWeather() async {
        do {
            let response = try await KingdomAPIService.shared.weather.getKingdomWeather(kingdomId: kingdomId)
            weather = response.weather
        } catch {
            print("⚠️ Weather error: \(error)")
        }
    }
    
    // MARK: - Intelligence Actions
    
    @MainActor
    private func handleGatherIntelligence() async {
        do {
            let response = try await viewModel.gatherIntelligence(kingdomId: kingdomId)
            
            // Show result
            if response.success {
                // Success - show what we learned
                print("✅ Successfully gathered intelligence!")
            } else {
                // Caught - show failure
                print("❌ Caught gathering intelligence!")
            }
        } catch {
            print("❌ Failed to gather intelligence: \(error)")
        }
    }
}

// MARK: - Kingdom Bonus Helper

struct KingdomBonus: Hashable {
    let description: String
    let source: String
    let icon: String
    let color: Color
}
