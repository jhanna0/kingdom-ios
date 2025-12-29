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
                            name: "Mine",
                            currentLevel: kingdom.mineLevel,
                            maxLevel: 5,
                            benefit: mineBenefit(kingdom.mineLevel + 1),
                            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Mine"),
                            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                            kingdom: kingdom,
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
                            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Market"),
                            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                            kingdom: kingdom,
                            onCreateContract: {
                                selectedBuildingType = .market
                            }
                        )
                        
                        // Farm upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "leaf.fill",
                            name: "Farm",
                            currentLevel: kingdom.farmLevel,
                            maxLevel: 5,
                            benefit: farmBenefit(kingdom.farmLevel + 1),
                            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Farm"),
                            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                            kingdom: kingdom,
                            onCreateContract: {
                                selectedBuildingType = .farm
                            }
                        )
                        
                        // Civic Buildings Section
                        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                            Text("📚 Civic Buildings")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Support your citizens' development")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Education upgrade
                        BuildingUpgradeCardWithContract(
                            icon: "graduationcap.fill",
                            name: "Education Hall",
                            currentLevel: kingdom.educationLevel,
                            maxLevel: 5,
                            benefit: educationBenefit(kingdom.educationLevel + 1),
                            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Education"),
                            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                            kingdom: kingdom,
                            onCreateContract: {
                                selectedBuildingType = .education
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
                            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Walls"),
                            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                            kingdom: kingdom,
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
                            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Vault"),
                            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                            kingdom: kingdom,
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
                    viewModel: viewModel,
                    onSuccess: { buildingName in
                        // Contract created successfully!
                        selectedBuildingType = nil
                        
                        // Force refresh kingdom data
                        Task {
                            await viewModel.loadContracts()
                        }
                    }
                )
            }
    }
    
    // Income benefit descriptions
    private func mineBenefit(_ level: Int) -> String {
        let materials: [String] = {
            switch level {
            case 1: return ["Stone"]
            case 2: return ["Stone", "Iron"]
            case 3: return ["Stone", "Iron", "Steel"]
            case 4: return ["Stone", "Iron", "Steel", "Titanium"]
            case 5: return ["All materials at 2x quantity"]
            default: return []
            }
        }()
        return "Unlocks: " + materials.joined(separator: ", ")
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
    
    private func farmBenefit(_ level: Int) -> String {
        let reduction: Int = {
            switch level {
            case 1: return 5
            case 2: return 10
            case 3: return 20
            case 4: return 25
            case 5: return 33
            default: return 0
            }
        }()
        return "Citizens complete contracts \(reduction)% faster"
    }
    
    private func educationBenefit(_ level: Int) -> String {
        let reduction = level * 5
        return "-\(reduction)% training actions required (citizens train faster)"
    }
    
    /// Check if kingdom has an active contract for a specific building type
    /// Checks ALL contracts, not just kingdom.activeContract (since we can have multiple in DB before fix)
    private func hasActiveContractForBuilding(kingdom: Kingdom, buildingType: String) -> Bool {
        // Check all available contracts for this kingdom
        return viewModel.availableContracts.contains { contract in
            contract.kingdomId == kingdom.id &&
            contract.buildingType == buildingType &&
            (contract.status == .open || contract.status == .inProgress)
        }
    }
    
    /// Check if kingdom has ANY active contract (for blocking new contract creation)
    private func hasAnyActiveContract(kingdom: Kingdom) -> Bool {
        return viewModel.availableContracts.contains { contract in
            contract.kingdomId == kingdom.id &&
            (contract.status == .open || contract.status == .inProgress)
        }
    }
}

enum BuildingType {
    case walls
    case vault
    case mine
    case market
    case farm
    case education
}
