import SwiftUI

// MARK: - Foraging View
// Two-round foraging: Berries (Round 1) + Bonus Seeds (Round 2)
// Tap bushes to reveal - find seed trail to unlock bonus round!

struct ForagingView: View {
    @StateObject private var viewModel = ForagingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    @State private var isRevealing: Bool = false
    @State private var isResetting: Bool = false
    @State private var displayedIsBonusRound: Bool = false
    @State private var displayedRewardConfig: ForagingRewardConfig? = nil
    @State private var pulsingPositions: Set<Int> = []
    
    // Juice state
    @State private var lastRevealedCount: Int = 0
    @State private var lastFoundCount: Int = 0
    
    // Transition animation state (only for seed trail -> bonus round)
    @State private var isTransitioning: Bool = false
    @State private var gridSlideOffset: CGFloat = 0
    
    // Streak bonus popup - controlled by backend, not local state
    @State private var showStreakPopup: Bool = false
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                VStack(spacing: 16) {
                    statusCard
                    
                    Spacer()
                    
                    bushGrid
                        .offset(x: gridSlideOffset)
                    
                    Spacer()
                    
                    progressDots
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.vertical, KingdomTheme.Spacing.medium)
                
                bottomBar
            }
            
            // Streak bonus popup
            if showStreakPopup, let streakInfo = viewModel.streakInfo {
                StreakBonusPopup(
                    title: streakInfo.title,
                    subtitle: streakInfo.subtitle,
                    description: streakInfo.description,
                    multiplier: streakInfo.multiplier,
                    icon: streakInfo.icon,
                    color: streakInfo.color,
                    dismissButton: streakInfo.dismiss_button
                ) {
                    showStreakPopup = false
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.startSession()
            displayedIsBonusRound = viewModel.isBonusRound
            displayedRewardConfig = viewModel.rewardConfig
        }
        .onChange(of: viewModel.uiState) { _, newState in
            handleStateChange(newState)
        }
        .onChange(of: viewModel.revealedCount) { _, newValue in
            if newValue > lastRevealedCount {
                hapticImpact(.light)
            }
            lastRevealedCount = newValue
        }
        .onChange(of: viewModel.revealedTargetCount) { oldCount, newCount in
            if newCount > lastFoundCount {
                hapticImpact(.medium)
            }
            lastFoundCount = newCount
            
            // Show streak popup when we hit the winning match count (3rd target revealed)
            // Only if backend says we have a streak bonus to show
            if newCount >= viewModel.matchesToWin && oldCount < viewModel.matchesToWin {
                if viewModel.shouldShowStreakPopup && !showStreakPopup {
                    // Small delay so player sees the winning tile first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showStreakPopup = true
                    }
                }
            }
        }
        .onChange(of: viewModel.foundSeedTrail) { _, found in
            if found {
                // Delay to let player see the seed trail tile
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    haptic(.success)
                }
            }
        }
        .onChange(of: viewModel.revealedBushes) { _, _ in
            recomputePulsingPositions()
        }
        .onChange(of: isResetting) { _, _ in
            recomputePulsingPositions()
        }
    }
    
    // MARK: - State Change Handler
    
    private func handleStateChange(_ newState: ForagingViewModel.UIState) {
        switch newState {
        case .loading, .playing, .bonusRound:
            // No drop animation - tiles just reset in place
            if newState == .playing || newState == .bonusRound {
                isResetting = false
                displayedIsBonusRound = viewModel.isBonusRound
                displayedRewardConfig = viewModel.rewardConfig
                recomputePulsingPositions()
            }
            break
            
        case .seedTrailFound:
            // Bottom bar will show the transition button
            haptic(.success)
            
        case .transitioning:
            // Animation handled by startBonusTransition()
            break
            
        case .won, .lost, .bonusWon, .bonusLost:
            let isWin = newState == .won || newState == .bonusWon
            haptic(isWin ? .success : .warning)
            
        case .error:
            break
        }
    }

    // MARK: - Reset Helpers
    
    @MainActor
    private func flipResetThen(_ action: @escaping () async -> Void) async {
        guard !isResetting else { return }
        isResetting = true
        pulsingPositions = []
        
        // Let BushTile animate flip-back before we mutate the session.
        try? await Task.sleep(nanoseconds: 450_000_000)
        await action()
    }
    
    @MainActor
    private func recomputePulsingPositions() {
        guard !isResetting else {
            pulsingPositions = []
            return
        }
        guard viewModel.isWarming else {
            pulsingPositions = []
            return
        }
        
        let pulsing = viewModel.revealedBushes.keys.filter { pos in
            viewModel.revealedCell(at: pos)?.is_seed == true
        }
        pulsingPositions = Set(pulsing)
    }
    
    // MARK: - Bonus Round Transition
    
    private func startBonusTransition() {
        viewModel.startBonusRound()
        isTransitioning = true
        
        // Phase 1: Slide current grid out to the left
        withAnimation(.easeIn(duration: 0.35)) {
            gridSlideOffset = -UIScreen.main.bounds.width
        }
        
        // Phase 2: Instantly move to right side (off-screen), then enter bonus round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            gridSlideOffset = UIScreen.main.bounds.width
            viewModel.enterBonusRound()
            
            // Phase 3: Slide new grid in from the right
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                gridSlideOffset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTransitioning = false
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: displayedIsBonusRound ? "sparkles" : "leaf.fill")
                        .font(FontStyles.iconMedium)
                        .frame(width: 24, height: 24)
                        .foregroundColor(displayedIsBonusRound ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.buttonSuccess)
                    
                    Text(displayedIsBonusRound ? "SEED TRAIL" : "FORAGING")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(displayedIsBonusRound ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.endSession()
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            
            Rectangle()
                .fill(displayedIsBonusRound ? KingdomTheme.Colors.imperialGold : Color.black)
                .frame(height: 3)
        }
        .background(displayedIsBonusRound ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Status
    
    private var statusCard: some View {
        let tapsLeft = max(0, viewModel.maxReveals - viewModel.revealedCount)
        
        return VStack(spacing: 12) {
            // Top row: What to find + progress
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: displayedRewardConfig?.icon ?? "seal.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.color(fromThemeName: displayedRewardConfig?.color ?? "buttonDanger"))
                    
                    Text("Match 3 \(displayedRewardConfig?.display_name ?? "Berries")")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                // Found progress badge
                HStack(spacing: 6) {
                    Text("\(viewModel.revealedTargetCount)/\(viewModel.matchesToWin)")
                        .font(FontStyles.statLarge)
                        .foregroundColor(viewModel.isWarming ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkDark)
                    Text("found")
                        .font(FontStyles.captionLarge)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(height: 20)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 10,
                    borderWidth: 2
                )
            }
            
            // Bottom row: Taps left + session tallies
            HStack(spacing: 10) {
                // Taps left badge
                HStack(spacing: 6) {
                    Text("\(tapsLeft)")
                        .font(FontStyles.statMedium)
                        .foregroundColor(tapsLeft <= 1 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkDark)
                    Text("taps")
                        .font(FontStyles.captionLarge)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(height: 20)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 10,
                    borderWidth: 2
                )
                
                Spacer()
                
                // Berries collected badge
                HStack(spacing: 6) {
                    Image(systemName: "seal.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("\(viewModel.totalBerriesCollected)")
                        .font(FontStyles.statMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .frame(height: 20)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 10,
                    borderWidth: 2
                )
                
                // Seed trails badge
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                    Text("\(viewModel.totalSeedTrailsFound / 3)")
                        .font(FontStyles.statMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .frame(height: 20)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    cornerRadius: 10,
                    borderWidth: 2
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 16)
    }
    
    // MARK: - Grid
    
    private var bushGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<16, id: \.self) { position in
                let isRevealed = viewModel.isRevealed(position)
                let effectiveRevealed = isRevealed && !isResetting
                let revealedCell = viewModel.revealedCell(at: position)
                let isTarget = effectiveRevealed && (revealedCell?.is_seed ?? false)
                let isSeedTrail = revealedCell?.isSeedTrail ?? false
                let shouldPulse = pulsingPositions.contains(position)
                
                BushTile(
                    cell: revealedCell,
                    isRevealed: effectiveRevealed,
                    isHighlighted: isTarget && !viewModel.hasWon,
                    isWinningMatch: isTarget && viewModel.hasWon,
                    isSeedTrail: isSeedTrail,
                    shouldPulse: shouldPulse,
                    hiddenIcon: viewModel.hiddenIcon,
                    hiddenColor: viewModel.hiddenColor
                ) {
                    guard viewModel.canReveal, !isRevealed, !isRevealing, !isTransitioning, !isResetting else { return }
                    isRevealing = true
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 140_000_000)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            viewModel.reveal(position: position)
                        }
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        isRevealing = false
                    }
                }
                .id(position)
            }
        }
        .padding(KingdomTheme.Spacing.small)
    }
    
    // MARK: - Progress
    
    private var progressDots: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<viewModel.maxReveals, id: \.self) { i in
                    let isJustRevealed = i == viewModel.revealedCount - 1
                    let isFilled = i < viewModel.revealedCount
                    
                    Circle()
                        .fill(isFilled
                              ? KingdomTheme.Colors.buttonSuccess
                              : KingdomTheme.Colors.inkMedium.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        .scaleEffect(isJustRevealed ? 1.25 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: viewModel.revealedCount)
                }
            }
        }
        .frame(height: 18) // lock height so bottom doesn't jump
    }
    
    // MARK: - Bottom
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(displayedIsBonusRound ? KingdomTheme.Colors.imperialGold : Color.black)
                .frame(height: 3)
            
            bottomBarContent
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, KingdomTheme.Spacing.large)
        }
        .background((displayedIsBonusRound ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight).ignoresSafeArea(edges: .bottom))
    }
    
    @ViewBuilder
    private var bottomBarContent: some View {
        switch viewModel.uiState {
        case .loading, .transitioning:
            HStack {
                skillBadge
                Spacer()
                ProgressView()
                    .tint(KingdomTheme.Colors.loadingTint)
            }
            
        case .playing, .bonusRound:
            HStack {
                skillBadge
                Spacer()
                Text(playingMessage)
                    .font(FontStyles.bodySmallBold)
                    .foregroundColor(playingMessageColor)
            }
            
        case .seedTrailFound:
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                    Text("Seed Trail!")
                        .font(FontStyles.bodySmallBold)
                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                }
                
                Spacer()
                
                Button {
                    startBonusTransition()
                } label: {
                    HStack(spacing: 4) {
                        Text("Follow")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.brutalist(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    foregroundColor: .white
                ))
            }
            
        case .won, .bonusWon:
            HStack(spacing: 12) {
                if let reward = viewModel.allRewards.first {
                    HStack(spacing: 6) {
                        Image(systemName: reward.icon)
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.color(fromThemeName: reward.color))
                        Text("+\(reward.amount) \(reward.display_name)")
                            .font(FontStyles.bodySmallBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
                
                Spacer()
                
                Button {
                    Task {
                        await flipResetThen {
                            await viewModel.collect()
                            await viewModel.startSession()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Collect")
                    }
                }
                .buttonStyle(.brutalist(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    foregroundColor: .white
                ))
            }
            
        case .lost, .bonusLost:
            HStack(spacing: 12) {
                Text("No match — try again!")
                    .font(FontStyles.bodySmallBold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                Button {
                    Task {
                        await flipResetThen {
                            await viewModel.playAgain()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Retry")
                    }
                }
                .buttonStyle(.brutalist(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    foregroundColor: .white
                ))
            }
            
        case .error(let message):
            Text(message)
                .font(FontStyles.captionMedium)
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
        }
    }
    
    @ViewBuilder
    private var skillBadge: some View {
        if let skillInfo = viewModel.currentSkillInfo {
            let config = SkillConfig.get(skillInfo.skill)
            
            HStack(spacing: 4) {
                Image(systemName: config.icon)
                    .font(FontStyles.iconTiny)
                Text("\(config.displayName) T\(skillInfo.level)")
                    .font(FontStyles.captionMedium)
            }
            .foregroundColor(config.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .brutalistBadge(
                backgroundColor: KingdomTheme.Colors.parchmentDark,
                cornerRadius: 6,
                borderWidth: 1.5
            )
        }
    }
    
    private var playingMessage: String {
        if displayedIsBonusRound {
            return viewModel.isWarming ? "Getting close!" : "Dig for seeds..."
        } else if viewModel.foundSeedTrail {
            return "Seed trail found!"
        } else if viewModel.isWarming {
            return "Keep going..."
        } else {
            return "Tap to reveal"
        }
    }
    
    private var playingMessageColor: Color {
        if displayedIsBonusRound && viewModel.isWarming {
            return KingdomTheme.Colors.imperialGold
        } else if viewModel.foundSeedTrail {
            return KingdomTheme.Colors.imperialGold
        } else if viewModel.isWarming {
            return KingdomTheme.Colors.buttonSuccess
        } else {
            return KingdomTheme.Colors.inkMedium
        }
    }
    
    // MARK: - Haptics
    
    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Bush Tile
// Dumb renderer - show hidden or revealed content from array

struct BushTile: View {
    let cell: ForagingBushCell?     // nil = not revealed yet
    let isRevealed: Bool
    let isHighlighted: Bool
    let isWinningMatch: Bool
    let isSeedTrail: Bool           // Is this the special seed trail cell?
    let shouldPulse: Bool
    let hiddenIcon: String
    let hiddenColor: String
    let onTap: () -> Void
    
    @State private var isFlipped = false
    
    // Minimal feedback (no particle clouds)
    @State private var tapRingScale: CGFloat = 0.75
    @State private var tapRingOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var flashColor: Color = .clear
    
    private var isCellSeedTrail: Bool {
        cell?.isSeedTrail ?? false
    }
    
    var body: some View {
        Button {
            triggerTapRing()
            onTap()
        } label: {
            pulsingTileBody
        }
        .buttonStyle(ForagingTilePressButtonStyle())
        .onAppear {
            isFlipped = isRevealed
        }
        .onChange(of: isRevealed) { _, nowRevealed in
            if nowRevealed {
                isFlipped = true
                triggerRevealFlash()
            } else {
                // Flip back to hidden
                isFlipped = false
            }
        }
    }
    
    @ViewBuilder
    private var pulsingTileBody: some View {
        if shouldPulse || (isCellSeedTrail && isRevealed) {
            TimelineView(.animation) { context in
                tileBody
                    .scaleEffect(combinedScale(at: context.date))
            }
        } else {
            tileBody
        }
    }
    
    private var tileBody: some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .offset(x: 3, y: 3)
            
            // Background
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: (isHighlighted || isWinningMatch || isSeedTrail) ? 3 : 2.5)
                )
                .overlay(winningGlow)
                .overlay(seedTrailGlowOverlay)
                .overlay(revealFlashOverlay)
            
            // Front / Back (flip)
            ZStack {
                hiddenFace
                    .opacity(isFlipped ? 0 : 1)
                revealedFace
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isFlipped)
            
            tapRingOverlay
        }
        .frame(height: 65)
    }
    
    private func combinedScale(at date: Date) -> CGFloat {
        var scale: CGFloat = 1.0
        if shouldPulse {
            scale *= pulseScale(at: date)
        }
        if isCellSeedTrail && isRevealed {
            scale *= seedTrailScale(at: date)
        }
        return scale
    }
    
    private func pulseScale(at date: Date) -> CGFloat {
        // Smooth sine pulse: ~0.8s period, subtle amplitude.
        let t = date.timeIntervalSinceReferenceDate
        let period = 0.8
        let phase = (t / period) * (2.0 * Double.pi)
        let normalized = (sin(phase) + 1.0) / 2.0 // 0...1
        return 1.0 + CGFloat(0.08 * normalized)
    }
    
    private func seedTrailScale(at date: Date) -> CGFloat {
        // Separate glow pulse for seed trail tiles (~1.0s period, subtle).
        let t = date.timeIntervalSinceReferenceDate
        let period = 1.0
        let phase = (t / period) * (2.0 * Double.pi)
        let normalized = (sin(phase) + 1.0) / 2.0 // 0...1
        return 1.0 + CGFloat(0.03 * normalized)
    }
    
    private func triggerTapRing() {
        tapRingScale = 0.78
        tapRingOpacity = 0.6
        
        withAnimation(.easeOut(duration: 0.32)) {
            tapRingScale = 1.45
            tapRingOpacity = 0
        }
    }
    
    private func triggerRevealFlash() {
        let isSeed = cell?.is_seed ?? false
        let isTrail = cell?.isSeedTrail ?? false
        
        if isTrail {
            flashColor = KingdomTheme.Colors.imperialGold
            flashOpacity = 0.25
        } else if isSeed {
            flashColor = KingdomTheme.Colors.buttonSuccess
            flashOpacity = 0.18
        } else {
            flashColor = KingdomTheme.Colors.inkMedium
            flashOpacity = 0.12
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            flashOpacity = 0
        }
    }
    
    private var backgroundColor: Color {
        let isSeed = (cell?.is_seed ?? false) && isRevealed
        let isTrail = isCellSeedTrail && isRevealed
        if isTrail { return KingdomTheme.Colors.parchmentHighlight }
        if isWinningMatch { return KingdomTheme.Colors.parchmentHighlight }
        if isHighlighted { return KingdomTheme.Colors.parchmentHighlight }
        if isSeed { return KingdomTheme.Colors.parchmentLight }
        return isRevealed ? KingdomTheme.Colors.parchmentDark : KingdomTheme.Colors.parchment
    }
    
    private var borderColor: Color {
        let isTrail = isCellSeedTrail && isRevealed
        if isTrail { return KingdomTheme.Colors.imperialGold }
        if isWinningMatch { return KingdomTheme.Colors.buttonSuccess }
        if isHighlighted { return KingdomTheme.Colors.royalBlue }
        return Color.black
    }
    
    private var hiddenFace: some View {
        Image(systemName: hiddenIcon)
            .font(FontStyles.iconMedium)
            .foregroundColor(KingdomTheme.Colors.color(fromThemeName: hiddenColor))
    }
    
    private var revealedFace: some View {
        Group {
            if let cell, isRevealed {
                VStack(spacing: 2) {
                    Image(systemName: cell.icon)
                        .font(cell.label != nil ? FontStyles.iconSmall : FontStyles.iconMedium)
                        .foregroundColor(cellColor(for: cell))
                        .shadow(color: .clear, radius: 0)
                    
                    if let label = cell.label {
                        Text(label)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.color(fromThemeName: cell.color))
                    }
                }
            } else {
                Image(systemName: hiddenIcon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.color(fromThemeName: hiddenColor))
            }
        }
    }
    
    private func cellColor(for cell: ForagingBushCell) -> Color {
        if cell.isSeedTrail {
            return KingdomTheme.Colors.imperialGold
        } else if cell.is_seed {
            return KingdomTheme.Colors.royalBlue
        } else {
            return KingdomTheme.Colors.color(fromThemeName: cell.color)
        }
    }
    
    private var winningGlow: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(KingdomTheme.Colors.buttonSuccess, lineWidth: isWinningMatch ? 3 : 0)
            .blur(radius: isWinningMatch ? 1.5 : 0)
            .opacity(isWinningMatch ? 0.65 : 0)
            .animation(.easeInOut(duration: 0.35), value: isWinningMatch)
    }
    
    private var seedTrailGlowOverlay: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(KingdomTheme.Colors.imperialGold, lineWidth: (isCellSeedTrail && isRevealed) ? 2 : 0)
            .blur(radius: (isCellSeedTrail && isRevealed) ? 3 : 0)
            .opacity((isCellSeedTrail && isRevealed) ? 0.8 : 0)
    }
    
    private var tapRingOverlay: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(KingdomTheme.Colors.inkDark.opacity(0.55), lineWidth: 2)
            .scaleEffect(tapRingScale)
            .opacity(tapRingOpacity)
            .allowsHitTesting(false)
    }
    
    private var revealFlashOverlay: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(flashColor)
            .opacity(flashOpacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Tile Press Style

private struct ForagingTilePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? -0.6 : 0))
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

#Preview {
    Text("Foraging Preview")
}
