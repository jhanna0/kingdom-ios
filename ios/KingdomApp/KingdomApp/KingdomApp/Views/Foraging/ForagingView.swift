import SwiftUI

// MARK: - Foraging View
// Two-round foraging: Berries (Round 1) + Bonus Seeds (Round 2)
// Tap bushes to reveal - find seed trail to unlock bonus round!

struct ForagingView: View {
    @StateObject private var viewModel = ForagingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    @State private var showResult: Bool = false
    @State private var showSeedTrailOverlay: Bool = false
    @State private var isRevealing: Bool = false
    
    // Juice state
    @State private var lastRevealedCount: Int = 0
    @State private var lastFoundCount: Int = 0
    @State private var boardIsResetting: Bool = true
    
    // Transition animation state
    @State private var isTransitioning: Bool = false
    @State private var gridSlideOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                VStack(spacing: 20) {
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
            
            // Seed Trail Found Overlay
            if showSeedTrailOverlay {
                SeedTrailFoundOverlay(
                    onFollowTrail: {
                        showSeedTrailOverlay = false
                        startBonusTransition()
                    }
                )
            }
            
            // Result Overlay (win/lose for current round)
            if showResult {
                ForagingResultOverlay(
                    hasWon: viewModel.hasWon,
                    isBonusRound: viewModel.isBonusRound,
                    rewards: viewModel.allRewards,
                    onPrimary: {
                        Task {
                            await viewModel.collect()
                            showResult = false
                            await viewModel.startSession()
                        }
                    },
                    onSecondary: {
                        showResult = false
                        Task { await viewModel.playAgain() }
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.startSession()
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
        .onChange(of: viewModel.revealedTargetCount) { _, newValue in
            if newValue > lastFoundCount {
                hapticImpact(.medium)
            }
            lastFoundCount = newValue
        }
        .onChange(of: viewModel.foundSeedTrail) { _, found in
            if found {
                // Delay to let player see the seed trail tile
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    haptic(.success)
                }
            }
        }
    }
    
    // MARK: - State Change Handler
    
    private func handleStateChange(_ newState: ForagingViewModel.UIState) {
        switch newState {
        case .loading:
            withAnimation(.easeOut(duration: 0.18)) {
                boardIsResetting = true
            }
            
        case .playing, .bonusRound:
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                boardIsResetting = false
            }
            
        case .seedTrailFound:
            // Show the seed trail overlay after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSeedTrailOverlay = true
                }
            }
            
        case .transitioning:
            // Animation handled by startBonusTransition()
            break
            
        case .won, .lost, .bonusWon, .bonusLost:
            let isWin = newState == .won || newState == .bonusWon
            haptic(isWin ? .success : .warning)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showResult = true
                }
            }
            
        case .error:
            break
        }
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
                    Image(systemName: viewModel.isBonusRound ? "sparkles" : "leaf.fill")
                        .font(FontStyles.iconMedium)
                        .frame(width: 24, height: 24)
                        .foregroundColor(viewModel.isBonusRound ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.buttonSuccess)
                    
                    Text(viewModel.isBonusRound ? "SEED TRAIL" : "FORAGING")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(viewModel.isBonusRound ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.inkDark)
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
                .fill(viewModel.isBonusRound ? KingdomTheme.Colors.imperialGold : Color.black)
                .frame(height: 3)
        }
        .background(viewModel.isBonusRound ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Status
    
    private var statusCard: some View {
        let isLoading = viewModel.uiState == .loading || viewModel.uiState == .transitioning
        let tapsLeft = max(0, viewModel.maxReveals - viewModel.revealedCount)
        
        return VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black)
                        .offset(x: 2, y: 2)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    Image(systemName: "leaf.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
                .frame(width: 46, height: 46)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Match 3 to collect")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 10) {
                        if let config = viewModel.rewardConfig {
                            HStack(spacing: 6) {
                                Image(systemName: config.icon)
                                    .font(FontStyles.iconTiny)
                                Text(config.display_name)
                                    .font(FontStyles.labelMedium)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.parchmentLight,
                                cornerRadius: 8,
                                borderWidth: 2
                            )
                        } else {
                            Text(isLoading ? "Preparing..." : "Target")
                                .font(FontStyles.labelMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .brutalistBadge(
                                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                                    cornerRadius: 8,
                                    borderWidth: 2
                                )
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(viewModel.revealedTargetCount)/\(viewModel.matchesToWin)")
                                .font(FontStyles.statMedium)
                                .foregroundColor(viewModel.isWarming ? KingdomTheme.Colors.color(fromThemeName: viewModel.rewardConfig?.color ?? "buttonSuccess") : KingdomTheme.Colors.inkDark)
                            
                            Text("found")
                                .font(FontStyles.captionLarge)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(width: 72, alignment: .trailing)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.revealedTargetCount)
                    }
                }
            }
            
            HStack(spacing: 10) {
                ForagingMiniStatPill(
                    title: "Taps left",
                    value: "\(tapsLeft)",
                    color: tapsLeft <= 1 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkDark
                )
                
                ForagingMiniStatPill(
                    title: "Collect",
                    value: "\(max(0, viewModel.matchesToWin - viewModel.revealedTargetCount))",
                    color: KingdomTheme.Colors.royalBlue
                )
                
                // Show seed trail indicator in Round 1
                if !viewModel.isBonusRound && viewModel.foundSeedTrail {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(FontStyles.iconTiny)
                        Text("Trail!")
                            .font(FontStyles.captionMedium)
                    }
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.parchmentHighlight,
                        cornerRadius: 8,
                        borderWidth: 2
                    )
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(KingdomTheme.Colors.loadingTint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 16)
        .opacity(isLoading ? 0.92 : 1.0)
    }
    
    // MARK: - Grid
    
    private var bushGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        let entryToken = "\(viewModel.session?.session_id ?? "loading")_r\(viewModel.currentRound)"
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<16, id: \.self) { position in
                let isRevealed = viewModel.isRevealed(position)
                let revealedCell = viewModel.revealedCell(at: position)
                let isTarget = revealedCell?.is_seed ?? false
                let isSeedTrail = revealedCell?.isSeedTrail ?? false
                let shouldPulse = isTarget && viewModel.isWarming
                let row = position / 4
                let col = position % 4
                let entryDelay = Double(row) * 0.06 + Double(col) * 0.02
                
                BushTile(
                    cell: revealedCell,
                    isRevealed: isRevealed,
                    isHighlighted: isTarget && !viewModel.hasWon,
                    isWinningMatch: isTarget && viewModel.hasWon,
                    isSeedTrail: isSeedTrail,
                    shouldPulse: shouldPulse,
                    hiddenIcon: viewModel.hiddenIcon,
                    hiddenColor: viewModel.hiddenColor,
                    boardIsResetting: boardIsResetting || isTransitioning,
                    entryToken: entryToken,
                    entryDelay: entryDelay
                ) {
                    guard viewModel.canReveal, !isRevealed, !isRevealing, !isTransitioning else { return }
                    isRevealing = true
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 140_000_000)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            viewModel.reveal(position: position)
                        }
                        try? await Task.sleep(nanoseconds: 260_000_000)
                        isRevealing = false
                    }
                }
                .id("\(viewModel.session?.session_id ?? "none")_r\(viewModel.currentRound)_\(position)")
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
        let message: String
        let color: Color
        
        if viewModel.isBonusRound {
            if viewModel.isWarming {
                message = "You're getting close!"
                color = KingdomTheme.Colors.imperialGold
            } else {
                message = "Dig for seeds..."
                color = KingdomTheme.Colors.inkMedium
            }
        } else if viewModel.foundSeedTrail {
            message = "Seed trail found!"
            color = KingdomTheme.Colors.imperialGold
        } else if viewModel.isWarming {
            message = "Keep going."
            color = KingdomTheme.Colors.buttonSuccess
        } else {
            message = "Tap a bush to reveal."
            color = KingdomTheme.Colors.inkMedium
        }
        
        return VStack(spacing: 0) {
            Rectangle()
                .fill(viewModel.isBonusRound ? KingdomTheme.Colors.imperialGold : Color.black)
                .frame(height: 3)
            
            Text(message)
                .font(FontStyles.bodySmallBold)
                .foregroundColor(color)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, KingdomTheme.Spacing.large)
        }
        .background((viewModel.isBonusRound ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight).ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Result Overlay
    
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
    let boardIsResetting: Bool
    let entryToken: String
    let entryDelay: Double
    let onTap: () -> Void
    
    @State private var pulse = false
    @State private var isFlipped = false
    @State private var seedTrailGlow = false
    
    // Minimal feedback (no particle clouds)
    @State private var tapRingScale: CGFloat = 0.75
    @State private var tapRingOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var flashColor: Color = .clear
    
    // Board in/out animation
    @State private var boardOffsetY: CGFloat = -60
    @State private var boardOpacity: Double = 0
    
    private var isCellSeedTrail: Bool {
        cell?.isSeedTrail ?? false
    }
    
    var body: some View {
        Button {
            triggerTapRing()
            onTap()
        } label: {
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
            .scaleEffect(pulse ? 1.08 : 1.0)
            .scaleEffect(seedTrailGlow ? 1.03 : 1.0)
        }
        .buttonStyle(ForagingTilePressButtonStyle())
        .onAppear {
            isFlipped = isRevealed
            if shouldPulse { startPulse() }
            animateBoardState(isResetting: boardIsResetting, token: entryToken)
        }
        .onChange(of: shouldPulse) { _, doPulse in
            if doPulse { startPulse() } else { pulse = false }
        }
        .onChange(of: isRevealed) { _, nowRevealed in
            guard nowRevealed else { return }
            isFlipped = true
            triggerRevealFlash()
            
            // Start seed trail glow if this is the trail
            if isCellSeedTrail {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    seedTrailGlow = true
                }
            }
        }
        .onChange(of: boardIsResetting) { _, isResetting in
            animateBoardState(isResetting: isResetting, token: entryToken)
        }
        .onChange(of: entryToken) { _, newToken in
            animateBoardState(isResetting: boardIsResetting, token: newToken)
        }
        .offset(y: boardOffsetY)
        .opacity(boardOpacity)
    }
    
    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            pulse = true
        }
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
    
    private func animateBoardState(isResetting: Bool, token: String) {
        if isResetting {
            withAnimation(.easeIn(duration: 0.18)) {
                boardOffsetY = 40
                boardOpacity = 0
            }
        } else {
            boardOffsetY = -70
            boardOpacity = 0
            let delay = max(0, entryDelay)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {
                    boardOffsetY = 0
                    boardOpacity = 1
                }
            }
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

// MARK: - Mini Stat Pill

private struct ForagingMiniStatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(FontStyles.captionMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Text(value)
                .font(FontStyles.statMedium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 10,
            borderWidth: 2
        )
    }
}

// MARK: - Seed Trail Found Overlay

private struct SeedTrailFoundOverlay: View {
    let onFollowTrail: () -> Void
    
    @State private var iconScale: CGFloat = 0.7
    @State private var contentOpacity: Double = 0
    @State private var trailPulse: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    // Sparkles around the icon
                    ForEach(0..<8, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            .offset(
                                x: CGFloat.random(in: -60...60),
                                y: CGFloat.random(in: -50...50)
                            )
                            .opacity(0.7)
                    }
                    
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        .scaleEffect(iconScale)
                        .scaleEffect(trailPulse ? 1.05 : 1.0)
                }
                
                Text("Seed Trail Found!")
                    .font(FontStyles.resultSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("You discovered a trail of seeds leading deeper into the forest...")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                
                Button(action: onFollowTrail) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Follow the Trail")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    foregroundColor: .white,
                    fullWidth: true
                ))
            }
            .padding(24)
            .frame(maxWidth: 300)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 18)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                contentOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                trailPulse = true
            }
        }
    }
}

// MARK: - Result Overlay

private struct ForagingResultOverlay: View {
    let hasWon: Bool
    let isBonusRound: Bool
    let rewards: [ForagingReward]  // Just render this array!
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    
    @State private var iconScale: CGFloat = 0.86
    @State private var contentOpacity: Double = 0
    
    private var hasAnyRewards: Bool { !rewards.isEmpty }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ZStack {
                    if hasAnyRewards {
                        ForEach(0..<6, id: \.self) { _ in
                            Image(systemName: "sparkle")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.color(fromThemeName: rewards.first?.color ?? "buttonSuccess"))
                                .offset(
                                    x: CGFloat.random(in: -70...70),
                                    y: CGFloat.random(in: -55...55)
                                )
                                .opacity(0.8)
                        }
                    }
                    
                    Image(systemName: hasAnyRewards ? (rewards.first?.icon ?? "checkmark.circle.fill") : "xmark.circle.fill")
                        .font(.system(size: 64, weight: .black))
                        .foregroundColor(hasAnyRewards ? KingdomTheme.Colors.color(fromThemeName: rewards.first?.color ?? "buttonSuccess") : KingdomTheme.Colors.inkMedium)
                        .shadow(color: .clear, radius: 0)
                        .scaleEffect(iconScale)
                }
                
                if hasAnyRewards {
                    Text("Found!")
                        .font(FontStyles.resultSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Just render whatever backend sent
                    VStack(spacing: 8) {
                        ForEach(rewards.indices, id: \.self) { index in
                            let reward = rewards[index]
                            HStack(spacing: 6) {
                                Image(systemName: reward.icon)
                                    .font(FontStyles.iconSmall)
                                    .foregroundColor(KingdomTheme.Colors.color(fromThemeName: reward.color))
                                Text("+\(reward.amount) \(reward.display_name)")
                                    .font(FontStyles.bodyMediumBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                        }
                    }
                    
                    Button(action: onPrimary) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Collect & Keep Foraging")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.color(fromThemeName: rewards.first?.color ?? "buttonSuccess"),
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                } else {
                    Text("No Match")
                        .font(FontStyles.resultSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Better luck next time!")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Button(action: onSecondary) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try Again")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                }
            }
            .padding(24)
            .frame(maxWidth: 300)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 18)
            .opacity(contentOpacity)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .onAppear(perform: animateEntrance)
    }
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
            iconScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
            contentOpacity = 1.0
        }
    }
}

#Preview {
    Text("Foraging Preview")
}
