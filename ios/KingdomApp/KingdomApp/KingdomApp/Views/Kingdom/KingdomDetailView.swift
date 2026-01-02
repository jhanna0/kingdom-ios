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
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
                    Text(kingdom.name)
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if isRuler {
                        Text("Your Kingdom")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 8)
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
                            .foregroundColor(KingdomTheme.Colors.gold)
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
                
                // Buildings section
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                        .padding(.horizontal)
                    
                    Text("Fortifications")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.large) {
                        BuildingStatCard(
                            icon: "building.2.fill",
                            name: "Walls",
                            level: kingdom.wallLevel,
                            maxLevel: 5,
                            benefit: "+\(kingdom.wallLevel * 2) defenders",
                            buildingType: "wall",
                            kingdom: kingdom,
                            player: player
                        )
                        
                        BuildingStatCard(
                            icon: "lock.shield.fill",
                            name: "Vault",
                            level: kingdom.vaultLevel,
                            maxLevel: 5,
                            benefit: "\(kingdom.vaultLevel * 20)% protected",
                            buildingType: "vault",
                            kingdom: kingdom,
                            player: player
                        )
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
