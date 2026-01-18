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
    @State private var showClaimError = false
    @State private var claimErrorMessage = ""
    @State private var isClaiming = false
    @State private var isProposingAlliance = false
    @State private var showAllianceResult = false
    @State private var allianceResultMessage = ""
    @State private var allianceResultSuccess = false
    // DYNAMIC: Single state for any building action - no hardcoded types!
    @State private var activeBuildingAction: BuildingClickAction?
    // Catchup state - for buildings that need catch-up work
    @State private var catchupBuilding: BuildingMetadata?
    
    // Battle state (Coups & Invasions)
    @State private var showBattleView = false
    @State private var isInitiatingCoup = false
    @State private var isDeclaringInvasion = false
    @State private var battleError: String?
    @State private var showBattleError = false
    @State private var initiatedBattleId: Int?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.xLarge) {
                // Header with medieval styling
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(
                            backgroundColor: Color(
                                red: kingdom.color.strokeRGBA.red,
                                green: kingdom.color.strokeRGBA.green,
                                blue: kingdom.color.strokeRGBA.blue
                            ),
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kingdom.name)
                            .font(FontStyles.displaySmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if kingdom.isUnclaimed {
                            Text("No ruler")
                                .font(FontStyles.bodySmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else {
                            HStack(spacing: 4) {
                                Text("Ruled by \(kingdom.rulerName)")
                                    .font(FontStyles.bodySmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if kingdom.isUnclaimed {
                        Text("Unclaimed")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 6)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Kingdom color divider with brutalist style
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal)
                
                // Ruler Actions - compact buttons
                if isPlayerInside && kingdom.rulerId == player.playerId {
                    HStack(spacing: 10) {
                        Button(action: onViewKingdom) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                                Text("Manage")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(KingdomTheme.Colors.parchmentLight)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                        }
                        
                        Button(action: onViewAllKingdoms) {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                                Text("All Kingdoms")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(KingdomTheme.Colors.parchmentLight)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if kingdom.canClaim {
                    // Backend says we can claim!
                    Button(action: {
                        isClaiming = true
                        Task {
                            do {
                                try await viewModel.claimKingdom()
                                // Dismiss sheet after short delay to let celebration popup show
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                dismiss()
                            } catch {
                                isClaiming = false
                                claimErrorMessage = error.localizedDescription
                                showClaimError = true
                                print("❌ Failed to claim: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            if isClaiming {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text(isClaiming ? "Claiming Your Kingdom..." : "Claim This Kingdom")
                                .font(FontStyles.headingMedium)
                                .fontWeight(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.large)
                        .foregroundColor(.white)
                    }
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 12, shadowOffset: 4, borderWidth: 3)
                    .disabled(isClaiming)
                    .padding(.horizontal)
                    .alert("Claim Failed", isPresented: $showClaimError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(claimErrorMessage)
                    }
                } else if isPlayerInside {
                    // Already present but someone else rules it
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("You are here")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(KingdomTheme.Spacing.small)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
                    .padding(.horizontal)
                } else {
                    // Not inside this kingdom
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text("You must travel here first")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(KingdomTheme.Spacing.small)
                    .padding(.horizontal)
                }
                
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
                    player: player,
                    onGatherIntel: {
                        Task {
                            do {
                                _ = try await viewModel.gatherIntelligence(kingdomId: kingdom.id)
                            } catch {
                                print("❌ Failed to gather intelligence: \(error)")
                            }
                        }
                    }
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
                if let contract = kingdom.activeContract {
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text("Active Contract")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Spacer()
                            if contract.isComplete {
                                Text("Complete")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                            } else {
                                Text("In Progress")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text("\(contract.buildingType) Level \(contract.buildingLevel)")
                                    .font(FontStyles.labelMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            
                            HStack(spacing: 8) {
                                Label("\(contract.contributorCount) contributors", systemImage: "person.2.fill")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                
                                Label("\(contract.rewardPool) pool", systemImage: "g.circle.fill")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.goldLight)
                            }
                            
                            // Progress bar
                            if !contract.isComplete {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Progress")
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkLight)
                                        Spacer()
                                        Text(String(format: "%.0f%%", contract.progress * 100))
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                                .frame(height: 6)
                                                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                            
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.buttonWarning)
                                                .frame(width: geometry.size.width * contract.progress, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                        }
                    }
                    .padding(KingdomTheme.Spacing.medium)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    .padding(.horizontal)
                }
                
                // Alliance status banner (if allied)
                if kingdom.isAllied, let allianceInfo = kingdom.allianceInfo {
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        Image(systemName: "handshake.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.buttonSuccess,
                                cornerRadius: 10,
                                shadowOffset: 2,
                                borderWidth: 2
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allied Kingdom")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("\(allianceInfo.daysRemaining) days remaining")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                    .padding(KingdomTheme.Spacing.medium)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.buttonSuccess.opacity(0.1), cornerRadius: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KingdomTheme.Colors.buttonSuccess, lineWidth: 2)
                    )
                    .padding(.horizontal)
                }
                
                // Action buttons - Medieval war council style (backend controls visibility)
                if kingdom.canDeclareWar || kingdom.canFormAlliance || !kingdom.isAllied {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                        .padding(.horizontal)
                    
                    VStack(spacing: KingdomTheme.Spacing.small) {
                        if kingdom.canDeclareWar {
                            Button(action: {
                                // TODO: Implement declare war
                                print("Declare war on \(kingdom.name)")
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(.white)
                                    Text("Declare War")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
                        }
                        
                        if kingdom.canFormAlliance {
                            Button(action: {
                                isProposingAlliance = true
                                Task {
                                    await proposeAlliance()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isProposingAlliance {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "handshake.fill")
                                            .font(FontStyles.iconSmall)
                                            .foregroundColor(.white)
                                    }
                                    Text(isProposingAlliance ? "Proposing..." : "Propose Alliance")
                                        .font(FontStyles.bodyMediumBold)
                                    
                                    Spacer()
                                    
                                    // Show cost
                                    HStack(spacing: 4) {
                                        Image(systemName: "g.circle.fill")
                                            .font(.caption)
                                        Text("500")
                                            .font(FontStyles.labelSmall)
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
                            .disabled(isProposingAlliance)
                        }
                        
                        // Stage Coup button - only show if can stage or has reason
                        if kingdom.canStageCoup {
                            Button(action: {
                                initiateCoup(kingdomId: kingdom.id)
                            }) {
                                HStack(spacing: 8) {
                                    if isInitiatingCoup {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                            .font(FontStyles.iconSmall)
                                            .foregroundColor(.white)
                                    }
                                    Text(isInitiatingCoup ? "Starting Coup..." : "Stage Coup")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSpecial, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
                            .disabled(isInitiatingCoup)
                        } else if let reason = kingdom.coupIneligibilityReason {
                            // Show disabled button with reason
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(KingdomTheme.Colors.inkLight)
                                    Text("Stage Coup")
                                        .font(FontStyles.bodyMediumBold)
                                        .foregroundColor(KingdomTheme.Colors.inkLight)
                                }
                                Text(reason)
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(KingdomTheme.Spacing.medium)
                            .background(KingdomTheme.Colors.parchmentMuted)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KingdomTheme.Colors.inkLight, lineWidth: 2))
                        }
                        
                        // Declare Invasion button - only for rulers at enemy kingdoms
                        if kingdom.canDeclareWar && kingdom.rulerId != nil && kingdom.rulerId != player.playerId {
                            Button(action: {
                                declareInvasion(kingdomId: kingdom.id)
                            }) {
                                HStack(spacing: 8) {
                                    if isDeclaringInvasion {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "flag.2.crossed.fill")
                                            .font(FontStyles.iconSmall)
                                            .foregroundColor(.white)
                                    }
                                    Text(isDeclaringInvasion ? "Declaring..." : "Declare Invasion")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
                            .disabled(isDeclaringInvasion)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.top)
            }
        .background(KingdomTheme.Colors.parchment)
        .alert(allianceResultSuccess ? "Alliance Proposed!" : "Alliance Failed", isPresented: $showAllianceResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(allianceResultMessage)
        }
        // DYNAMIC: Single fullScreenCover for ALL building actions
        .fullScreenCover(item: $activeBuildingAction) { action in
            BuildingActionView(
                action: action,
                kingdom: kingdom,
                playerId: player.playerId,
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
    }
    
    // MARK: - Alliance Actions
    
    private func proposeAlliance() async {
        do {
            let response = try await APIClient.shared.proposeAlliance(targetEmpireId: kingdom.id)
            
            await MainActor.run {
                isProposingAlliance = false
                allianceResultSuccess = response.success
                allianceResultMessage = response.message
                showAllianceResult = true
            }
        } catch {
            await MainActor.run {
                isProposingAlliance = false
                allianceResultSuccess = false
                allianceResultMessage = error.localizedDescription
                showAllianceResult = true
            }
        }
    }
    
    // MARK: - Kingdom Overview (Table with Icons)
    
    private var kingdomOverviewCard: some View {
        VStack(spacing: 0) {
            // Present
            statRow(icon: "person.3.fill", iconColor: KingdomTheme.Colors.royalBlue, label: "Present", value: "\(kingdom.checkedInPlayers)")
            Divider()
            
            // Citizens
            statRow(icon: "person.2.circle.fill", iconColor: KingdomTheme.Colors.imperialGold, label: "Citizens", value: "\(kingdom.activeCitizens)")
            
            if !kingdom.isUnclaimed {
                Divider()
                statRow(icon: "percent", iconColor: KingdomTheme.Colors.buttonWarning, label: "Tax Rate", value: "\(kingdom.taxRate)%")
                Divider()
                statRow(icon: "figure.walk.arrival", iconColor: KingdomTheme.Colors.buttonPrimary, label: "Entry Fee", value: "\(kingdom.travelFee)g")
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .brutalistBadge(backgroundColor: iconColor, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            
            Text(label)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Spacer()
            
            Text(value)
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Kingdom Buildings Card
    
    private var kingdomBuildingsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Buildings")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            let sortedBuildings = kingdom.sortedBuildings()
            
            if sortedBuildings.isEmpty {
                ProgressView().padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedBuildings, id: \.type) { building in
                        buildingRow(building: building)
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    // MARK: - Building Row with brutalist icon badge
    
    @ViewBuilder
    private func buildingRow(building: BuildingMetadata) -> some View {
        let isBuilt = building.level > 0
        let color = Color(hex: building.colorHex) ?? KingdomTheme.Colors.inkMedium
        // DYNAMIC: Building is clickable if backend says so AND player is inside
        let isClickable = isPlayerInside && building.isClickable
        // Check if player needs to complete catch-up work
        let needsCatchup = building.needsCatchup && isPlayerInside
        
        let content = HStack(spacing: 10) {
            // Icon with level badge - brutalist style
            ZStack(alignment: .topTrailing) {
                Image(systemName: building.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .brutalistBadge(
                        backgroundColor: isBuilt ? color : KingdomTheme.Colors.inkLight,
                        cornerRadius: 8,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                if isBuilt {
                    Text("\(building.level)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .brutalistBadge(backgroundColor: .black, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
                        .offset(x: 6, y: -6)
                }
            }
            
            // Name + description
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(building.displayName)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Show expand badge if building needs capacity expansion
                    if needsCatchup {
                        Text("EXPAND")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(KingdomTheme.Colors.buttonWarning)
                            .cornerRadius(4)
                    }
                }
                
                if needsCatchup, let catchup = building.catchup {
                    Text("\(catchup.actionsCompleted)/\(catchup.actionsRequired) actions to unlock")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        .lineLimit(1)
                } else {
                    Text(building.description)
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Chevron for clickable buildings or catchup
            if isClickable || needsCatchup {
                Image(systemName: needsCatchup ? "hammer.fill" : "chevron.right")
                    .font(FontStyles.iconMini)
                    .foregroundColor(needsCatchup ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(10)
        .background(isBuilt ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(needsCatchup ? KingdomTheme.Colors.buttonWarning : Color.black, lineWidth: needsCatchup ? 2 : 1.5))
        
        // Handle click: catchup takes priority over normal action
        if needsCatchup {
            Button {
                catchupBuilding = building
            } label: { content }
            .buttonStyle(.plain)
        } else if isClickable, let clickAction = building.clickAction {
            Button {
                activeBuildingAction = clickAction
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
    
    // MARK: - Battle Actions
    
    private func initiateCoup(kingdomId: String) {
        isInitiatingCoup = true
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/battles/coup/initiate",
                    method: "POST",
                    body: ["kingdom_id": kingdomId]
                )
                let response: BattleInitiateResponse = try await APIClient.shared.execute(request)
                await MainActor.run {
                    initiatedBattleId = response.battleId
                    showBattleView = true
                    isInitiatingCoup = false
                }
            } catch {
                await MainActor.run {
                    battleError = error.localizedDescription
                    showBattleError = true
                    isInitiatingCoup = false
                }
            }
        }
    }
    
    private func declareInvasion(kingdomId: String) {
        isDeclaringInvasion = true
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/battles/invasion/declare",
                    method: "POST",
                    body: ["target_kingdom_id": kingdomId]
                )
                let response: BattleInitiateResponse = try await APIClient.shared.execute(request)
                await MainActor.run {
                    initiatedBattleId = response.battleId
                    showBattleView = true
                    isDeclaringInvasion = false
                }
            } catch {
                await MainActor.run {
                    battleError = error.localizedDescription
                    showBattleError = true
                    isDeclaringInvasion = false
                }
            }
        }
    }
}
