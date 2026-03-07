import SwiftUI

// Build Menu View - Brutalist Style
// Uses EmpireKingdomSummary from empire API (not Kingdom from map)
struct BuildMenuView: View {
    let kingdom: EmpireKingdomSummary
    @ObservedObject var player: Player
    let onRefresh: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    @State private var selectedBuilding: EmpireBuildingData?
    @State private var availableContracts: [Contract] = []
    @State private var isLoadingContracts = false
    
    // Group buildings by category from EmpireKingdomSummary.buildings
    private var buildingsByCategory: [(category: String, buildings: [EmpireBuildingData])] {
        let categories = Set(kingdom.buildings.map { $0.category })
        
        return categories.sorted().map { category in
            let buildings = kingdom.buildings
                .filter { $0.category == category }
                .sorted { $0.type < $1.type }
            return (category: category, buildings: buildings)
        }
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.xLarge) {
                    // Header with treasury
                    treasuryHeader
                    
                    // Render buildings by category
                    ForEach(buildingsByCategory, id: \.category) { categoryData in
                        if !categoryData.buildings.isEmpty {
                            sectionDivider(title: categoryData.category.capitalized)
                            
                            ForEach(categoryData.buildings) { building in
                                buildingCard(for: building)
                            }
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
        .task {
            await loadContracts()
        }
        .navigationDestination(item: $selectedBuilding) { building in
            ContractCreationView(
                kingdom: kingdom,
                building: building,
                onSuccess: { buildingName in
                    selectedBuilding = nil
                    Task {
                        await loadContracts()
                        await onRefresh()
                    }
                }
            )
        }
    }
    
    private func loadContracts() async {
        isLoadingContracts = true
        do {
            availableContracts = try await APIClient.shared.getAvailableContracts()
        } catch {
            print("Failed to load contracts: \(error)")
        }
        isLoadingContracts = false
    }
    
    // MARK: - Building Card
    
    @ViewBuilder
    private func buildingCard(for building: EmpireBuildingData) -> some View {
        let nextLevel = building.level + 1
        
        BuildingUpgradeCardWithContract(
            icon: building.icon,
            name: building.displayName,
            buildingType: building.type,
            currentLevel: building.level,
            maxLevel: building.maxLevel,
            benefit: building.nextTierBenefit ?? tierManager.buildingTierBenefit(building.type, tier: nextLevel),
            hasActiveContract: hasActiveContractForBuilding(buildingType: building.type),
            hasAnyActiveContract: hasAnyActiveContract(),
            treasuryGold: kingdom.treasuryGold,
            actionsRequired: building.upgradeCostActions ?? 0,
            iconColor: building.swiftColor,
            onCreateContract: {
                selectedBuilding = building
            }
        )
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
                
                let totalLevels = kingdom.buildings.reduce(0) { $0 + $1.level }
                let maxPossibleLevels = kingdom.buildings.reduce(0) { $0 + $1.maxLevel }
                Text("\(totalLevels)/\(maxPossibleLevels)")
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
    private func hasActiveContractForBuilding(buildingType: String) -> Bool {
        return availableContracts.contains { contract in
            contract.kingdomId == kingdom.id &&
            contract.buildingType == buildingType &&
            (contract.status == .open || contract.status == .inProgress)
        }
    }
    
    /// Check if kingdom has ANY active contract (for blocking new contract creation)
    private func hasAnyActiveContract() -> Bool {
        return availableContracts.contains { contract in
            contract.kingdomId == kingdom.id &&
            (contract.status == .open || contract.status == .inProgress)
        }
    }
}

