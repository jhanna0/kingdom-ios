import SwiftUI

// Build Menu View - Brutalist Style
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
                VStack(spacing: KingdomTheme.Spacing.xLarge) {
                    // Header with treasury
                    treasuryHeader
                    
                    // Economic Buildings Section
                    buildingSection(
                        icon: "dollarsign.circle.fill",
                        title: "Economic Buildings",
                        subtitle: "Generate passive income for the city treasury",
                        iconColor: KingdomTheme.Colors.inkMedium
                    )
                    
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
                        upgradeCost: kingdom.mineUpgradeCost,
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
                        upgradeCost: kingdom.marketUpgradeCost,
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
                        upgradeCost: kingdom.farmUpgradeCost,
                        onCreateContract: {
                            selectedBuildingType = .farm
                        }
                    )
                    
                    // Civic Buildings Section
                    buildingSection(
                        icon: "graduationcap.fill",
                        title: "Civic Buildings",
                        subtitle: "Support your citizens' development",
                        iconColor: .blue
                    )
                    
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
                        upgradeCost: kingdom.educationUpgradeCost,
                        onCreateContract: {
                            selectedBuildingType = .education
                        }
                    )
                    
                    // Defensive Buildings Section
                    buildingSection(
                        icon: "shield.fill",
                        title: "Defensive Buildings",
                        subtitle: "Protect your kingdom from coups",
                        iconColor: KingdomTheme.Colors.buttonDanger
                    )
                    
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
                        upgradeCost: kingdom.wallUpgradeCost,
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
                        upgradeCost: kingdom.vaultUpgradeCost,
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
    
    // MARK: - Treasury Header
    
    private var treasuryHeader: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "building.columns.fill")
                .font(FontStyles.iconLarge)
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 12, shadowOffset: 3, borderWidth: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Kingdom Treasury")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("\(kingdom.treasuryGold) gold")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Buildings")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                let totalLevels = kingdom.mineLevel + kingdom.marketLevel + kingdom.farmLevel + kingdom.educationLevel + kingdom.wallLevel + kingdom.vaultLevel
                Text("\(totalLevels)/30")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Section Header
    
    private func buildingSection(icon: String, title: String, subtitle: String, iconColor: Color) -> some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .brutalistBadge(backgroundColor: iconColor, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(subtitle)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
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

enum BuildingType: Hashable {
    case walls
    case vault
    case mine
    case market
    case farm
    case education
}
