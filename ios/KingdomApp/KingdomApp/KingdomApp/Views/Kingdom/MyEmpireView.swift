import SwiftUI

/// Full empire overview for rulers - SERVER-DRIVEN UI
/// All icons, colors, labels come from backend config
struct MyEmpireView: View {
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @State private var empireData: EmpireOverviewResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let empire = empireData {
                    empireContent(empire)
                } else {
                    noEmpireView
                }
            }
            .navigationTitle("My Empire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await loadEmpireData() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(FontStyles.iconSmall)
                    }
                }
            }
        }
        .task {
            await loadEmpireData()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(empireData?.uiConfig.loadingMessage ?? "Loading Empire...")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        let config = empireData?.uiConfig
        return VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(KingdomTheme.Colors.royalCrimson)
            
            Text(config?.errorTitle ?? "Error")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(message)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { Task { await loadEmpireData() } }) {
                Text(config?.errorRetry ?? "Retry")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
            }
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 8)
        }
    }
    
    // MARK: - No Empire View (uses fallback since no config yet)
    
    private var noEmpireView: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("No Empire Yet")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Conquer a kingdom to establish your empire!")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Empire Content
    
    private func empireContent(_ empire: EmpireOverviewResponse) -> some View {
        let config = empire.uiConfig
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Empire Header - uses config
                empireHeader(empire, config: config)
                
                // Stats Row - uses config.stats
                statsRow(empire, config: config)
                
                // Active Wars (if any)
                if !empire.activeWars.isEmpty {
                    activeWarsSection(empire.activeWars, config: config)
                }
                
                // Kingdoms List
                kingdomsSection(empire.kingdoms, config: config)
                
                // Alliances (if any)
                if !empire.alliances.isEmpty {
                    alliancesSection(empire.alliances, config: config)
                }
            }
            .padding(.bottom, KingdomTheme.Spacing.xLarge)
        }
    }
    
    // MARK: - Empire Header
    
    private func empireHeader(_ empire: EmpireOverviewResponse, config: EmpireUIConfig) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: config.headerIcon)
                .font(FontStyles.iconExtraLarge)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .brutalistBadge(backgroundColor: config.headerSwiftColor, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
            
            Text(empire.empireName)
                .font(FontStyles.displayMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Use template from config
            let subtitle = config.subtitleTemplate
                .replacingOccurrences(of: "{kingdom_count}", with: "\(empire.kingdomCount)")
                .replacingOccurrences(of: "{plural}", with: empire.kingdomCount == 1 ? "" : "s")
            
            Text(subtitle)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding()
    }
    
    // MARK: - Stats Row - SERVER DRIVEN
    
    private func statsRow(_ empire: EmpireOverviewResponse, config: EmpireUIConfig) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // First row: treasury + personal gold
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.large) {
                ForEach(config.stats.prefix(2), id: \.id) { stat in
                    statItem(stat: stat, value: getValue(for: stat.id, from: empire))
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Second row: rest of stats
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.large) {
                ForEach(config.stats.dropFirst(2), id: \.id) { stat in
                    let value = getValue(for: stat.id, from: empire)
                    let isInactive = stat.id == "active_wars" && value == 0
                    statItem(stat: stat, value: value, useInactiveColor: isInactive)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private func getValue(for statId: String, from empire: EmpireOverviewResponse) -> Int {
        switch statId {
        case "total_treasury": return empire.totalTreasury
        case "personal_gold": return empire.personalGold
        case "total_subjects": return empire.totalSubjects
        case "active_wars": return empire.warsAttacking + empire.warsDefending
        case "alliance_count": return empire.allianceCount
        default: return 0
        }
    }
    
    private func statItem(stat: StatConfig, value: Int, useInactiveColor: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: stat.icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(useInactiveColor ? stat.swiftColorInactive : stat.swiftColor)
                .frame(height: 24, alignment: .center)
            
            Text("\(value)\(stat.suffix ?? "")")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(height: 24, alignment: .center)
            
            Text(stat.label)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .lineLimit(1)
                .frame(height: 18, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    // MARK: - Active Wars Section
    
    private func activeWarsSection(_ wars: [ActiveWarSummary], config: EmpireUIConfig) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: config.warsSection.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(config.warsSection.swiftColor)
                
                Text(config.warsSection.title)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            ForEach(wars) { war in
                warCard(war, config: config)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private func warCard(_ war: ActiveWarSummary, config: EmpireUIConfig) -> some View {
        let isAttacking = war.type == "attacking"
        let icon = isAttacking ? config.warsAttackingIcon : config.warsDefendingIcon
        let color = isAttacking ? config.warsAttackingSwiftColor : config.warsDefendingSwiftColor
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .brutalistBadge(backgroundColor: color, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isAttacking ? "Attacking \(war.targetKingdomName)" : "Defending \(war.targetKingdomName)")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Phase: \(war.phase.capitalized) • \(war.attackerCount) vs \(war.defenderCount)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    // MARK: - Alliances Section
    
    private func alliancesSection(_ alliances: [EmpireAllianceSummary], config: EmpireUIConfig) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: config.alliancesSection.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(config.alliancesSection.swiftColor)
                
                Text(config.alliancesSection.title)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            ForEach(alliances) { alliance in
                allianceCard(alliance, config: config)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    private func allianceCard(_ alliance: EmpireAllianceSummary, config: EmpireUIConfig) -> some View {
        HStack(spacing: 12) {
            Image(systemName: config.alliancesSection.icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .brutalistBadge(backgroundColor: config.alliancesSection.swiftColor, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alliance.alliedEmpireName)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(alliance.alliedKingdomCount) \(config.alliancesKingdomsLabel) • \(alliance.daysRemaining) \(config.alliancesDaysLabel)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    // MARK: - Kingdoms Section
    
    private func kingdomsSection(_ kingdoms: [EmpireKingdomSummary], config: EmpireUIConfig) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: config.kingdomsSection.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(config.kingdomsSection.swiftColor)
                
                Text(config.kingdomsSection.title)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, KingdomTheme.Spacing.small)
            
            ForEach(kingdoms) { kingdom in
                empireKingdomCard(kingdom, config: config)
            }
        }
    }
    
    private func empireKingdomCard(_ kingdom: EmpireKingdomSummary, config: EmpireUIConfig) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                if kingdom.isCapital {
                    Image(systemName: config.kingdomsCapitalIcon)
                        .font(FontStyles.iconSmall)
                        .foregroundColor(config.kingdomsCapitalSwiftColor)
                }
                
                Text(kingdom.name)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if kingdom.isCapital {
                    Text(config.kingdomsCapitalBadge)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .brutalistBadge(backgroundColor: config.kingdomsCapitalSwiftColor, cornerRadius: 4)
                }
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Stats - from config (equal width columns)
            HStack(alignment: .top, spacing: 0) {
                ForEach(config.kingdomStats, id: \.id) { stat in
                    kingdomStatItem(
                        icon: getStatIcon(for: stat),
                        value: getKingdomValue(for: stat.id, from: kingdom),
                        suffix: getStatSuffix(for: stat),
                        label: stat.label
                    )
                }
            }
            .padding(.vertical, 8)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Actions - NavigationLinks
            HStack(spacing: KingdomTheme.Spacing.medium) {
                ForEach(config.kingdomActions, id: \.id) { action in
                    kingdomActionLink(action: action, kingdom: kingdom, config: config)
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    /// Get icon for stat - override percent to something better
    private func getStatIcon(for stat: StatConfig) -> String {
        // If the icon is "percent" which doesn't exist, use a better alternative
        if stat.icon == "percent" {
            return "slider.horizontal.3"
        }
        return stat.icon
    }
    
    /// Get suffix for stat - skip % suffix if we're showing tax (icon already implies it)
    private func getStatSuffix(for stat: StatConfig) -> String? {
        // Don't show % suffix for tax_rate since label says "Tax"
        if stat.id == "tax_rate" {
            return "%"
        }
        return stat.suffix
    }
    
    @ViewBuilder
    private func kingdomActionLink(action: KingdomActionConfig, kingdom: EmpireKingdomSummary, config: EmpireUIConfig) -> some View {
        switch action.id {
        case "treasury":
            NavigationLink(destination: TreasuryManagementView(
                kingdom: kingdom,
                player: player,
                uiConfig: config,
                onComplete: { Task { await loadEmpireData() } }
            )) {
                actionButtonContent(action: action)
            }
            .buttonStyle(PlainButtonStyle())
        case "manage":
            NavigationLink(destination: KingdomDetailView(kingdomId: kingdom.id, player: player, viewModel: viewModel)) {
                actionButtonContent(action: action)
            }
            .buttonStyle(PlainButtonStyle())
        default:
            EmptyView()
        }
    }
    
    private func actionButtonContent(action: KingdomActionConfig) -> some View {
        HStack(spacing: 6) {
            Image(systemName: action.icon)
                .font(FontStyles.iconSmall)
            Text(action.label)
                .font(FontStyles.labelMedium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .brutalistBadge(backgroundColor: action.swiftColor, cornerRadius: 8)
    }
    
    private func getKingdomValue(for statId: String, from kingdom: EmpireKingdomSummary) -> String {
        switch statId {
        case "treasury": return "\(kingdom.treasuryGold)"
        case "subjects": return "\(kingdom.checkedInPlayers)"
        case "tax_rate": return "\(kingdom.taxRate)"
        default: return "0"
        }
    }
    
    private func kingdomStatItem(icon: String, value: String, suffix: String?, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(height: 24, alignment: .center)
            
            Text(value + (suffix ?? ""))
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(height: 24, alignment: .center)
            
            Text(label)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .lineLimit(1)
                .frame(height: 18, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadEmpireData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.getMyEmpire()
            empireData = response
        } catch let error as APIError {
            if case .serverError(let message) = error {
                if message.contains("must rule a kingdom") {
                    errorMessage = nil  // Show no empire view instead
                    empireData = nil
                } else {
                    errorMessage = message
                }
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Make EmpireKingdomSummary Identifiable for sheet

extension EmpireKingdomSummary: Hashable {
    static func == (lhs: EmpireKingdomSummary, rhs: EmpireKingdomSummary) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
