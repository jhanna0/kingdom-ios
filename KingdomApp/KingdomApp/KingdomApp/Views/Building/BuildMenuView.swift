import SwiftUI

// Build Menu View
struct BuildMenuView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Walls upgrade
                        BuildingUpgradeCard(
                            icon: "building.2.fill",
                            name: "Walls",
                            currentLevel: kingdom.wallLevel,
                            maxLevel: 5,
                            cost: calculateWallsCost(kingdom.wallLevel + 1),
                            benefit: "Adds \((kingdom.wallLevel + 1) * 2) defenders during coups",
                            kingdomTreasury: kingdom.treasuryGold,
                            onUpgrade: {
                                upgradeWalls()
                            }
                        )
                        
                        // Vault upgrade
                        BuildingUpgradeCard(
                            icon: "lock.shield.fill",
                            name: "Vault",
                            currentLevel: kingdom.vaultLevel,
                            maxLevel: 5,
                            cost: calculateVaultCost(kingdom.vaultLevel + 1),
                            benefit: "Protects \((kingdom.vaultLevel + 1) * 20)% of treasury from looting",
                            kingdomTreasury: kingdom.treasuryGold,
                            onUpgrade: {
                                upgradeVault()
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
        }
    }
    
    private func calculateWallsCost(_ level: Int) -> Int {
        return Int(Double(200) * pow(1.5, Double(level - 1)))
    }
    
    private func calculateVaultCost(_ level: Int) -> Int {
        return Int(Double(250) * pow(1.5, Double(level - 1)))
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
}
