import SwiftUI

// MARK: - Hunt Phase View

struct HuntPhaseView: View {
    @ObservedObject var viewModel: HuntViewModel
    let phase: HuntPhase
    let showingIntro: Bool
    
    @State private var isShowingIntelSheet = false
    
    private var displayConfig: PhaseDisplayConfig? {
        viewModel.hunt?.phase_state?.display
    }
    
    private var isShowingMasterRoll: Bool {
        if case .resolving = viewModel.uiState { return true }
        if case .masterRollAnimation = viewModel.uiState { return true }
        return false
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
                    onBegin: {
                        Task { await viewModel.userTappedBeginPhase() }
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingIntelSheet) {
            intelSheet
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
                
                // Intel button
                Button { isShowingIntelSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "scope")
                            .font(.system(size: 12, weight: .bold))
                        Text("Intel")
                            .font(.system(size: 12, weight: .bold, design: .serif))
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            }
            
            Text("Rolls have chance to give better odds. Higher skill gives more rolls.")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - HUD Chips (3 equal width)
    
    private var hudChips: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            // Stat chip
            hudChip(
                label: abbreviate(displayConfig?.stat_display_name ?? "STAT"),
                value: "\(displayConfig?.stat_value ?? 0)",
                icon: displayConfig?.stat_icon ?? "star.fill",
                tint: phaseColor
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
    
    private var arenaCard: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [KingdomTheme.Colors.parchmentRich, KingdomTheme.Colors.parchmentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack {
                // Nameplates at top
                HStack {
                    nameplate(title: "YOU", subtitle: nil)
                    Spacer()
                    nameplate(title: enemyTitle, subtitle: enemySubtitle)
                }
                .padding(12)
                
                Spacer()
                
                // Sprites at bottom
                HStack {
                    // Player
                    Image(systemName: "person.fill")
                        .font(.system(size: 50, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    // Enemy
                    if phase == .strike, let icon = viewModel.hunt?.animal?.icon, !icon.isEmpty {
                        Text(icon).font(.system(size: 70))
                    } else {
                        Image(systemName: displayConfig?.phase_icon ?? phase.icon)
                            .font(.system(size: 50, weight: .black))
                            .foregroundColor(phaseColor)
                            .opacity(0.4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium))
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
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
        switch phase {
        case .strike: return viewModel.hunt?.animal?.name ?? "PREY"
        case .track: return "WILDERNESS"
        case .blessing: return "ALTAR"
        default: return "ENCOUNTER"
        }
    }
    
    private var enemySubtitle: String? {
        switch phase {
        case .strike:
            if let hp = viewModel.hunt?.animal?.hp {
                return "HP \(viewModel.currentAnimalHP)/\(hp)"
            }
            return nil
        case .track: return "Find prey"
        case .blessing: return "Seek fortune"
        default: return nil
        }
    }
    
    // MARK: - Roll Result Card
    
    private var rollResultCard: some View {
        VStack(spacing: 10) {
            // Result or prompt
            ZStack {
                if isShowingMasterRoll {
                    resultRow(
                        badge: "MASTER ROLL",
                        message: viewModel.masterRollAnimating ? "Rolling…" : "Locked in",
                        value: "\(viewModel.masterRollValue)",
                        tint: KingdomTheme.Colors.regalPurple
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
            
            // Mini odds bar
            oddsBarMini
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
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
    
    private func resultRow(badge: String, message: String, value: String, tint: Color) -> some View {
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
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    private var oddsBarMini: some View {
        let items = displayConfig?.drop_table_items ?? []
        let total = viewModel.dropTableSlots.values.reduce(0, +)
        
        return VStack(spacing: 4) {
            HStack {
                Text(isShowingMasterRoll ? "ROLLING" : "ODDS")
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            GeometryReader { geo in
                ZStack {
                    // Segments
                    HStack(spacing: 0) {
                        ForEach(items, id: \.key) { item in
                            let count = viewModel.dropTableSlots[item.key] ?? 0
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
                    
                    // Master roll crosshairs
                    if isShowingMasterRoll && viewModel.masterRollValue > 0 {
                        let markerX = geo.size.width * CGFloat(viewModel.masterRollValue) / 100.0
                        
                        Image(systemName: "scope")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                            .position(x: markerX, y: 10)
                    }
                }
            }
            .frame(height: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture { isShowingIntelSheet = true }
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
            
            Group {
                switch viewModel.uiState {
                case .phaseActive, .rolling, .rollRevealing:
                    twoButtonRow
                case .resolving, .masterRollAnimation:
                    if viewModel.masterRollAnimating || (viewModel.uiState == .resolving(phase)) {
                        loadingRow
                    } else {
                        continueButton
                    }
                default:
                    Color.clear.frame(height: 50)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
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
                backgroundColor: viewModel.canRoll ? phaseColor : KingdomTheme.Colors.disabled,
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
                backgroundColor: viewModel.canResolve ? KingdomTheme.Colors.regalPurple : KingdomTheme.Colors.disabled,
                foregroundColor: .white,
                fullWidth: true
            ))
            .disabled(!viewModel.canResolve)
        }
    }
    
    private var loadingRow: some View {
        HStack {
            ProgressView().tint(KingdomTheme.Colors.regalPurple)
            Text("Master Roll...").font(KingdomTheme.Typography.headline())
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
    
    // MARK: - Intel Sheet
    
    private var intelSheet: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            HStack {
                Text("Intel").font(KingdomTheme.Typography.title2())
                Spacer()
                Button("Done") { isShowingIntelSheet = false }
                    .buttonStyle(.toolbar(color: KingdomTheme.Colors.inkDark))
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.top, KingdomTheme.Spacing.large)
            
            DropTableBar(
                title: displayConfig?.drop_table_title ?? "ODDS",
                slots: viewModel.dropTableSlots,
                itemConfigs: displayConfig?.drop_table_items ?? [],
                masterRollValue: viewModel.masterRollValue,
                isAnimatingMasterRoll: viewModel.masterRollAnimating
            )
            .padding(.horizontal, KingdomTheme.Spacing.large)
            
            if phase == .strike {
                CombatHPBar(animal: viewModel.hunt?.animal, animalHP: viewModel.hunt?.animal?.hp ?? 1)
                    .padding(.horizontal, KingdomTheme.Spacing.large)
            }
            
            Spacer()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
    }
    
    // MARK: - Helpers
    
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
}

#Preview {
    HuntPhaseView(viewModel: HuntViewModel(), phase: .track, showingIntro: true)
}
