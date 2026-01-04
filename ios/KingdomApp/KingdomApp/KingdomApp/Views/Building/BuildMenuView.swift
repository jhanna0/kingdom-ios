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
    
    // FULLY DYNAMIC - Group buildings by whatever categories backend provides!
    private var buildingsByCategory: [(category: String, buildings: [String])] {
        // Get all unique categories from metadata
        let categories = Set(kingdom.buildingMetadata.values.map { $0.category })
        
        // Group buildings by category
        return categories.sorted().map { category in
            let buildings = kingdom.buildingMetadata.values
                .filter { $0.category == category }
                .map { $0.type }
                .sorted()
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
                    
                    // FULLY DYNAMIC - Render whatever categories backend provides!
                    ForEach(buildingsByCategory, id: \.category) { categoryData in
                        if !categoryData.buildings.isEmpty {
                            sectionDivider(title: categoryData.category.capitalized)
                            
                            ForEach(categoryData.buildings, id: \.self) { buildingType in
                                buildingCard(for: buildingType)
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
            // Load contracts when view appears so we can check for active contracts
            await viewModel.loadContracts()
        }
        .navigationDestination(item: $selectedBuildingTypeString) { buildingType in
            ContractCreationView(
                kingdom: kingdom,
                buildingType: buildingType,  // FULLY DYNAMIC - pass string directly
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
        // FULLY DYNAMIC - Get metadata from kingdom (populated from backend)
        if let metadata = kingdom.buildingMetadata(buildingType) {
            let level = kingdom.buildingLevel(buildingType)
            let nextLevel = level + 1
            
            BuildingUpgradeCardWithContract(
                icon: metadata.icon,
                name: metadata.displayName,
                currentLevel: level,
                maxLevel: metadata.maxLevel,
                benefit: tierManager.buildingTierBenefit(buildingType, tier: nextLevel),
                hasActiveContract: hasActiveContractForBuilding(kingdom: kingdom, buildingType: buildingType),  // Use key, not displayName
                hasAnyActiveContract: hasAnyActiveContract(kingdom: kingdom),
                kingdom: kingdom,
                upgradeCost: kingdom.upgradeCost(buildingType),
                iconColor: Color(hex: metadata.colorHex) ?? KingdomTheme.Colors.inkMedium,
                onCreateContract: {
                    selectedBuildingTypeString = buildingType
                }
            )
        } else {
            // Should never happen if backend is working properly
            Text("Building data unavailable")
                .foregroundColor(.red)
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
                
                // FULLY DYNAMIC - calculate from kingdom metadata or fallback
                let allBuildingTypes = kingdom.allBuildingTypes()
                let totalLevels = allBuildingTypes.reduce(0) { $0 + kingdom.buildingLevel($1) }
                let maxPossibleLevels = allBuildingTypes.count * 5  // Dynamic count x 5 levels
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

