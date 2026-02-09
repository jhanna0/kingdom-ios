import SwiftUI

// Sheet wrapper for KingdomInfoCard with proper dismiss handling
struct KingdomInfoSheetView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let isPlayerInside: Bool
    let onViewKingdom: () -> Void
    let onViewAllKingdoms: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Claim State
    @State var showClaimError = false
    @State var claimErrorMessage = ""
    @State var isClaiming = false
    
    // MARK: - Building Action State
    // DYNAMIC: Single state for any building action - no hardcoded types!
    @State var activeBuildingAction: BuildingClickAction?
    // Catchup state - for buildings that need catch-up work
    @State var catchupBuilding: BuildingMetadata?
    // Permit state - for visitors who need to buy a permit
    @State var permitBuilding: BuildingMetadata?
    // Exhausted state - for buildings that have hit daily limit
    @State var showExhaustedAlert = false
    @State var exhaustedMessage = ""
    
    // MARK: - Battle State (Coups & Invasions)
    @State var showBattleView = false
    @State var isInitiatingCoup = false
    @State var isDeclaringInvasion = false
    @State var battleError: String?
    @State var showBattleError = false
    @State var initiatedBattleId: Int?
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.xLarge) {
                // Header with medieval styling
                headerSection
                
                // Ruler Actions - compact buttons
                rulerActionsSection
                
                // Kingdom Overview - Population & Laws (compact)
                kingdomOverviewCard
                
                // Kingdom Buildings with Town Hall & Market nav links
                if !kingdom.isUnclaimed {
                    kingdomBuildingsCard
                }
                
                // Military Strength / Intelligence
                MilitaryStrengthCard(
                    strength: viewModel.militaryStrengthCache[kingdom.id],
                    kingdom: kingdom,
                    player: player
                )
                .padding(.horizontal)
                .task {
                    // Load military strength when sheet opens
                    print("🎯 KingdomInfoSheet loading strength for: \(kingdom.id)")
                    if viewModel.militaryStrengthCache[kingdom.id] == nil {
                        print("🎯 Cache miss, fetching...")
                        await viewModel.fetchMilitaryStrength(kingdomId: kingdom.id)
                    } else {
                        print("🎯 Cache hit!")
                    }
                }
                
                // Active Contract Section
                activeContractSection
                
                // Active Alliances section (only shown for player's hometown)
                activeAlliancesSection
                
                // Alliance status banner (if viewing an allied kingdom - not your hometown)
                allianceStatusBanner
            }
            .padding(.top)
        }
        .background(KingdomTheme.Colors.parchment)
        // DYNAMIC: Single fullScreenCover for ALL building actions
        .fullScreenCover(item: $activeBuildingAction) { action in
            BuildingActionView(
                action: action,
                kingdom: kingdom,
                playerId: player.playerId,
                scienceLevel: player.science,
                onDismiss: { activeBuildingAction = nil }
            )
        }
        // Catchup view for buildings that need catch-up work
        .fullScreenCover(item: $catchupBuilding) { building in
            NavigationStack {
                BuildingCatchupView(
                    building: building,
                    kingdom: kingdom,
                    onDismiss: { catchupBuilding = nil },
                    onComplete: {
                        // Refresh kingdom data after completing catchup
                        Task {
                            await viewModel.refreshKingdomData()
                        }
                    }
                )
            }
        }
        // Permit purchase view for visitors
        .fullScreenCover(item: $permitBuilding) { building in
            NavigationStack {
                BuildingPermitView(
                    building: building,
                    kingdom: kingdom,
                    onDismiss: { permitBuilding = nil },
                    onPurchased: {
                        // Refresh this specific kingdom's data after purchasing permit
                        permitBuilding = nil
                        Task {
                            await viewModel.refreshKingdom(id: kingdom.id)
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showBattleView) {
            if let battleId = initiatedBattleId {
                BattleView(battleId: battleId, onDismiss: { showBattleView = false })
            }
        }
        .alert("Battle Failed", isPresented: $showBattleError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(battleError ?? "Unknown error")
        }
        .alert("Resources Exhausted", isPresented: $showExhaustedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exhaustedMessage)
        }
    }
}
