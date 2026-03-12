import SwiftUI
import MapKit

struct KingdomDetailView: View {
    let kingdomId: String
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var kingdom: Kingdom?
    @State private var isLoading = true
    @State private var decreeText = ""
    @State private var weather: WeatherData?
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let kingdom = kingdom {
                kingdomContent(kingdom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadKingdom()
            await loadWeather()
            await loadMilitaryStrength()
        }
    }
    
    // MARK: - Content
    
    private func kingdomContent(_ kingdom: Kingdom) -> some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "crown.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
                    Text(kingdom.name)
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Your Kingdom")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 8)
                }
                .padding()
                
                // Treasury
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
                    
                    Text("Funded by income tax and fees.")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                
                // Weather
                SimpleWeatherCard(weather: weather)
                    .padding(.horizontal)
                
                // Active Kingdom Bonuses
                activeKingdomBonusesCard(kingdom)
                
                // Military Strength
                MilitaryStrengthCard(
                    strength: viewModel.militaryStrengthCache[kingdomId],
                    kingdom: kingdom,
                    player: player
                )
                .padding(.horizontal)
                
                // Management Section
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                    .padding(.horizontal)
                
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Text("Kingdom Management")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    NavigationLink(destination: BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)) {
                        managementRow(icon: "hammer.fill", color: KingdomTheme.Colors.royalPurple, title: "Manage Buildings", subtitle: "Upgrade economy & defenses")
                    }
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    
                    NavigationLink(destination: TaxRateManagementView(kingdom: kingdom, viewModel: viewModel)) {
                        managementRow(icon: "percent", color: KingdomTheme.Colors.imperialGold, title: "Set Tax Rate", subtitle: "Current: \(kingdom.taxRate)%")
                    }
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    
                    NavigationLink(destination: DecreeInputView(kingdom: kingdom, decreeText: $decreeText)) {
                        managementRow(icon: "scroll.fill", color: KingdomTheme.Colors.royalCrimson, title: "Make Decree", subtitle: "Announce to all subjects")
                    }
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
    
    private func managementRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .brutalistBadge(backgroundColor: color, cornerRadius: 12, shadowOffset: 3, borderWidth: 2.5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FontStyles.bodyLargeBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text(subtitle)
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
    
    // MARK: - Kingdom Bonuses
    
    private func activeKingdomBonusesCard(_ kingdom: Kingdom) -> some View {
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
            
            let bonuses = getKingdomBonuses(kingdom)
            
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
            Image(systemName: bonus.icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(backgroundColor: bonus.color, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bonus.description)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(bonus.source)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    private func getKingdomBonuses(_ kingdom: Kingdom) -> [KingdomBonus] {
        kingdom.buildingMetadata.values
            .filter { $0.level > 0 }
            .map { metadata in
                KingdomBonus(
                    description: metadata.tierBenefit,
                    source: "\(metadata.displayName) Level \(metadata.level)",
                    icon: metadata.icon,
                    color: Color(hex: metadata.colorHex) ?? KingdomTheme.Colors.inkMedium
                )
            }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadKingdom() async {
        isLoading = true
        do {
            let managed = try await APIClient.shared.getManagedKingdom(kingdomId: kingdomId)
            kingdom = managed.toKingdom()
        } catch {
            print("⚠️ Failed to load kingdom: \(error)")
        }
        isLoading = false
    }
    
    @MainActor
    private func loadWeather() async {
        do {
            let response = try await KingdomAPIService.shared.weather.getKingdomWeather(kingdomId: kingdomId)
            weather = response.weather
        } catch {
            print("⚠️ Weather error: \(error)")
        }
    }
    
    @MainActor
    private func loadMilitaryStrength() async {
        if viewModel.militaryStrengthCache[kingdomId] == nil {
            await viewModel.fetchMilitaryStrength(kingdomId: kingdomId)
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
