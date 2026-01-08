import SwiftUI

// MARK: - Hunt Phase View
// Shows the current phase with probability displays and roll results
// MOBILE-FIRST LAYOUT: Content at top, BUTTONS AT BOTTOM

struct HuntPhaseView: View {
    @ObservedObject var viewModel: HuntViewModel
    let phase: HuntPhase
    let showingIntro: Bool
    
    var body: some View {
        ZStack {
            // Base parchment background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            // Main phase content (visible when not showing intro)
            if !showingIntro {
                phaseContent
            }
            
            // Phase intro overlay
            if showingIntro {
                PhaseIntroOverlay(
                    phase: phase,
                    config: viewModel.config,
                    onBegin: {
                        Task {
                            await viewModel.userTappedBeginPhase()
                        }
                    }
                )
            }
            
            // PhaseCompleteOverlay is now shown directly from HuntView
            // to prevent flashing during state transitions
        }
    }
    
    // MARK: - Phase Content
    // MOBILE-FIRST: Content scrolls at top, buttons pinned at bottom
    
    private var phaseContent: some View {
        VStack(spacing: 0) {
            // Scrollable content area
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    // Phase header with icon
                    phaseHeader
                    
                    // Compact stats row: Skill | Chance | Attempts
                    compactStatsRow
                    
                    // Phase-specific goal display (creature odds / damage bar / blessing odds)
                    phaseGoalDisplay
                        .padding(.horizontal)
                    
                    // Result message
                    rollResultMessage
                        .padding(.top, 8)
                    
                    // Round results (roll history) - horizontal scroll
                    roundResultsSection
                }
                .padding(.top, KingdomTheme.Spacing.medium)
                .padding(.bottom, 160) // Space for pinned buttons
            }
            
            // PINNED ACTION BUTTONS AT BOTTOM - MOBILE GAME STYLE!
            pinnedActionButtons
        }
    }
    
    // MARK: - Phase Header
    
    private var phaseHeader: some View {
        HStack(spacing: 12) {
            // Phase icon with brutalist badge
            Image(systemName: phase.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .brutalistBadge(
                    backgroundColor: rollButtonColor,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.displayName)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(rollInstructionText)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Rolling indicator
            if case .rolling = viewModel.uiState {
                ProgressView()
                    .tint(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Compact Stats Row
    // Horizontal: [SKILL] | [CHANCE] | [ATTEMPTS]
    
    private var compactStatsRow: some View {
        HStack(spacing: 8) {
            // Skill badge
            statBadge(
                icon: statIcon,
                label: statDisplayName,
                value: "\(getStatValue(for: phase))",
                color: KingdomTheme.Colors.inkMedium
            )
            
            // Hit chance badge
            statBadge(
                icon: "target",
                label: "Hit Chance",
                value: "\(successChance)%",
                color: chanceColor
            )
            
            // Attempts badge
            statBadge(
                icon: "dice.fill",
                label: "Attempts",
                value: "\(viewModel.maxRolls - viewModel.rollsCompleted)/\(viewModel.maxRolls)",
                color: viewModel.rollsCompleted >= viewModel.maxRolls - 1 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium
            )
        }
        .padding(.horizontal)
    }
    
    private func statBadge(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    private var statDisplayName: String {
        switch phase {
        case .track: return "Intelligence"
        case .strike: return "Attack"
        case .blessing: return "Faith"
        default: return "Skill"
        }
    }
    
    private var statIcon: String {
        switch phase {
        case .track: return "brain.head.profile"
        case .strike: return "bolt.fill"
        case .blessing: return "sparkles"
        default: return "star.fill"
        }
    }
    
    private var successChance: Int {
        let statValue = getStatValue(for: phase)
        let base = 15 + (statValue * 8)
        return min(95, max(10, base))
    }
    
    private var chanceColor: Color {
        if successChance >= 65 { return KingdomTheme.Colors.buttonSuccess }
        if successChance >= 45 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonDanger
    }
    
    private func getStatValue(for phase: HuntPhase) -> Int {
        guard let hunt = viewModel.hunt,
              let participant = hunt.participants.values.first(where: { $0.player_id == viewModel.currentUserId }) else {
            return 0
        }
        
        switch phase {
        case .track: return participant.stats?["intelligence"] ?? 0
        case .strike: return participant.stats?["attack_power"] ?? 0
        case .blessing: return participant.stats?["faith"] ?? 0
        default: return 0
        }
    }
    
    // MARK: - Phase Goal Display
    // Now includes INLINE master roll animation - no overlay!
    
    private var isShowingMasterRoll: Bool {
        if case .resolving = viewModel.uiState { return true }
        if case .masterRollAnimation = viewModel.uiState { return true }
        return false
    }
    
    @ViewBuilder
    private var phaseGoalDisplay: some View {
        switch phase {
        case .track:
            DropTableBar(
                title: isShowingMasterRoll ? "MASTER ROLL" : "CREATURE ODDS",
                slots: viewModel.dropTableSlots,
                displayConfig: .creatures(config: viewModel.config),
                masterRollValue: viewModel.masterRollValue,
                isAnimatingMasterRoll: viewModel.masterRollAnimating
            )
            
        case .strike:
            VStack(spacing: 8) {
                CombatHPBar(
                    animal: viewModel.hunt?.animal,
                    animalHP: viewModel.hunt?.animal?.hp ?? 1
                )
                DropTableBar(
                    title: isShowingMasterRoll ? "FINAL DAMAGE" : "DAMAGE ODDS",
                    slots: viewModel.dropTableSlots,
                    displayConfig: .damage,
                    masterRollValue: viewModel.masterRollValue,
                    isAnimatingMasterRoll: viewModel.masterRollAnimating
                )
            }
            
        case .blessing:
            DropTableBar(
                title: isShowingMasterRoll ? "LOOT ROLL" : "LOOT BONUS ODDS",
                slots: viewModel.dropTableSlots,
                displayConfig: .blessing,
                masterRollValue: viewModel.masterRollValue,
                isAnimatingMasterRoll: viewModel.masterRollAnimating
            )
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Roll Result Message
    
    private var rollResultMessage: some View {
        Group {
            if let lastRoll = viewModel.lastRollResult {
                HStack(spacing: 8) {
                    Text(lastRoll.message)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(lastRoll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                    
                    if lastRoll.is_critical {
                        Text("⚡")
                            .font(.title2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        // SOLID tinted parchment - no opacity!
                        RoundedRectangle(cornerRadius: 10)
                            .fill(lastRoll.is_success ? Color(red: 0.85, green: 0.92, blue: 0.82) : Color(red: 0.95, green: 0.85, blue: 0.82))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(lastRoll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger, lineWidth: 2)
                            )
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 50)
        .animation(.spring(response: 0.3), value: viewModel.lastRollResult?.round)
    }
    
    private var rollInstructionText: String {
        switch phase {
        case .track: return "Scout the area to improve your odds"
        case .strike: return "Strike to deal damage"
        case .blessing: return "Pray for better loot"
        default: return "Roll to take action"
        }
    }
    
    // MARK: - Round Results Section
    
    private var roundResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.roundResults.isEmpty {
                Text("ROLL HISTORY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.roundResults) { result in
                            RoundResultCard(result: result)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 110)
            } else {
                // Empty state - subtle prompt
                HStack(spacing: 12) {
                    Image(systemName: phase == .track ? "pawprint.fill" : phase == .strike ? "bolt.fill" : "sparkles")
                        .font(.title2)
                        .foregroundColor(rollButtonColor.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready to \(rollButtonLabel.lowercased())")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("Tap the button below to attempt")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KingdomTheme.Colors.parchmentLight)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Pinned Action Buttons (BOTTOM OF SCREEN!)
    
    private var pinnedActionButtons: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            // Buttons area - show during ALL active states (no overlay BS)
            Group {
                switch viewModel.uiState {
                case .phaseActive, .rolling, .rollRevealing:
                    actionButtonsRow
                case .resolving, .masterRollAnimation:
                    // Show rolling state - same screen, just disabled buttons
                    masterRollInProgressRow
                default:
                    // Placeholder maintains consistent height
                    Color.clear
                        .frame(height: 100)
                }
            }
            .background(KingdomTheme.Colors.parchmentLight)
        }
    }
    
    private var masterRollInProgressRow: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            if viewModel.masterRollAnimating {
                // Animation in progress - show spinner
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(KingdomTheme.Colors.gold)
                    Text("Rolling...")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(KingdomTheme.Colors.gold, lineWidth: 3)
                            )
                    }
                )
            } else {
                // Waiting for user to tap - BIG TAP BUTTON
                Button {
                    Task {
                        await viewModel.executeMasterRoll()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title2)
                        Text("TAP TO ROLL!")
                            .font(.system(size: 18, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.gold, foregroundColor: KingdomTheme.Colors.inkDark, fullWidth: true))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    private var actionButtonsRow: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Roll button - PHASE-COLORED
            Button {
                Task {
                    await viewModel.userTappedRollAgain()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: rollButtonIcon)
                        .font(.title2)
                    Text(rollButtonLabel)
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
            }
            .buttonStyle(.brutalist(
                backgroundColor: viewModel.canRoll ? rollButtonColor : KingdomTheme.Colors.disabled,
                foregroundColor: .white
            ))
            .disabled(!viewModel.canRoll)
            
            // Resolve/Master Roll button - GOLD for visibility
            Button {
                Task {
                    await viewModel.userTappedResolve()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: resolveButtonIcon)
                        .font(.title2)
                    Text(resolveButtonLabel)
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
            }
            .buttonStyle(.brutalist(
                backgroundColor: viewModel.canResolve ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled,
                foregroundColor: KingdomTheme.Colors.inkDark
            ))
            .disabled(!viewModel.canResolve)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    private var rollButtonLabel: String {
        switch phase {
        case .track: return "Scout"
        case .strike: return "Strike!"
        case .blessing: return "Pray"
        default: return "Roll"
        }
    }
    
    private var rollButtonIcon: String {
        switch phase {
        case .track: return "binoculars.fill"
        case .strike: return "bolt.fill"
        case .blessing: return "hands.sparkles.fill"
        default: return "dice.fill"
        }
    }
    
    private var rollButtonColor: Color {
        switch phase {
        case .track: return KingdomTheme.Colors.royalBlue
        case .strike: return KingdomTheme.Colors.buttonDanger
        case .blessing: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.buttonPrimary
        }
    }
    
    private var resolveButtonLabel: String {
        switch phase {
        case .track: return "Master Roll"
        case .strike: return "Finish Hunt"
        case .blessing: return "Claim Loot"
        default: return "Resolve"
        }
    }
    
    private var resolveButtonIcon: String {
        switch phase {
        case .track: return "target"
        case .strike: return "checkmark.circle.fill"
        case .blessing: return "gift.fill"
        default: return "checkmark"
        }
    }
}

// MARK: - Preview

#Preview {
    HuntPhaseView(viewModel: HuntViewModel(), phase: .track, showingIntro: true)
}
