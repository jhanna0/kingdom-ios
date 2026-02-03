import SwiftUI
import MapKit

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
    
    /// Whether player rules THIS specific kingdom (from backend data)
    var isRuler: Bool {
        // Primary: use backend-provided ruledKingdomIds (source of truth)
        // Fallback: compare kingdom.rulerId with player.playerId (from backend Kingdom data)
        player.rulesKingdom(id: kingdom.id) || kingdom.rulerId == player.playerId
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
                    
                    Text("Funded by income tax and fees. Rulers exempt.")
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
                    player: player
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
                        
                        NavigationLink(destination: BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)) {
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
                        
                        NavigationLink(destination: TaxRateManagementView(kingdom: kingdom, viewModel: viewModel)) {
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
                        
                        NavigationLink(destination: DecreeInputView(kingdom: kingdom, decreeText: $decreeText)) {
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
        
        // Dynamically generate bonuses from all buildings with tier benefits
        for (_, metadata) in kingdom.buildingMetadata {
            guard metadata.level > 0 else { continue }
            
            bonuses.append(KingdomBonus(
                description: metadata.tierBenefit,
                source: "\(metadata.displayName) Level \(metadata.level)",
                icon: metadata.icon,
                color: Color(hex: metadata.colorHex) ?? KingdomTheme.Colors.inkMedium
            ))
        }
        
        return bonuses
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
}

// MARK: - Kingdom Bonus Helper

struct KingdomBonus: Hashable {
    let description: String
    let source: String
    let icon: String
    let color: Color
}
