import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hunt Phase View

struct HuntPhaseView: View {
    @ObservedObject var viewModel: HuntViewModel
    let phase: HuntPhase
    let showingIntro: Bool
    
    // Inline master roll animation state
    @State private var masterRollDisplayValue: Int = 0
    @State private var showMasterRollMarker: Bool = false
    @State private var masterRollAnimationStarted: Bool = false
    @State private var lastRollResultId: Int? = nil
    
    private var displayConfig: PhaseDisplayConfig? {
        viewModel.hunt?.phase_state?.display
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            if !showingIntro {
                mainContent
            }
            
            if showingIntro {
                PhaseIntroOverlay(
                    phase: phase,
                    config: viewModel.config,
                    hunt: viewModel.hunt,
                    onBegin: {
                        Task { await viewModel.userTappedBeginPhase() }
                    }
                )
            }
        }
        .onChange(of: viewModel.lastRollResult?.round) { _, newRound in
            guard let newRound = newRound, newRound != lastRollResultId else { return }
            lastRollResultId = newRound
            handleRollResult()
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    headerRow
                    hudChips
                    arenaCard
                    rollResultCard
                    rollHistoryCard
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.top, KingdomTheme.Spacing.medium)
                .padding(.bottom, KingdomTheme.Spacing.large)
            }
            
            bottomButtons
        }
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Phase name
                HStack(spacing: KingdomTheme.Spacing.small) {
                    Image(systemName: displayConfig?.phase_icon ?? phase.icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(phaseColor)
                    
                    Text(displayConfig?.phase_name.uppercased() ?? phase.displayName.uppercased())
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
            }
            
            Text("Rolls have chance to give better odds. Higher skill gives more rolls.")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - HUD Chips (3 equal width)
    
    private var hudChips: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            // Stat chip - uses SkillConfig for proper icon!
            hudChip(
                label: abbreviate(skillConfig.displayName),
                value: "\(displayConfig?.stat_value ?? 0)",
                icon: skillConfig.icon,
                tint: skillConfig.color
            )
            
            // Hit chance chip
            hudChip(
                label: "HIT",
                value: "\(displayConfig?.hit_chance ?? 0)%",
                icon: "scope",
                tint: hitTint
            )
            
            // Attempts chip
            attemptsChip
        }
    }
    
    private func hudChip(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 10,
            shadowOffset: 2,
            borderWidth: 2
        )
    }
    
    private var attemptsChip: some View {
        let remaining = max(0, viewModel.maxRolls - viewModel.rollsCompleted)
        return HStack(spacing: 8) {
            Image(systemName: "dice.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(KingdomTheme.Colors.inkDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("LEFT")
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                HStack(spacing: 3) {
                    ForEach(0..<viewModel.maxRolls, id: \.self) { i in
                        Circle()
                            .fill(i < remaining ? KingdomTheme.Colors.buttonSuccess : Color.black.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 10,
            shadowOffset: 2,
            borderWidth: 2
        )
    }
    
    // MARK: - Arena Card
    
    /// Only show animal after track phase is done (strike/blessing phase, or after master roll complete)
    private var shouldShowAnimal: Bool {
        guard viewModel.hunt?.animal != nil else { return false }
        // Show animal in strike or blessing phase, or after master roll in track
        return phase == .strike || phase == .blessing || 
               (phase == .track && viewModel.uiState == .masterRollComplete(.track))
    }
    
    private var arenaCard: some View {
        ZStack {
            LinearGradient(
                colors: [KingdomTheme.Colors.parchmentRich, KingdomTheme.Colors.parchmentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack {
                HStack {
                    nameplate(title: "YOU", subtitle: nil)
                    Spacer()
                    nameplate(title: enemyTitle, subtitle: enemySubtitle)
                }
                .padding(12)
                
                Spacer()
                
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    // Animal (only after track resolves) or phase icon
                    if shouldShowAnimal, let animal = viewModel.hunt?.animal, let icon = animal.icon, !icon.isEmpty {
                        VStack(spacing: 6) {
                            Text(icon).font(.system(size: 55))
                            // Potential drops with names
                            if let drops = animal.potential_drops, !drops.isEmpty {
                                VStack(spacing: 2) {
                                    ForEach(drops.prefix(2)) { drop in
                                        HStack(spacing: 3) {
                                            Image(systemName: drop.item_icon)
                                                .font(.system(size: 9))
                                            Text(drop.item_name)
                                                .font(.system(size: 9, weight: .medium))
                                        }
                                        .foregroundColor(dropColor(drop.item_color))
                                    }
                                }
                            }
                        }
                    } else {
                        // Bush for track phase, SF Symbol for others
                        if phase == .track {
                            BrutalistBush()
                                .opacity(0.7)
                        } else {
                            Image(systemName: displayConfig?.phase_icon ?? phase.icon)
                                .font(.system(size: 50, weight: .black))
                                .foregroundColor(phaseColor)
                                .opacity(0.4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium))
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    private func dropColor(_ colorName: String?) -> Color {
        guard let name = colorName?.lowercased() else { return .gray }
        switch name {
        case "orange": return .orange
        case "brown": return .brown
        case "purple": return KingdomTheme.Colors.regalPurple
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
    
    private func nameplate(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 8,
            shadowOffset: 2,
            borderWidth: 2
        )
    }
    
    private var enemyTitle: String {
        // Only show animal name after animation completes
        if shouldShowAnimal, let name = viewModel.hunt?.animal?.name {
            return name
        }
        switch phase {
        case .track: return "WILDERNESS"
        case .blessing: return "ALTAR"
        default: return "ENCOUNTER"
        }
    }
    
    private var enemySubtitle: String? {
        // Only show animal stats after animation completes
        if shouldShowAnimal, let animal = viewModel.hunt?.animal {
            if phase == .strike, let hp = animal.hp {
                return "HP \(viewModel.currentAnimalHP)/\(hp)"
            } else if let hp = animal.hp, let meat = animal.meat {
                return "\(hp) HP · \(meat) Meat"
            }
        }
        switch phase {
        case .track: return "Find prey"
        case .blessing: return "Seek fortune"
        default: return nil
        }
    }
    
    // MARK: - Roll Result Card
    
    /// Whether the master roll animation is actively running
    private var isMasterRollAnimating: Bool {
        viewModel.shouldAnimateMasterRoll && showMasterRollMarker
    }
    
    /// The value to display for master roll - animates during animation, final value after
    private var displayedMasterRollValue: Int {
        if isMasterRollAnimating {
            return masterRollDisplayValue
        }
        return viewModel.masterRollFinalValue
    }
    
    /// Returns the color of the drop table segment that the given roll value lands in
    private var masterRollColor: Color {
        let items = displayConfig?.drop_table_items ?? []
        let slots = viewModel.dropTableSlots
        let total = slots.values.reduce(0, +)
        
        guard total > 0 else { return phaseColor }
        
        let rollValue = displayedMasterRollValue
        var cumulative = 0
        
        for item in items {
            let count = slots[item.key] ?? 0
            cumulative += count
            let threshold = (cumulative * 100) / total
            
            if rollValue <= threshold {
                return Color(hex: item.color) ?? phaseColor
            }
        }
        
        // Fallback to last item's color or phase color
        if let lastItem = items.last {
            return Color(hex: lastItem.color) ?? phaseColor
        }
        return phaseColor
    }
    
    private var rollResultCard: some View {
        VStack(spacing: 10) {
            // Result or prompt
            ZStack {
                if viewModel.shouldAnimateMasterRoll || viewModel.masterRollFinalValue > 0 {
                    resultRow(
                        badge: displayConfig?.resolve_button_label.uppercased() ?? "RESULT",
                        message: isMasterRollAnimating ? "Rolling…" : "Locked in",
                        value: "\(displayedMasterRollValue)",
                        tint: phaseColor,
                        valueColor: masterRollColor
                    )
                } else if let roll = viewModel.lastRollResult {
                    resultRow(
                        badge: roll.is_critical ? "CRITICAL" : (roll.is_success ? "SUCCESS" : "MISS"),
                        message: roll.message,
                        value: "\(roll.roll)",
                        tint: roll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
                    )
                } else {
                    promptRow
                }
            }
            .frame(height: 50)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.lastRollResult?.round)
            
            // Inline master roll bar
            masterRollBar
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    // MARK: - Inline Master Roll Bar
    
    private var masterRollBar: some View {
        let items = displayConfig?.drop_table_items ?? []
        let slots = viewModel.dropTableSlots
        let total = slots.values.reduce(0, +)
        let markerIcon = displayConfig?.master_roll_icon ?? "scope"
        
        return VStack(spacing: 4) {
            Text(isMasterRollAnimating ? "ROLLING" : (showMasterRollMarker ? "RESULT" : "ODDS"))
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 0) {
                        ForEach(items, id: \.key) { item in
                            let count = slots[item.key] ?? 0
                            let frac = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                            if frac > 0.01 {
                                Rectangle()
                                    .fill(Color(hex: item.color) ?? KingdomTheme.Colors.inkMedium)
                                    .frame(width: geo.size.width * frac)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                    
                    if showMasterRollMarker {
                        let markerX = geo.size.width * CGFloat(max(1, masterRollDisplayValue)) / 100.0
                        Image(systemName: markerIcon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                            .position(x: markerX, y: 10)
                    }
                }
            }
            .frame(height: 20)
        }
        .onAppear {
            // Backup: if animation should be running but hasn't started, start it
            if viewModel.shouldAnimateMasterRoll && !masterRollAnimationStarted {
                masterRollAnimationStarted = true
                Task { await runMasterRollAnimation() }
            }
            // If resuming with a completed master roll, show the marker at final position
            else if viewModel.masterRollFinalValue > 0 && !viewModel.shouldAnimateMasterRoll {
                showMasterRollMarker = true
                masterRollDisplayValue = viewModel.masterRollFinalValue
            }
        }
        .onChange(of: viewModel.shouldAnimateMasterRoll) { _, shouldAnimate in
            if shouldAnimate && !masterRollAnimationStarted {
                masterRollAnimationStarted = true
                Task { await runMasterRollAnimation() }
            } else if !shouldAnimate {
                // Reset when animation flag is cleared
                masterRollAnimationStarted = false
            }
        }
        .onChange(of: viewModel.masterRollFinalValue) { _, newValue in
            if newValue == 0 {
                showMasterRollMarker = false
                masterRollDisplayValue = 0
                masterRollAnimationStarted = false
            }
        }
        .onChange(of: phase) { _, _ in
            // Reset animation state when phase changes
            showMasterRollMarker = false
            masterRollDisplayValue = 0
            masterRollAnimationStarted = false
        }
    }
    
    @MainActor
    private func runMasterRollAnimation() async {
        let finalValue = viewModel.masterRollFinalValue
        
        var positions = Array(stride(from: 1, through: 100, by: 2))
        if finalValue < 100 {
            positions.append(contentsOf: stride(from: 98, through: max(1, finalValue), by: -2))
        }
        if positions.last != finalValue {
            positions.append(finalValue)
        }
        
        showMasterRollMarker = true
        
        for pos in positions {
            masterRollDisplayValue = pos
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        
        masterRollDisplayValue = finalValue
        
        // Haptic when result lands
        HapticService.shared.success()
        HapticService.shared.heavyImpact()
        
        viewModel.finishMasterRollAnimation()
    }
    
    private var promptRow: some View {
        HStack {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(phaseColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("What will you do?")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text("Tap Roll to act")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
    }
    
    private func resultRow(badge: String, message: String, value: String, tint: Color, valueColor: Color? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(badge)
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .lineLimit(1)
            }

            Spacer()

            Text(value)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(valueColor ?? KingdomTheme.Colors.inkDark)
        }
    }
    
    /// Get the resolve button tint - uses phase color instead of always purple
    private var resolveButtonTint: Color {
        phaseColor
    }
    
    // MARK: - Roll History Card
    
    private var rollHistoryCard: some View {
        ZStack {
            if viewModel.roundResults.isEmpty {
                Text("No rolls yet")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.roundResults) { result in
                            RoundResultCard(result: result)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            bottomButtonContent
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    @ViewBuilder
    private var bottomButtonContent: some View {
        switch viewModel.uiState {
        case .phaseActive, .rolling, .rollRevealing:
            twoButtonRow
        case .resolving, .masterRollAnimation:
            loadingRow
        case .masterRollComplete:
            continueButton
        default:
            Color.clear.frame(height: 50)
        }
    }
    
    private var twoButtonRow: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Button {
                Task { await viewModel.userTappedRollAgain() }
            } label: {
                HStack {
                    Image(systemName: displayConfig?.roll_button_icon ?? "dice.fill")
                    Text(displayConfig?.roll_button_label ?? "Roll")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(
                backgroundColor: viewModel.canRoll ? phaseColor.opacity(0.7) : KingdomTheme.Colors.disabled,
                foregroundColor: .white,
                fullWidth: true
            ))
            .disabled(!viewModel.canRoll)
            
            Button {
                Task { await viewModel.userTappedResolve() }
            } label: {
                HStack {
                    Image(systemName: displayConfig?.resolve_button_icon ?? "checkmark")
                    Text(displayConfig?.resolve_button_label ?? "Resolve")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(
                backgroundColor: viewModel.canResolve ? phaseColor : KingdomTheme.Colors.disabled,
                foregroundColor: .white,
                fullWidth: true
            ))
            .disabled(!viewModel.canResolve)
        }
    }
    
    private var loadingRow: some View {
        HStack {
            ProgressView().tint(phaseColor)
            Text(displayConfig?.resolve_button_label ?? "Resolving...")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KingdomTheme.Spacing.medium)
    }
    
    private var continueButton: some View {
        Button {
            Task { await viewModel.userTappedNextAfterMasterRoll() }
        } label: {
            HStack {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, foregroundColor: .white, fullWidth: true))
    }
    
    // MARK: - Helpers
    
    /// Get skill config using SkillConfig single source of truth
    /// Maps backend stat names to SkillConfig keys (e.g. "attack_power" → "attack")
    private var skillConfig: SkillConfig {
        let statName = displayConfig?.stat_name ?? ""
        // Backend uses "attack_power" but SkillConfig uses "attack"
        let mappedName = statName == "attack_power" ? "attack" : statName
        return SkillConfig.get(mappedName)
    }
    
    private var phaseColor: Color {
        guard let name = displayConfig?.phase_color else { return KingdomTheme.Colors.buttonPrimary }
        switch name {
        case "royalBlue": return KingdomTheme.Colors.royalBlue
        case "buttonDanger": return KingdomTheme.Colors.buttonDanger
        case "regalPurple": return KingdomTheme.Colors.regalPurple
        case "buttonSuccess": return KingdomTheme.Colors.buttonSuccess
        case "buttonWarning": return KingdomTheme.Colors.buttonWarning
        case "gold": return KingdomTheme.Colors.gold
        default: return KingdomTheme.Colors.buttonPrimary
        }
    }
    
    private var hitTint: Color {
        let v = displayConfig?.hit_chance ?? 0
        if v >= 65 { return KingdomTheme.Colors.buttonSuccess }
        if v >= 45 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonDanger
    }
    
    private func abbreviate(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "STAT" }
        let parts = t.split(separator: " ")
        if parts.count > 1 {
            return String(parts.compactMap { $0.first }.prefix(3)).uppercased()
        }
        return String(t.prefix(3)).uppercased()
    }
    
    // MARK: - Haptics
    
    private func handleRollResult() {
        guard let roll = viewModel.lastRollResult else { return }
        
        if roll.is_critical && roll.is_success {
            HapticService.shared.success()
            HapticService.shared.heavyImpact()
        } else if roll.is_success {
            HapticService.shared.mediumImpact()
        }
    }
}

// MARK: - Brutalist Bush

private struct BrutalistBush: View {
    var body: some View {
        ZStack {
            // Shadow layer
            bushShape
                .fill(Color.black)
                .offset(x: 3, y: 3)
            
            // Main bush
            bushShape
                .fill(KingdomTheme.Colors.buttonSuccess.opacity(0.6))
                .overlay(
                    bushShape
                        .stroke(Color.black, lineWidth: 2.5)
                )
        }
        .frame(width: 70, height: 55)
    }
    
    private var bushShape: some Shape {
        BushPath()
    }
}

private struct BushPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Three overlapping bumps to form a bush
        // Left bump
        path.addEllipse(in: CGRect(x: 0, y: h * 0.2, width: w * 0.5, height: h * 0.8))
        // Right bump
        path.addEllipse(in: CGRect(x: w * 0.5, y: h * 0.2, width: w * 0.5, height: h * 0.8))
        // Top center bump
        path.addEllipse(in: CGRect(x: w * 0.2, y: 0, width: w * 0.6, height: h * 0.7))
        
        return path
    }
}

#Preview {
    HuntPhaseView(viewModel: HuntViewModel(), phase: .track, showingIntro: true)
}
