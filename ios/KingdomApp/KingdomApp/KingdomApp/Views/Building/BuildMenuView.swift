import SwiftUI

// Build Menu View - Brutalist Style
// NOW DYNAMIC - Building types come from TierManager!
struct BuildMenuView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    @State private var selectedBuildingTypeString: String?
    
    // Building categories from TierManager
    private var economyBuildings: [String] {
        tierManager.buildingTypesByCategory("economy")
    }
    
    private var defenseBuildings: [String] {
        tierManager.buildingTypesByCategory("defense")
    }
    
    private var civicBuildings: [String] {
        tierManager.buildingTypesByCategory("civic")
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.xLarge) {
                    // Header with treasury
                    treasuryHeader
                    
                    // Economic Buildings Section (dynamic!)
                    if !economyBuildings.isEmpty {
                        sectionDivider(title: "Economy")
                        
                        ForEach(economyBuildings, id: \.self) { buildingType in
                            buildingCard(for: buildingType)
                        }
                    }
                    
                    // Civic Buildings Section (dynamic!)
                    if !civicBuildings.isEmpty {
                        sectionDivider(title: "Civic")
                        
                        ForEach(civicBuildings, id: \.self) { buildingType in
                            buildingCard(for: buildingType)
                        }
                    }
                    
                    // Defensive Buildings Section (dynamic!)
                    if !defenseBuildings.isEmpty {
                        sectionDivider(title: "Defense")
                        
                        ForEach(defenseBuildings, id: \.self) { buildingType in
                            buildingCard(for: buildingType)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Manage Buildings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationDestination(item: $selectedBuildingTypeString) { buildingType in
            ContractCreationView(
                kingdom: kingdom,
                buildingType: buildingTypeFromString(buildingType),
                viewModel: viewModel,
                onSuccess: { buildingName in
                    selectedBuildingTypeString = nil
                    Task {
                        await viewModel.loadContracts()
                    }
                }
            )
        }
    }
    
    // MARK: - Dynamic Building Card
    
    @ViewBuilder
    private func buildingCard(for buildingType: String) -> some View {
        let info = tierManager.buildingTypeInfo(buildingType)
        let level = kingdom.buildingLevel(buildingType)
        let maxLevel = info?.maxTier ?? 5
        let nextLevel = level + 1
        
        BuildingUpgradeCardWithContract(
            icon: info?.icon ?? "building.fill",
            name: info?.displayName ?? buildingType.capitalized,
            currentLevel: level,
            maxLevel: maxLevel,
            benefit: tierManager.buildingTierBenefit(buildingType, tier: nextLevel),
            hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: buildingType.capitalized),
            hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
            kingdom: kingdom,
            upgradeCost: kingdom.upgradeCost(buildingType),
            iconColor: iconColor(for: buildingType),
            onCreateContract: {
                selectedBuildingTypeString = buildingType
            }
        )
    }
    
    // Map string to BuildingType enum (for backwards compatibility with ContractCreationView)
    private func buildingTypeFromString(_ type: String) -> BuildingType {
        switch type {
        case "wall": return .walls
        case "vault": return .vault
        case "mine": return .mine
        case "market": return .market
        case "farm": return .farm
        case "education": return .education
        default: return .mine  // fallback
        }
    }
    
    // Icon colors by building type
    private func iconColor(for buildingType: String) -> Color {
        switch buildingType {
        case "mine": return KingdomTheme.Colors.buttonWarning
        case "market": return KingdomTheme.Colors.royalPurple
        case "farm": return KingdomTheme.Colors.buttonSuccess
        case "education": return KingdomTheme.Colors.royalBlue
        case "wall": return KingdomTheme.Colors.buttonDanger
        case "vault": return KingdomTheme.Colors.imperialGold
        default: return KingdomTheme.Colors.inkMedium
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
