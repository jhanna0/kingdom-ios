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
                    sectionDivider(title: "Economy")
                    
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
                        iconColor: KingdomTheme.Colors.buttonWarning,
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
                        benefit: marketBenefit(kingdom.marketLevel + 1),
                        hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Market"),
                        hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                        kingdom: kingdom,
                        upgradeCost: kingdom.marketUpgradeCost,
                        iconColor: KingdomTheme.Colors.royalPurple,
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
                        iconColor: KingdomTheme.Colors.buttonSuccess,
                        onCreateContract: {
                            selectedBuildingType = .farm
                        }
                    )
                    
                    // Civic Buildings Section
                    sectionDivider(title: "Civic")
                    
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
                        iconColor: KingdomTheme.Colors.royalBlue,
                        onCreateContract: {
                            selectedBuildingType = .education
                        }
                    )
                    
                    // Defensive Buildings Section
                    sectionDivider(title: "Defense")
                    
                    // Walls upgrade
                    BuildingUpgradeCardWithContract(
                        icon: "building.2.fill",
                        name: "Walls",
                        currentLevel: kingdom.wallLevel,
                        maxLevel: 5,
                        benefit: "+\((kingdom.wallLevel + 1) * 2) defenders during coups",
                        hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Walls"),
                        hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                        kingdom: kingdom,
                        upgradeCost: kingdom.wallUpgradeCost,
                        iconColor: KingdomTheme.Colors.buttonDanger,
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
                        benefit: "\((kingdom.vaultLevel + 1) * 20)% treasury protected from looting",
                        hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: "Vault"),
                        hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                        kingdom: kingdom,
                        upgradeCost: kingdom.vaultUpgradeCost,
                        iconColor: KingdomTheme.Colors.imperialGold,
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
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
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
    
    // MARK: - Section Divider
    
    private func sectionDivider(title: String) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            HStack {
                Text(title.uppercased())
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(1.5)
                
                Spacer()
            }
        }
    }
    
    // Benefit descriptions
    private func mineBenefit(_ level: Int) -> String {
        switch level {
        case 1: return "Unlocks Stone"
        case 2: return "Unlocks Stone, Iron"
        case 3: return "Unlocks Stone, Iron, Steel"
        case 4: return "Unlocks Stone, Iron, Steel, Titanium"
        case 5: return "All materials at 2x quantity"
        default: return ""
        }
    }
    
    private func marketBenefit(_ level: Int) -> String {
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
        return "+\(income)g per day"
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
        return "Contracts complete \(reduction)% faster"
    }
    
    private func educationBenefit(_ level: Int) -> String {
        let reduction = level * 5
        return "Citizens train skills \(reduction)% faster"
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
