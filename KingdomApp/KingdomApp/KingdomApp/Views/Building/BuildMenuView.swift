import SwiftUI

// Build Menu View
struct BuildMenuView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedBuildingType: BuildingType?
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Economic Buildings Section
                        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                            Text("💰 Economic Buildings")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.gold)
                            
                            Text("Generate passive income for the city treasury")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.horizontal)
                        
                        // Mine upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "hammer.fill",
                            name: "Gold Mine",
                            currentLevel: kingdom.mineLevel,
                            maxLevel: 5,
                            benefit: mineIncomeBenefit(kingdom.mineLevel + 1),
                            hasActiveContract: kingdom.activeContract?.buildingType == "Mine",
                            onCreateContract: {
                                selectedBuildingType = .mine
                            }
                        )
                        
                        // Market upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "cart.fill",
                            name: "Market",
                            currentLevel: kingdom.marketLevel,
                            maxLevel: 5,
                            benefit: marketIncomeBenefit(kingdom.marketLevel + 1),
                            hasActiveContract: kingdom.activeContract?.buildingType == "Market",
                            onCreateContract: {
                                selectedBuildingType = .market
                            }
                        )
                        
                        // Defensive Buildings Section
                        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                            Text("🛡️ Defensive Buildings")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Protect your kingdom from coups")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Walls upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "building.2.fill",
                            name: "Walls",
                            currentLevel: kingdom.wallLevel,
                            maxLevel: 5,
                            benefit: "Adds \((kingdom.wallLevel + 1) * 2) defenders during coups",
                            hasActiveContract: kingdom.activeContract?.buildingType == "Walls",
                            onCreateContract: {
                                selectedBuildingType = .walls
                            }
                        )
                        
                        // Vault upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "lock.shield.fill",
                            name: "Vault",
                            currentLevel: kingdom.vaultLevel,
                            maxLevel: 5,
                            benefit: "Protects \((kingdom.vaultLevel + 1) * 20)% of treasury from looting",
                            hasActiveContract: kingdom.activeContract?.buildingType == "Vault",
                            onCreateContract: {
                                selectedBuildingType = .vault
                            }
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Manage Buildings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationDestination(item: $selectedBuildingType) { buildingType in
                ContractCreationView(
                    kingdom: kingdom,
                    buildingType: buildingType,
                    viewModel: viewModel
                )
            }
    }
    
    // Income benefit descriptions
    private func mineIncomeBenefit(_ level: Int) -> String {
        let income: Int = {
            switch level {
            case 1: return 10
            case 2: return 25
            case 3: return 50
            case 4: return 80
            case 5: return 120
            default: return 0
            }
        }()
        return "+\(income)g/day passive income"
    }
    
    private func marketIncomeBenefit(_ level: Int) -> String {
        let income: Int = {
            switch level {
            case 1: return 15
            case 2: return 35
            case 3: return 65
            case 4: return 100
            case 5: return 150
            default: return 0
            }
        }()
        return "+\(income)g/day from trade activity"
    }
}

enum BuildingType {
    case walls
    case vault
    case mine
    case market
}
