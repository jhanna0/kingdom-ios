import SwiftUI

// MARK: - Hunt Phase View
// Shows the current phase with probability displays and roll results
// Multi-roll system: Roll multiple times, then Master Roll / Resolve

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
            
            // Master roll animation overlay
            if case .masterRollAnimation = viewModel.uiState {
                MasterRollAnimationOverlay(
                    viewModel: viewModel,
                    config: viewModel.config
                )
            }
            
            // Phase complete overlay
            if case .phaseComplete = viewModel.uiState {
                PhaseCompleteOverlay(
                    phaseResult: viewModel.currentPhaseResult,
                    hunt: viewModel.hunt,
                    onContinue: {
                        Task {
                            await viewModel.userTappedContinue()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Phase Content
    // STABLE LAYOUT: All sections have fixed heights, no jumping
    
    private var phaseContent: some View {
        VStack(spacing: 0) {
            // Top area - Phase-specific probability display
            probabilityDisplayArea
            
            Divider()
                .frame(height: 3)
                .background(Color.black)
            
            // Middle area - Phase info with roll result
            phaseInfoArea
            
            // Action buttons - ALWAYS present for stable layout
            // Visibility/enabled state controlled inside
            actionButtonsArea
            
            // Bottom area - Round results
            roundResultsArea
        }
    }
    
    // MARK: - Action Buttons Area
    // Fixed height area that's always present
    
    private var actionButtonsArea: some View {
        Group {
            switch viewModel.uiState {
            case .phaseActive, .rolling, .rollRevealing:
                multiRollActionButtons
            default:
                // Placeholder to maintain consistent height
                Color.clear
                    .frame(height: 84) // Same height as buttons area
            }
        }
    }
    
    // MARK: - Probability Display Area
    // UNIFIED: Every phase shows YOUR success chance + phase-specific goal
    
    private var probabilityDisplayArea: some View {
        VStack(spacing: 0) {
            // UNIVERSAL: Your success chance (same for ALL phases)
            SuccessChanceDisplay(
                statName: phase.statUsed,
                statValue: getStatValue(for: phase),
                rollsRemaining: viewModel.maxRolls - viewModel.rollsCompleted,
                maxRolls: viewModel.maxRolls
            )
            
            Divider()
                .frame(height: 2)
                .background(Color.black.opacity(0.3))
            
            // Phase-specific goal display
            phaseGoalDisplay
        }
        .frame(height: 220)
        .background(KingdomTheme.Colors.parchmentLight)
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
    
    @ViewBuilder
    private var phaseGoalDisplay: some View {
        // ALL phases use the same drop table bar!
            switch phase {
            case .track:
            DropTableBar(
                title: "CREATURE ODDS",
                slots: viewModel.dropTableSlots,
                displayConfig: .creatures(config: viewModel.config)
                )
            case .strike:
            VStack(spacing: 8) {
                // HP Bar (visual indicator of goal)
                CombatHPBar(
                    animal: viewModel.hunt?.animal,
                    animalHP: viewModel.hunt?.animal?.hp ?? 1
                )
                // Damage drop table (same system!)
                DropTableBar(
                    title: "DAMAGE ODDS",
                    slots: viewModel.dropTableSlots,
                    displayConfig: .damage
                )
            }
            case .blessing:
            DropTableBar(
                title: "LOOT BONUS ODDS",
                slots: viewModel.dropTableSlots,
                displayConfig: .blessing
                )
            default:
                EmptyView()
            }
    }
    
    // MARK: - Phase Info Area
    // Fixed height for stable layout
    
    private var phaseInfoArea: some View {
        VStack(spacing: 8) {
            // Current phase header
            HStack {
                Image(systemName: phase.icon)
                    .font(.title2)
                Text(phase.displayName)
                    .font(KingdomTheme.Typography.headline())
                
                Spacer()
                
                // Rolling indicator
                if case .rolling = viewModel.uiState {
                    ProgressView()
                        .tint(KingdomTheme.Colors.inkMedium)
                }
            }
            .foregroundColor(KingdomTheme.Colors.inkDark)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Result message area - fixed height to prevent jumping
            ZStack {
                // Last roll result message
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
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Placeholder when no result yet
                    Text("Tap to roll!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.6))
                }
            }
            .frame(height: 30)
            .animation(.spring(response: 0.3), value: viewModel.lastRollResult?.round)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(KingdomTheme.Colors.parchment)
    }
    
    // MARK: - Multi-Roll Action Buttons
    // FIXED LAYOUT: Buttons always in same position, uses Theme.swift styles
    
    private var multiRollActionButtons: some View {
        VStack(spacing: 0) {
            // Fixed height container ensures consistent layout
            HStack(spacing: KingdomTheme.Spacing.large) {
                // Roll button
                Button {
                    Task {
                        await viewModel.userTappedRollAgain()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "dice.fill")
                        Text(rollButtonLabel)
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: viewModel.canRoll ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled,
                    foregroundColor: .white
                ))
                .disabled(!viewModel.canRoll)
                
                // Resolve/Master Roll button
                // For Strike phase, this auto-resolves when HP=0, but user can still finish early
                Button {
                    Task {
                        await viewModel.userTappedResolve()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: resolveButtonIcon)
                        Text(resolveButtonLabel)
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: viewModel.canResolve ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled,
                    foregroundColor: KingdomTheme.Colors.inkDark
                ))
                .disabled(!viewModel.canResolve)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(KingdomTheme.Colors.parchment)
    }
    
    private var rollButtonLabel: String {
        switch phase {
        case .track: return "Scout"
        case .strike: return "Strike!"
        case .blessing: return "Pray"
        default: return "Roll"
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
    
    // MARK: - Round Results Area
    
    private var roundResultsArea: some View {
        VStack(spacing: 0) {
            Divider()
                .frame(height: 2)
                .background(Color.black)
            
            if viewModel.roundResults.isEmpty {
                Text("Tap a button above to roll!")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KingdomTheme.Spacing.medium) {
                        ForEach(viewModel.roundResults) { result in
                            RoundResultCard(result: result)
                    }
                }
                .padding()
            }
                .frame(height: 120)
        }
        }
        .background(KingdomTheme.Colors.parchmentDark)
    }
    
    private var isRollingState: Bool {
        switch viewModel.uiState {
        case .rolling, .rollRevealing, .resolving:
            return true
        default:
        return false
        }
    }
}

// MARK: - Round Result Card

struct RoundResultCard: View {
    let result: PhaseRoundResult
    
    var body: some View {
        VStack(spacing: 6) {
            Text("R\(result.round)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBackground)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(cardBorder, lineWidth: 2)
                    )
                
                VStack(spacing: 2) {
                    Text("\(result.roll)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(resultColor)
                    
                    if result.is_critical {
                        Text("⚡")
                            .font(.caption)
                    }
                }
            }
            
            Text(result.is_success ? "+\(String(format: "%.1f", result.contribution))" : "—")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(result.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
        }
    }
    
    private var cardBackground: Color {
        if result.is_critical && result.is_success {
            return KingdomTheme.Colors.gold.opacity(0.3)
        } else if result.is_success {
            return KingdomTheme.Colors.buttonSuccess.opacity(0.2)
        } else if result.is_critical {
            return KingdomTheme.Colors.buttonDanger.opacity(0.3)
        } else {
            return KingdomTheme.Colors.parchment
        }
    }
    
    private var cardBorder: Color {
        if result.is_critical {
            return result.is_success ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger
        }
        return Color.black
    }
    
    private var resultColor: Color {
        if result.is_critical && result.is_success {
            return KingdomTheme.Colors.gold
        } else if result.is_success {
            return KingdomTheme.Colors.buttonSuccess
        } else if result.is_critical {
            return KingdomTheme.Colors.buttonDanger
        } else {
        return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Universal Success Chance Display
// SAME for ALL phases - shows your stat and chance to succeed

struct SuccessChanceDisplay: View {
    let statName: String
    let statValue: Int
    let rollsRemaining: Int
    let maxRolls: Int
    
    // Calculate success chance based on stat (matches backend formula EXACTLY)
    // Backend: ROLL_BASE_CHANCE = 0.15, ROLL_SCALING_PER_LEVEL = 0.08
    // Formula: 15% + (8% * stat_level), clamped to 10%-95%
    private var successChance: Int {
        let base = 15 + (statValue * 8)
        return min(95, max(10, base))
    }
    
    private var statDisplayName: String {
        switch statName {
        case "intelligence": return "Intelligence"
        case "attack_power": return "Attack"
        case "faith": return "Faith"
        default: return statName.capitalized
        }
    }
    
    private var statIcon: String {
        switch statName {
        case "intelligence": return "brain.head.profile"
        case "attack_power": return "bolt.fill"
        case "faith": return "sparkles"
        default: return "star.fill"
        }
    }
    
    private var rollsUsed: Int {
        maxRolls - rollsRemaining
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Your stat
            VStack(spacing: 4) {
                Image(systemName: statIcon)
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(statDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("\(statValue)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .frame(width: 70)
            
            // Success chance - THE BIG NUMBER
            VStack(spacing: 4) {
                Text("HIT CHANCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                ZStack {
                    // Background bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 40)
                    
                    // Filled portion
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(chanceColor)
                            .frame(width: geo.size.width * CGFloat(successChance) / 100.0)
                    }
                    .frame(height: 40)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 2)
                        .frame(height: 40)
                    
                    // Percentage text
                    Text("\(successChance)%")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                }
                .frame(width: 130)
            }
            
            // Rolls remaining - compact display for any number of max rolls
            VStack(spacing: 4) {
                Text("ATTEMPTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Show as fraction instead of dots (scales to any number)
                Text("\(rollsUsed)/\(maxRolls)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(rollsRemaining <= 1 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkDark)
                
                Text(rollsRemaining == 1 ? "1 left" : "\(rollsRemaining) left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(rollsRemaining <= 1 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium)
            }
            .frame(width: 70)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
    
    private var chanceColor: Color {
        if successChance >= 65 { return KingdomTheme.Colors.buttonSuccess }
        if successChance >= 45 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonDanger
    }
}

// MARK: - Creature Odds Bar (Track phase goal)

// MARK: - Unified Drop Table Bar
// Same visual system for ALL phases!

enum DropTableDisplayConfig {
    case creatures(config: HuntConfigResponse?)
    case damage
    case blessing
}

struct DropTableBar: View {
    let title: String
    let slots: [String: Int]
    let displayConfig: DropTableDisplayConfig
    
    private var totalSlots: Int {
        slots.values.reduce(0, +)
    }
    
    private var orderedItems: [(key: String, slots: Int, display: DropTableItemDisplay)] {
        switch displayConfig {
        case .creatures(let config):
            let animals = (config?.animals ?? []).sorted { $0.tier < $1.tier }
            return animals.compactMap { animal in
                let slotCount = slots[animal.id] ?? 0
                return (animal.id, slotCount, DropTableItemDisplay(
                    icon: animal.icon,
                    name: animal.name,
                    color: creatureTierColor(animal.tier)
                ))
            }
        case .damage:
            return [
                ("miss", slots["miss"] ?? 0, DropTableItemDisplay(icon: "💨", name: "Miss", color: Color.gray.opacity(0.6))),
                ("graze", slots["graze"] ?? 0, DropTableItemDisplay(icon: "🩹", name: "Graze", color: Color.orange.opacity(0.7))),
                ("hit", slots["hit"] ?? 0, DropTableItemDisplay(icon: "⚔️", name: "Hit", color: Color.green.opacity(0.7))),
                ("crit", slots["crit"] ?? 0, DropTableItemDisplay(icon: "💥", name: "Crit!", color: Color.red.opacity(0.8))),
            ]
        case .blessing:
            return [
                ("none", slots["none"] ?? 0, DropTableItemDisplay(icon: "😶", name: "None", color: Color.gray.opacity(0.6))),
                ("small", slots["small"] ?? 0, DropTableItemDisplay(icon: "✨", name: "+10%", color: Color.blue.opacity(0.6))),
                ("medium", slots["medium"] ?? 0, DropTableItemDisplay(icon: "🌟", name: "+25%", color: Color.purple.opacity(0.7))),
                ("large", slots["large"] ?? 0, DropTableItemDisplay(icon: "⚡", name: "+50%", color: Color.yellow.opacity(0.8))),
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Horizontal bar with segments
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(orderedItems, id: \.key) { item in
                        let fraction = totalSlots > 0 ? CGFloat(item.slots) / CGFloat(totalSlots) : 0
                        if fraction > 0.01 {
                            DropTableSegment(display: item.display, fraction: fraction)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 3)
                )
            }
            .frame(height: 50)
            .padding(.horizontal, 16)
            
            // Legend
            HStack(spacing: 6) {
                ForEach(orderedItems, id: \.key) { item in
                    let percent = totalSlots > 0 ? Int(Double(item.slots) / Double(totalSlots) * 100) : 0
                    HStack(spacing: 2) {
                        Text(item.display.icon)
                            .font(.system(size: 14))
                            .opacity(percent > 0 ? 1 : 0.3)
                        Text("\(percent)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(percent > 0 ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium.opacity(0.4))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func creatureTierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return KingdomTheme.Colors.inkMedium.opacity(0.6)
        case 1: return KingdomTheme.Colors.buttonSuccess.opacity(0.7)
        case 2: return KingdomTheme.Colors.buttonWarning.opacity(0.7)
        case 3: return KingdomTheme.Colors.buttonDanger.opacity(0.7)
        case 4: return KingdomTheme.Colors.regalPurple.opacity(0.7)
        default: return KingdomTheme.Colors.inkMedium.opacity(0.6)
        }
    }
}

struct DropTableItemDisplay {
    let icon: String
    let name: String
    let color: Color
}

struct DropTableSegment: View {
    let display: DropTableItemDisplay
    let fraction: CGFloat
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(display.color)
            
            if fraction > 0.15 {
                Text(display.icon)
                    .font(.system(size: fraction > 0.3 ? 28 : 20))
            }
        }
    }
}

// MARK: - Combat HP Bar (visual only)

struct CombatHPBar: View {
    let animal: HuntAnimal?
    let animalHP: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text(animal?.icon ?? "🎯")
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("\(animal?.name ?? "Prey") HP: \(animalHP)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Text("Damage is rolled when combat resolves!")
                    .font(.system(size: 10))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Combat Goal Display (Strike phase goal)

struct CombatGoalDisplay: View {
    let animal: HuntAnimal?
    let damageDealt: Int
    let animalHP: Int
    
    private var remainingHP: Int {
        max(0, animalHP - damageDealt)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Animal
            VStack(spacing: 4) {
                Text(animal?.icon ?? "🎯")
                    .font(.system(size: 44))
                    .scaleEffect(damageDealt > 0 ? 0.95 : 1.0)
                    .animation(.spring(response: 0.2), value: damageDealt)
                    Text(animal?.name ?? "Prey")
                    .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
            }
                    
            // HP Bar
            VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(hpColor)
                    Text("HP: \(remainingHP)/\(animalHP)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(hpColor)
                                .contentTransition(.numericText())
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.2))
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(hpColor)
                            .frame(width: geo.size.width * CGFloat(remainingHP) / CGFloat(max(1, animalHP)))
                            .animation(.spring(response: 0.3), value: remainingHP)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                        }
                .frame(height: 24)
                .frame(width: 180)
                
                // Damage dealt
                HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("Damage: \(damageDealt)")
                        .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            
            if remainingHP <= 0 {
                Text("SLAIN!")
                    .font(.system(size: 20, weight: .black))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    .transition(.scale)
            }
        }
        .padding(.vertical, 12)
    }
    
    private var hpColor: Color {
        let ratio = Double(remainingHP) / Double(max(1, animalHP))
        if ratio <= 0.3 { return KingdomTheme.Colors.buttonDanger }
        if ratio <= 0.6 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonSuccess
    }
}

// MARK: - Loot Bonus Display (Blessing phase goal)

struct LootBonusDisplay: View {
    let bonus: Double
    
    var body: some View {
        HStack(spacing: 24) {
            // Divine sparkle
                Image(systemName: "sparkles")
                .font(.system(size: 40))
                    .foregroundColor(KingdomTheme.Colors.regalPurple)
                .symbolEffect(.pulse.byLayer, options: .repeating, value: bonus)
            
            // Bonus percentage
            VStack(spacing: 4) {
                Text("LOOT BONUS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("+\(Int(bonus * 100))%")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.regalPurple)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: bonus)
            }
            
            // Visual indicator
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) * 0.1 < bonus ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundColor(Double(i) * 0.1 < bonus ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium.opacity(0.3))
                    }
                }
                Text("Drop chance boost")
                    .font(.system(size: 10))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.vertical, 12)
    }
}


// MARK: - Player Roll Card

struct PlayerRollCard: View {
    let participant: HuntParticipant
    let rollResult: RollResult?
    let isRevealed: Bool
    let isRolling: Bool
    
    @State private var diceRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Text(participant.player_name)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardBorder, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                
                if isRolling {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 36))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .rotationEffect(.degrees(diceRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                                diceRotation = 360
                            }
                        }
                } else if isRevealed, let roll = rollResult {
                    VStack(spacing: 2) {
                        Text("\(roll.rollPercentage)")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(resultColor(roll))
                        
                        Text(roll.outcome.displayName)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(resultColor(roll))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("?")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.3))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isRevealed)
            
            if isRevealed, let roll = rollResult {
                Text(roll.is_success ? "+\(String(format: "%.1f", roll.contribution))" : "—")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(roll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
            }
        }
        .frame(width: 100)
    }
    
    private var cardBackground: Color {
        guard isRevealed, let roll = rollResult else { return KingdomTheme.Colors.parchment }
        if roll.is_critical && roll.is_success {
            return KingdomTheme.Colors.gold.opacity(0.3)
        } else if roll.is_success {
            return KingdomTheme.Colors.buttonSuccess.opacity(0.2)
        } else if roll.is_critical {
            return KingdomTheme.Colors.buttonDanger.opacity(0.3)
        } else {
            return KingdomTheme.Colors.parchment
        }
    }
    
    private var cardBorder: Color {
        guard isRevealed, let roll = rollResult else { return Color.black }
        if roll.is_critical {
            return roll.is_success ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger
        }
        return Color.black
    }
    
    private func resultColor(_ roll: RollResult) -> Color {
        switch roll.outcome {
        case .criticalSuccess: return KingdomTheme.Colors.gold
        case .success: return KingdomTheme.Colors.buttonSuccess
        case .failure: return KingdomTheme.Colors.inkMedium
        case .criticalFailure: return KingdomTheme.Colors.buttonDanger
        }
    }
}

// MARK: - Master Roll Animation Overlay
// Works for ALL phases: Track (creatures), Strike (damage), Blessing (loot)

struct MasterRollAnimationOverlay: View {
    @ObservedObject var viewModel: HuntViewModel
    let config: HuntConfigResponse?
    
    private var currentPhase: HuntPhase {
        if case .masterRollAnimation(let phase) = viewModel.uiState {
            return phase
        }
        return .track
    }
    
    private var title: String {
        switch currentPhase {
        case .track: return "MASTER ROLL"
        case .strike: return "DAMAGE ROLL"
        case .blessing: return "LOOT ROLL"
        default: return "FINAL ROLL"
        }
    }
    
    private var segments: [(key: String, probability: Double, icon: String, color: Color)] {
        switch currentPhase {
        case .track:
            let animals = (config?.animals ?? []).sorted { $0.tier < $1.tier }
            return animals.compactMap { animal in
                let prob = viewModel.dropTableOdds[animal.id] ?? 0
                guard prob > 0 else { return nil }
                return (animal.id, prob, animal.icon, tierColor(animal.tier))
            }
        case .strike:
            return strikeSegments
        case .blessing:
            return blessingSegments
        default:
            return []
        }
    }
    
    private var strikeSegments: [(key: String, probability: Double, icon: String, color: Color)] {
        let odds = viewModel.dropTableOdds
        var result: [(key: String, probability: Double, icon: String, color: Color)] = []
        if let p = odds["miss"], p > 0 { result.append(("miss", p, "💨", Color.gray)) }
        if let p = odds["graze"], p > 0 { result.append(("graze", p, "🩹", Color.orange)) }
        if let p = odds["hit"], p > 0 { result.append(("hit", p, "⚔️", KingdomTheme.Colors.buttonSuccess)) }
        if let p = odds["crit"], p > 0 { result.append(("crit", p, "💥", KingdomTheme.Colors.buttonDanger)) }
        return result
    }
    
    private var blessingSegments: [(key: String, probability: Double, icon: String, color: Color)] {
        let odds = viewModel.dropTableOdds
        var result: [(key: String, probability: Double, icon: String, color: Color)] = []
        if let p = odds["none"], p > 0 { result.append(("none", p, "😶", Color.gray)) }
        if let p = odds["small"], p > 0 { result.append(("small", p, "✨", Color.blue)) }
        if let p = odds["medium"], p > 0 { result.append(("medium", p, "🌟", KingdomTheme.Colors.regalPurple)) }
        if let p = odds["large"], p > 0 { result.append(("large", p, "⚡", KingdomTheme.Colors.gold)) }
        return result
    }
    
    var body: some View {
        ZStack {
            // Dark backdrop
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                Spacer()
                
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .tracking(4)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                // The probability bar with sliding marker
                GeometryReader { geo in
                    ZStack {
                        // Background bar
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(KingdomTheme.Colors.gold, lineWidth: 4)
                            )
                        
                        // Segments
                        HStack(spacing: 0) {
                            ForEach(segments, id: \.key) { segment in
                                Rectangle()
                                    .fill(segment.color.opacity(0.8))
                                    .frame(width: geo.size.width * CGFloat(segment.probability))
                                    .overlay(
                                        Text(segment.icon)
                                            .font(.system(size: segment.probability > 0.2 ? 40 : 24))
                                            .opacity(segment.probability > 0.1 ? 1 : 0)
                                    )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // The sliding marker
                        let markerX = geo.size.width * CGFloat(viewModel.masterRollValue) / 100.0
                        
                        VStack(spacing: 0) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 24))
                                .foregroundColor(KingdomTheme.Colors.gold)
                                .shadow(color: .black, radius: 2, x: 0, y: 2)
                            
                            Rectangle()
                                .fill(KingdomTheme.Colors.gold)
                                .frame(width: 4, height: geo.size.height + 10)
                                .shadow(color: .black, radius: 3)
                        }
                        .offset(x: markerX - geo.size.width / 2)
                        .animation(viewModel.masterRollAnimating ? .linear(duration: 0.03) : .spring(response: 0.5, dampingFraction: 0.6), value: viewModel.masterRollValue)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 20)
                
                // Icons below the bar
                HStack(spacing: 4) {
                    ForEach(segments, id: \.key) { segment in
                        Text(segment.icon)
                            .font(.system(size: 36))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                
                // Roll value display
                Text("\(viewModel.masterRollValue)")
                    .font(.system(size: 60, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2), value: viewModel.masterRollValue)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
                
                Spacer()
            }
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return KingdomTheme.Colors.inkMedium
        case 1: return KingdomTheme.Colors.buttonSuccess
        case 2: return KingdomTheme.Colors.buttonWarning
        case 3: return KingdomTheme.Colors.buttonDanger
        case 4: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}


// MARK: - Phase Intro Overlay

struct PhaseIntroOverlay: View {
    let phase: HuntPhase
    let config: HuntConfigResponse?
    let onBegin: () -> Void
    
    @State private var iconScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack {
                decorativeBorder
                Spacer()
                decorativeBorder
            }
            .ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xxLarge) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [phaseColor.opacity(0.4), phaseColor.opacity(0.0)],
                                center: .center,
                                startRadius: 40,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .fill(phaseColor.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(phaseColor, lineWidth: 4)
                        )
                    
                    Image(systemName: phase.icon)
                        .font(.system(size: 70, weight: .medium))
                        .foregroundColor(phaseColor)
                        .symbolEffect(.bounce, options: .repeating.speed(0.5))
                }
                .scaleEffect(iconScale)
                
                VStack(spacing: 8) {
                    Text(phase.displayName.uppercased())
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .tracking(4)
                    
                    Text(phaseDescription)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(textOpacity)
                
                if phase == .track, let animals = config?.animals {
                    possibleCreaturesPreview(animals: animals)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                Button {
                    onBegin()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("BEGIN")
                            .font(.system(size: 22, weight: .black))
                            .tracking(2)
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.gold, foregroundColor: KingdomTheme.Colors.inkDark))
                .opacity(buttonOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    @ViewBuilder
    private func possibleCreaturesPreview(animals: [HuntAnimalConfig]) -> some View {
        VStack(spacing: 8) {
            Text("Possible Finds:")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 12) {
                ForEach(animals.sorted { $0.tier < $1.tier }, id: \.id) { animal in
                    Text(animal.icon)
                        .font(.system(size: 28))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchment.opacity(0.5))
        )
    }
    
    private var phaseColor: Color {
        switch phase {
        case .track: return KingdomTheme.Colors.royalBlue
        case .strike: return KingdomTheme.Colors.buttonDanger
        case .blessing: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var phaseDescription: String {
        switch phase {
        case .track: return "Use your Intelligence to find animal tracks"
        case .strike: return "Use your Attack to land the killing blow"
        case .blessing: return "Use your Faith to bless the loot"
        default: return ""
        }
    }
    
    private var decorativeBorder: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundColor(KingdomTheme.Colors.border.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Phase Complete Overlay

struct PhaseCompleteOverlay: View {
    let phaseResult: PhaseResultData?
    let hunt: HuntSession?
    let onContinue: () -> Void
    
    @State private var resultScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    private var isHuntComplete: Bool {
        hunt?.isComplete == true || phaseResult?.huntPhase == .blessing
    }
    
    private var isSuccess: Bool {
        // Check if hunt succeeded (animal killed or blessing complete)
        if let effects = phaseResult?.effects {
            if effects["killed"]?.boolValue == true { return true }
            if effects["escaped"]?.boolValue == true { return false }
            if effects["no_trail"]?.boolValue == true { return false }
        }
        return phaseResult?.group_roll.success_rate ?? 0 >= 0.5
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(resultColor.opacity(0.15))
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(resultColor.opacity(0.4), lineWidth: 4)
                        )
                    
                    Image(systemName: resultIcon)
                        .font(.system(size: 70))
                        .foregroundColor(resultColor)
                }
                .scaleEffect(resultScale)
                
                VStack(spacing: 12) {
                    // Clear headline for hunt completion
                    if isHuntComplete {
                        Text(isSuccess ? "HUNT COMPLETE!" : "HUNT OVER")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(2)
                            .foregroundColor(resultColor)
                    }
                    
                    Text(phaseResult?.outcome_message ?? "Phase Complete")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let effects = phaseResult?.effects {
                        effectsBadges(effects)
                    }
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Clear call-to-action button
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 12) {
                        if isHuntComplete {
                            Image(systemName: "trophy.fill")
                            Text("VIEW REWARDS")
                        } else {
                            Text("NEXT PHASE")
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.gold, foregroundColor: KingdomTheme.Colors.inkDark))
                .opacity(buttonOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                resultScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                contentOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    @ViewBuilder
    private func effectsBadges(_ effects: [String: AnyCodableValue]) -> some View {
        HStack(spacing: 12) {
            if effects["killed"]?.boolValue == true {
                effectBadge(icon: "target", text: "Slain!", color: KingdomTheme.Colors.buttonSuccess)
            }
            if effects["escaped"]?.boolValue == true {
                effectBadge(icon: "figure.run", text: "Escaped", color: KingdomTheme.Colors.buttonDanger)
            }
            if effects["no_trail"]?.boolValue == true {
                effectBadge(icon: "questionmark.circle", text: "No Trail", color: KingdomTheme.Colors.inkMedium)
            }
        }
    }
    
    private func effectBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(FontStyles.labelMedium)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color)
                .overlay(
                    Capsule()
                        .stroke(Color.black, lineWidth: 2)
                )
        )
    }
    
    private var backgroundColor: Color {
        isSuccess ? KingdomTheme.Colors.parchmentLight : KingdomTheme.Colors.parchmentDark
    }
    
    private var resultColor: Color {
        isSuccess ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private var resultIcon: String {
        if isHuntComplete {
            return isSuccess ? "trophy.fill" : "xmark.circle.fill"
        }
        return isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}

// MARK: - Preview

#Preview {
    HuntPhaseView(viewModel: HuntViewModel(), phase: .track, showingIntro: true)
}
