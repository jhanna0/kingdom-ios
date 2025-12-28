import SwiftUI

// Build Menu View
struct BuildMenuView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showContractSheet = false
    @State private var selectedBuildingType: BuildingType?
    
    var body: some View {
        NavigationView {
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
                            directCost: calculateMineCost(kingdom.mineLevel + 1),
                            benefit: mineIncomeBenefit(kingdom.mineLevel + 1),
                            kingdomTreasury: kingdom.treasuryGold,
                            hasActiveContract: kingdom.activeContract?.buildingType == "Mine",
                            onDirectUpgrade: {
                                upgradeMine()
                            },
                            onCreateContract: {
                                selectedBuildingType = .mine
                                showContractSheet = true
                            }
                        )
                        
                        // Market upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "cart.fill",
                            name: "Market",
                            currentLevel: kingdom.marketLevel,
                            maxLevel: 5,
                            directCost: calculateMarketCost(kingdom.marketLevel + 1),
                            benefit: marketIncomeBenefit(kingdom.marketLevel + 1),
                            kingdomTreasury: kingdom.treasuryGold,
                            hasActiveContract: kingdom.activeContract?.buildingType == "Market",
                            onDirectUpgrade: {
                                upgradeMarket()
                            },
                            onCreateContract: {
                                selectedBuildingType = .market
                                showContractSheet = true
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
                            directCost: calculateWallsCost(kingdom.wallLevel + 1),
                            benefit: "Adds \((kingdom.wallLevel + 1) * 2) defenders during coups",
                            kingdomTreasury: kingdom.treasuryGold,
                            hasActiveContract: kingdom.activeContract?.buildingType == "Walls",
                            onDirectUpgrade: {
                                upgradeWalls()
                            },
                            onCreateContract: {
                                selectedBuildingType = .walls
                                showContractSheet = true
                            }
                        )
                        
                        // Vault upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "lock.shield.fill",
                            name: "Vault",
                            currentLevel: kingdom.vaultLevel,
                            maxLevel: 5,
                            directCost: calculateVaultCost(kingdom.vaultLevel + 1),
                            benefit: "Protects \((kingdom.vaultLevel + 1) * 20)% of treasury from looting",
                            kingdomTreasury: kingdom.treasuryGold,
                            hasActiveContract: kingdom.activeContract?.buildingType == "Vault",
                            onDirectUpgrade: {
                                upgradeVault()
                            },
                            onCreateContract: {
                                selectedBuildingType = .vault
                                showContractSheet = true
                            }
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Build Fortifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .sheet(isPresented: $showContractSheet) {
                if let buildingType = selectedBuildingType {
                    ContractCreationSheet(
                        kingdom: kingdom,
                        buildingType: buildingType,
                        viewModel: viewModel,
                        onDismiss: {
                            showContractSheet = false
                            dismiss()  // Also dismiss the build menu
                        }
                    )
                }
            }
        }
    }
    
    // Cost calculations
    private func calculateMineCost(_ level: Int) -> Int {
        return Int(Double(150) * pow(1.6, Double(level - 1)))
    }
    
    private func calculateMarketCost(_ level: Int) -> Int {
        return Int(Double(200) * pow(1.6, Double(level - 1)))
    }
    
    private func calculateWallsCost(_ level: Int) -> Int {
        return Int(Double(200) * pow(1.5, Double(level - 1)))
    }
    
    private func calculateVaultCost(_ level: Int) -> Int {
        return Int(Double(250) * pow(1.5, Double(level - 1)))
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
    
    // Upgrade actions
    private func upgradeMine() {
        let cost = calculateMineCost(kingdom.mineLevel + 1)
        viewModel.upgradeBuilding(kingdom: kingdom, buildingType: .mine, cost: cost)
        dismiss()
    }
    
    private func upgradeMarket() {
        let cost = calculateMarketCost(kingdom.marketLevel + 1)
        viewModel.upgradeBuilding(kingdom: kingdom, buildingType: .market, cost: cost)
        dismiss()
    }
    
    private func upgradeWalls() {
        let cost = calculateWallsCost(kingdom.wallLevel + 1)
        viewModel.upgradeBuilding(kingdom: kingdom, buildingType: .walls, cost: cost)
        dismiss()
    }
    
    private func upgradeVault() {
        let cost = calculateVaultCost(kingdom.vaultLevel + 1)
        viewModel.upgradeBuilding(kingdom: kingdom, buildingType: .vault, cost: cost)
        dismiss()
    }
}

enum BuildingType {
    case walls
    case vault
    case mine
    case market
}
