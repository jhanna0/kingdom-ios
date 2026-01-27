import SwiftUI
import Combine

struct DuelCombatView: View {
    let match: DuelMatch
    let playerId: Int
    let onComplete: () -> Void

    @StateObject private var viewModel = DuelCombatViewModel()
    
    // Animation state (local to view)
    @State private var rollDisplayValue: Int = 0
    @State private var showRollMarker: Bool = false
    @State private var animatedBarValue: Double = 50
    @State private var barPulse: Bool = false  // Pulse effect on bar push
    @State private var pushFlash: Bool = false  // Full-screen flash on big push
    @State private var pushDirection: Double = 0  // +1 = good push, -1 = bad push
    
    // Character animation state
    @State private var myCharacterSwinging: Bool = false
    @State private var enemyCharacterSwinging: Bool = false
    @State private var myCharacterPushing: Bool = false
    @State private var enemyCharacterPushing: Bool = false
    @State private var showImpact: Bool = false
    @State private var lastOutcome: String = ""
    
    // Forfeit confirmation
    @State private var showForfeitConfirmation: Bool = false
    
    // Critical hit popup
    @State private var showCritPopup: Bool = false
    @State private var critPopupData: CritPopupData? = nil
    
    // Turn timer (initialized from server config)
    @State private var secondsRemaining: Int = 0
    @State private var timerActive: Bool = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Server config (no hardcoded values!)
    private var gameConfig: DuelGameConfig? { currentMatch.config }
    private var turnTimeout: Int { gameConfig?.turnTimeoutSeconds ?? 30 }  // Fallback only for loading state
    private var roundTimeout: Int { gameConfig?.roundTimeoutSeconds ?? turnTimeout }
    private var critMultiplier: Double { gameConfig?.criticalMultiplier ?? 1.5 }
    private var critPopupDurationMs: Int { gameConfig?.critPopupDurationMs ?? 1500 }
    private var rollSweepStepMs: Int { gameConfig?.rollSweepStepMs ?? 15 }
    private var isRoundMode: Bool { (gameConfig?.duelMode ?? "") == "rounds" }
    
    @Environment(\.dismiss) private var dismiss

    // MARK: - Server-Driven Values (no client computation!)
    
    private var currentMatch: DuelMatch { viewModel.match ?? match }
    
    // Names from server perspective
    private var myDisplayName: String { currentMatch.myName }
    private var opponentDisplayName: String { currentMatch.opponentName }
    
    // Stats from server perspective
    private var myAttack: Int { currentMatch.myAttack }
    private var myDefense: Int { currentMatch.myDefense }
    private var opponentAttack: Int { currentMatch.opponentAttack }
    private var opponentDefense: Int { currentMatch.opponentDefense }
    
    // Colors (fixed - you're always blue, opponent is always red)
    private var myColor: Color { KingdomTheme.Colors.royalBlue }
    private var enemyColor: Color { KingdomTheme.Colors.royalCrimson }

    // Odds from server (for current attacker) - NO HARDCODED DEFAULTS
    private var oddsLoaded: Bool { currentMatch.currentOdds != nil || viewModel.odds.isLoaded }
    private var missChance: Int { currentMatch.currentOdds?.miss ?? viewModel.odds.miss ?? 0 }
    private var hitChance: Int { currentMatch.currentOdds?.hit ?? viewModel.odds.hit ?? 0 }
    private var critChance: Int { currentMatch.currentOdds?.crit ?? viewModel.odds.crit ?? 0 }

    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()

            // Always show main content - result overlay goes on top after animation
            mainContent
            
            // Push flash overlay - dramatic feedback when bar moves
            if pushFlash {
                let flashColor = pushDirection > 0 ? myColor : enemyColor
                flashColor.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Turn banner POPUP overlay (controlled by event queue in ViewModel)
            if viewModel.showTurnBanner {
                turnBannerPopup
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(50)
            }
            
            // Show result overlay only after animations/queue complete
            if currentMatch.isComplete, let winner = currentMatch.winnerPerspective, !viewModel.isAnimating {
                resultOverlay(winner: winner)
            }
            
            // Critical hit popup overlay
            if showCritPopup, let data = critPopupData {
                criticalHitPopup(data: data)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
            
            // Style reveal overlay (shows both styles before push)
            if viewModel.showStyleReveal, let data = viewModel.styleRevealData {
                styleRevealOverlay(data: data)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(55)
            }
            
            // Push popup overlay (shows bar push dramatically)
            if viewModel.showPushPopup, let data = viewModel.pushPopupData {
                pushPopupOverlay(data: data)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(60)
            }
            
            // Forfeit confirmation overlay
            if showForfeitConfirmation {
                forfeitConfirmationOverlay
                    .transition(.opacity)
                    .zIndex(150)
            }
        }
        .navigationTitle("Duel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.load(match: match, playerId: playerId)
            // Use server-provided bar position
            animatedBarValue = currentMatch.yourBarPosition ?? 50
            // Initialize turn timer from SERVER's turn_expires_at (not hardcoded 30s)
            updateTimerFromServer()
        }
        // Animate when there's a roll to show
        .onChange(of: viewModel.currentRoll?.value) { _, _ in
            if viewModel.currentRoll != nil {
                Task { await animateRoll() }
            }
        }
        // Update bar when match changes - DRAMATIC push animation
        .onChange(of: currentMatch.yourBarPosition) { oldValue, newValue in
            let newVal = newValue ?? 50
            let oldVal = oldValue ?? 50
            let pushAmount = newVal - oldVal
            
            // Only animate if there's a meaningful change
            if abs(pushAmount) > 0.1 {
                // Track push direction for color effects
                pushDirection = pushAmount > 0 ? 1 : -1
                let myPush = pushAmount > 0
                
                // STAGE 1: Character push animation + flash (immediate)
                triggerPushAnimation(myPush: myPush)
                withAnimation(.easeOut(duration: 0.1)) {
                    pushFlash = true
                    barPulse = true
                }
                
                // STAGE 2: Bar movement (slightly delayed for anticipation)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // Slower, bouncier animation for dramatic effect
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.2)) {
                        animatedBarValue = newVal
                    }
                }
                
                // STAGE 3: Flash fades
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        pushFlash = false
                    }
                }
                
                // STAGE 4: End pulse (after bar settles)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        barPulse = false
                    }
                }
            }
        }
        // Turn timer - recalculate from server's turn_expires_at when match updates
        .onChange(of: currentMatch.turnExpiresAt) { _, _ in
            updateTimerFromServer()
        }
        // Round timer (new system)
        .onChange(of: currentMatch.roundExpiresAt) { _, _ in
            updateTimerFromServer()
        }
        // Also update when turn changes (backup if turnExpiresAt didn't change)
        .onChange(of: currentMatch.isYourTurn) { _, _ in
            updateTimerFromServer()
        }
        // Countdown timer
        .onReceive(timer) { _ in
            guard currentMatch.isFighting && !viewModel.isAnimating else { return }
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
    }
    
    // MARK: - Timer from Server
    
    /// Calculate remaining seconds from server's turn_expires_at
    /// This ensures correct timeout state on reconnect and after opponent swings
    private func updateTimerFromServer() {
        timerActive = currentMatch.isFighting

        let expiresAtStr: String? = {
            if isRoundMode {
                return currentMatch.roundExpiresAt ?? currentMatch.turnExpiresAt
            }
            return currentMatch.turnExpiresAt
        }()

        guard let expiresAtStr else {
            // No expiration set, use default
            secondsRemaining = isRoundMode ? roundTimeout : turnTimeout
            return
        }
        
        // Parse ISO8601 date from server
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try with fractional seconds first, then without
        var expiresAt: Date? = formatter.date(from: expiresAtStr)
        if expiresAt == nil {
            formatter.formatOptions = [.withInternetDateTime]
            expiresAt = formatter.date(from: expiresAtStr)
        }
        
        guard let expiry = expiresAt else {
            secondsRemaining = isRoundMode ? roundTimeout : turnTimeout
            return
        }
        
        // Calculate remaining time (can be negative if already expired)
        let remaining = expiry.timeIntervalSinceNow
        secondsRemaining = max(0, Int(remaining))
    }
    
    // MARK: - Roll Animation
    
    @MainActor
    private func animateRoll() async {
        guard let roll = viewModel.currentRoll else { return }
        
        // Trigger character swing animation
        let isMySwing = (roll.attackerName ?? "") == currentMatch.myName
        triggerSwingAnimation(isMySwing: isMySwing, outcome: roll.outcome)
        
        showRollMarker = true
        let target = max(1, min(100, roll.value))
        
        // Build animation path: sweep 0→100, then back down to target (like BattleFightView)
        var positions: [Int] = []
        for i in stride(from: 0, through: 100, by: 3) { positions.append(i) }
        if target < 100 {
            for i in stride(from: 98, through: target, by: -3) { positions.append(i) }
        }
        if positions.last != target { positions.append(target) }
        
        // Animate through positions
        let sweepNanos = UInt64(rollSweepStepMs) * 1_000_000
        for pos in positions {
            rollDisplayValue = pos
            try? await Task.sleep(nanoseconds: sweepNanos)
        }
        rollDisplayValue = target
        
        // Hold on result
        let holdNanos = UInt64(gameConfig?.rollAnimationMs ?? 300) * 1_000_000
        try? await Task.sleep(nanoseconds: holdNanos)
        
        showRollMarker = false
        
        // Signal animation complete - queue will continue processing
        viewModel.finishCurrentRoll()
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    compactHeader
                    duelArenaView
                    heroControlBar
                    
                    // Style selection (shown during style phase)
                    if currentMatch.inStylePhase == true || currentMatch.canLockStyle == true {
                        styleSelectionCard
                    }
                    
                    probabilityBar
                    turnSwingsCard
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.top, KingdomTheme.Spacing.small)
                .padding(.bottom, KingdomTheme.Spacing.large)
            }
            .background(KingdomTheme.Colors.parchment)
            
            bottomButtons
        }
    }
    
    // MARK: - Style Selection Card
    
    private var styleSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timer
            HStack {
                Text("CHOOSE YOUR STYLE")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                // Style phase timer
                if let expiresAt = currentMatch.styleLockExpiresAt {
                    StylePhaseTimer(expiresAt: expiresAt)
                }
            }
            
            // Locked status
            if currentMatch.myStyleLocked == true {
                if let myStyle = currentMatch.myStyle {
                    let styleName = gameConfig?.attackStyles?.first(where: { $0.id == myStyle })?.name ?? myStyle.capitalized
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(myColor)
                        Text("Locked: \(styleName)")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(myColor)
                    }
                }
            } else {
                // Style selection grid (from server config)
                if let styles = gameConfig?.attackStyles {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(styles) { style in
                            StyleButton(style: style, isSelected: currentMatch.myStyle == style.id, myColor: myColor) {
                                Task { await viewModel.lockStyle(style.id) }
                            }
                            .disabled(currentMatch.myStyleLocked == true || viewModel.isAnimating)
                        }
                    }
                } else {
                    Text("Loading styles...")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            
            // Opponent status
            HStack {
                Circle()
                    .fill(currentMatch.opponentStyleLocked == true ? myColor : KingdomTheme.Colors.inkLight)
                    .frame(width: 8, height: 8)
                Text(currentMatch.opponentStyleLocked == true ? "\(opponentDisplayName) locked in!" : "\(opponentDisplayName) choosing...")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    // MARK: - Compact Header
    
    /// Computed status for the round header
    private var roundStatus: (text: String, color: Color) {
        let roundNum = currentMatch.roundNumber ?? 1
        let hasSubmitted = currentMatch.hasSubmittedRound ?? false
        let inStylePhase = currentMatch.inStylePhase ?? false
        let myStyleLocked = currentMatch.myStyleLocked ?? false
        
        if inStylePhase && !myStyleLocked {
            return ("ROUND \(roundNum) — PICK STYLE", KingdomTheme.Colors.imperialGold)
        } else if inStylePhase && myStyleLocked {
            return ("ROUND \(roundNum) — STYLE LOCKED", myColor)
        } else if hasSubmitted {
            return ("ROUND \(roundNum) — WAITING", enemyColor)
        } else {
            return ("ROUND \(roundNum) — SUBMIT", myColor)
        }
    }
    
    private var compactHeader: some View {
        HStack {
            // Round indicator (shows phase: style selection or swing submission)
            HStack(spacing: 6) {
                Circle()
                    .fill(roundStatus.color)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 1.5)
                    )
                    .shadow(color: roundStatus.color.opacity(0.6), radius: 4)
                
                Text(roundStatus.text)
                    .font(FontStyles.labelBold)
                    .foregroundColor(roundStatus.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(roundStatus.color.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
            )
            
            Spacer()
            
            // Timer
            if currentMatch.isFighting {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(secondsRemaining)s")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                }
                .foregroundColor(secondsRemaining <= 10 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium)
            }
            
            // Close button
            Button(action: { onComplete() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(KingdomTheme.Colors.parchmentLight).overlay(Circle().stroke(Color.black, lineWidth: 2)))
            }
        }
    }
    
    // MARK: - Hero Control Bar
    
    private var heroControlBar: some View {
        VStack(spacing: 12) {
            // Percentage display - big and centered
            Text("\(Int(animatedBarValue))%")
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundColor(animatedBarValue >= 50 ? myColor : enemyColor)
                .scaleEffect(barPulse ? 1.15 : 1.0)
                .shadow(color: barPulse ? (animatedBarValue >= 50 ? myColor : enemyColor).opacity(0.5) : .clear, radius: barPulse ? 10 : 0)
            
            // The big control bar
            DuelControlBar(
                value: animatedBarValue,
                myColor: myColor,
                enemyColor: enemyColor,
                isPulsing: barPulse
            )
            .frame(height: 44)
            
            // Win condition hint
            Text(animatedBarValue >= 50 ? "Push to 100% to win!" : "Opponent is winning!")
                .font(FontStyles.labelBadge)
                .foregroundColor(animatedBarValue >= 50 ? KingdomTheme.Colors.inkMedium : enemyColor)
        }
        .padding(16)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    // MARK: - Animated Duel Arena
    
    private var duelArenaView: some View {
        HStack(spacing: 0) {
            // YOUR CHARACTER (left side)
            VStack(spacing: 6) {
                // Name
                Text(myDisplayName)
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                
                ZStack {
                    // Swing trail effect
                    if myCharacterSwinging {
                        Image(systemName: "wind")
                            .font(.system(size: 20))
                            .foregroundColor(myColor.opacity(0.6))
                            .offset(x: -20, y: 5)
                            .transition(.opacity)
                    }
                    
                    // Character
                    Image(systemName: "figure.fencing")
                        .font(.system(size: 44))
                        .foregroundColor(myColor)
                        .shadow(color: myCharacterSwinging ? myColor : .clear, radius: myCharacterSwinging ? 12 : 0)
                        .rotationEffect(.degrees(myCharacterSwinging ? 20 : 0), anchor: .bottom)
                        .offset(x: myCharacterSwinging ? 25 : (myCharacterPushing ? 35 : 0))
                        .scaleEffect(myCharacterPushing ? 1.15 : 1.0)
                }
                .frame(height: 55)
                
                // Stats
                HStack(spacing: 6) {
                    Label("\(myAttack)", systemImage: "burst.fill")
                    Label("\(myDefense)", systemImage: "shield.fill")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity)
            
            // Center clash zone
            ZStack {
                if showImpact {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 14 + CGFloat(i) * 4))
                            .foregroundColor(outcomeColor)
                            .shadow(color: outcomeColor, radius: 6)
                            .rotationEffect(.degrees(Double(i) * 30))
                            .scaleEffect(showImpact ? 1.0 : 0.3)
                            .opacity(showImpact ? 1.0 : 0)
                    }
                }
            }
            .frame(width: 30)
            
            // ENEMY CHARACTER (right side)
            VStack(spacing: 6) {
                // Name
                Text(opponentDisplayName)
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                
                ZStack {
                    // Swing trail effect
                    if enemyCharacterSwinging {
                        Image(systemName: "wind")
                            .font(.system(size: 20))
                            .foregroundColor(enemyColor.opacity(0.6))
                            .offset(x: 20, y: 5)
                            .scaleEffect(x: -1, y: 1)
                            .transition(.opacity)
                    }
                    
                    // Character (facing left)
                    Image(systemName: "figure.fencing")
                        .font(.system(size: 44))
                        .foregroundColor(enemyColor)
                        .scaleEffect(x: -1, y: 1)
                        .shadow(color: enemyCharacterSwinging ? enemyColor : .clear, radius: enemyCharacterSwinging ? 12 : 0)
                        .rotationEffect(.degrees(enemyCharacterSwinging ? -20 : 0), anchor: .bottom)
                        .offset(x: enemyCharacterSwinging ? -25 : (enemyCharacterPushing ? -35 : 0))
                        .scaleEffect(enemyCharacterPushing ? 1.15 : 1.0)
                }
                .frame(height: 55)
                
                // Stats
                HStack(spacing: 6) {
                    Label("\(opponentAttack)", systemImage: "burst.fill")
                    Label("\(opponentDefense)", systemImage: "shield.fill")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    private var outcomeColor: Color {
        // Match the probability bar colors
        let isYourTurn = currentMatch.isYourTurn ?? false
        let baseColor = isYourTurn ? myColor : enemyColor
        let outcome = lastOutcome.lowercased()
        
        switch outcome {
        case "critical", "crit": return baseColor
        case "hit": return baseColor.opacity(0.8)
        default: return Color(white: 0.4)  // Gray for miss
        }
    }
    
    /// Trigger swing animation for the current attacker
    private func triggerSwingAnimation(isMySwing: Bool, outcome: String) {
        lastOutcome = outcome
        
        withAnimation(.easeOut(duration: 0.15)) {
            if isMySwing {
                myCharacterSwinging = true
            } else {
                enemyCharacterSwinging = true
            }
        }
        
        // Show impact at peak of swing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.1)) {
                showImpact = true
            }
        }
        
        // Return to rest
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                myCharacterSwinging = false
                enemyCharacterSwinging = false
            }
        }
        
        // Hide impact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showImpact = false
            }
        }
    }
    
    /// Trigger push animation when bar moves
    private func triggerPushAnimation(myPush: Bool) {
        withAnimation(.easeOut(duration: 0.2)) {
            if myPush {
                myCharacterPushing = true
            } else {
                enemyCharacterPushing = true
            }
            showImpact = true
        }
        
        // Hold the push
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                myCharacterPushing = false
                enemyCharacterPushing = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                showImpact = false
            }
        }
    }
    
    // MARK: - Turn Banner Popup
    
    private var turnBannerPopup: some View {
        let isYourTurn = currentMatch.isYourTurn ?? false
        let bannerColor = isYourTurn ? myColor : enemyColor
        
        return ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Icon
                Image(systemName: isYourTurn ? "figure.fencing" : "hourglass")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .shadow(color: bannerColor, radius: 10)
                
                // Title
                Text(isYourTurn ? "YOUR TURN!" : "OPPONENT'S TURN")
                    .font(FontStyles.displaySmall)
                    .foregroundColor(.white)
                
                // Subtitle
                Text(isYourTurn ? "Strike while they're vulnerable!" : "Brace yourself...")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(bannerColor.opacity(0.95))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            )
            .scaleEffect(viewModel.turnBannerScale)
        }
    }
    
    // MARK: - Combatants Card
    
    // MARK: - Probability Bar
    
    private var probabilityBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text(barTitle)
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                if !oddsLoaded {
                    Text("Loading...")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                } else if showRollMarker {
                    Text("Rolled: \(rollDisplayValue)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(markerColor(rollDisplayValue))
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Gradient-filled sections like the hero bar
                    HStack(spacing: 0) {
                        // Miss zone - dark gray gradient
                        LinearGradient(
                            colors: [Color(white: 0.4), Color(white: 0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        
                        // Hit zone - medium color
                        LinearGradient(
                            colors: [displayBarColor.opacity(0.8), displayBarColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        
                        // Crit zone - bright color
                        LinearGradient(
                            colors: [displayBarColor, displayBarColor.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Border
                    RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2.5)
                    
                    // Labels
                    HStack(spacing: 0) {
                        Text("MISS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        Text("HIT")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        Text("CRIT")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Roll marker - color based on outcome (gray for miss, player color for hit/crit)
                    if showRollMarker {
                        marker(value: rollDisplayValue, color: markerColor(rollDisplayValue), geo: geo)
                    }
                }
            }
            .frame(height: 28)
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private var barTitle: String {
        if viewModel.isAnimating {
            if let roll = viewModel.currentRoll, let name = roll.attackerName {
                return "\(name.uppercased()) ROLLING..."
            }
            return "ROLLING..."
        }
        return "YOUR SWING ODDS"
    }
    
    private var displayBarColor: Color {
        // Round system: marker color should reflect WHO is rolling, not "turn"
        if let roll = viewModel.currentRoll, let attacker = roll.attackerName {
            return attacker == currentMatch.myName ? myColor : enemyColor
        }
        return myColor
    }
    
    private func markerColor(_ value: Int) -> Color {
        // Use the ACTUAL outcome from the server - NO client-side calculation
        guard let roll = viewModel.currentRoll else {
            return Color(white: 0.35)  // Default gray if no roll
        }
        
        let outcome = roll.outcome.lowercased()
        switch outcome {
        case "critical", "crit":
            return displayBarColor  // Bright player color
        case "hit":
            return displayBarColor.opacity(0.8)  // Slightly faded
        default:
            return Color(white: 0.35)  // Gray for miss
        }
    }
    
    private func marker(value: Int, color: Color, geo: GeometryProxy) -> some View {
        // INVERT: Server uses low roll = crit (good), high roll = miss (bad)
        // So we invert to display correctly: low value -> right (crit zone), high value -> left (miss zone)
        let invertedValue = 100 - value
        let x = geo.size.width * CGFloat(invertedValue) / 100.0
        return Group {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .shadow(color: .black, radius: 0, x: 1, y: 1)
                .position(x: max(12, min(geo.size.width - 12, x)), y: -4)
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 28)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                .position(x: max(12, min(geo.size.width - 12, x)), y: 14)
        }
    }
    
    // MARK: - Round Reveal Card
    
    private var turnSwingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let roundNum = currentMatch.roundNumber ?? 1
            Text("ROUND \(roundNum)")
                .font(FontStyles.labelBadge)
                .foregroundColor(KingdomTheme.Colors.inkMedium)

            // YOU
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("YOU").font(FontStyles.labelBold).foregroundColor(KingdomTheme.Colors.inkDark)
                    Spacer()
                    if currentMatch.hasSubmittedRound == true {
                        Text("SUBMITTED").font(FontStyles.labelBadge).foregroundColor(myColor)
                    }
                }

                if viewModel.myDisplayedRoundRolls.isEmpty {
                    Text("Waiting for reveal…")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(viewModel.myDisplayedRoundRolls.enumerated()), id: \.offset) { index, roll in
                                rollBadge(roll: roll, index: index + 1, color: myColor)
                            }
                        }.padding(.horizontal, 4)
                    }
                }
            }

            // OPPONENT
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(opponentDisplayName.uppercased())
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    Spacer()
                    if currentMatch.opponentHasSubmittedRound == true {
                        Text("SUBMITTED").font(FontStyles.labelBadge).foregroundColor(enemyColor)
                    }
                }

                if viewModel.opponentDisplayedRoundRolls.isEmpty {
                    Text("Waiting for reveal…")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(viewModel.opponentDisplayedRoundRolls.enumerated()), id: \.offset) { index, roll in
                                rollBadge(roll: roll, index: index + 1, color: enemyColor)
                            }
                        }.padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private func rollBadge(roll: Roll, index: Int, color: Color) -> some View {
        // Colors match the probability bar: crit = bright color, hit = medium color, miss = gray
        let badgeColor: Color
        let icon: String
        let hasGlow: Bool
        let outcome = roll.outcome.lowercased()
        
        switch outcome {
        case "critical", "crit":
            badgeColor = color  // Bright player color (same as crit zone on bar)
            icon = "flame.fill"
            hasGlow = true
        case "hit":
            badgeColor = color.opacity(0.75)  // Slightly faded player color (same as hit zone on bar)
            icon = "checkmark.circle.fill"
            hasGlow = false
        default:  // "miss" or anything else
            badgeColor = Color(white: 0.35)  // Dark gray (same as miss zone on bar)
            icon = "xmark"
            hasGlow = false
        }
        
        return VStack(spacing: 4) {
            ZStack {
                // Glow for crits
                if hasGlow {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.4))
                        .frame(width: 52, height: 52)
                        .blur(radius: 6)
                }
                
                // Shadow
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                    .offset(x: 2, y: 2)
                
                // Main badge with gradient
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [badgeColor, badgeColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    Text("\(roll.value)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: 52, height: 52)
            
            Text("#\(index)")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    
    // MARK: - Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black).frame(height: 3)
            Group {
                if currentMatch.isWaiting {
                    HStack {
                        ProgressView().tint(myColor)
                        Text("Waiting for opponent...").font(FontStyles.labelMedium).foregroundColor(KingdomTheme.Colors.inkMedium)
                        Spacer()
                        Button("Cancel") { Task { await viewModel.cancel(); dismiss() } }.font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                } else if currentMatch.isReady {
                    Button { Task { await viewModel.startMatch() } } label: {
                        HStack { Image(systemName: "figure.fencing"); Text("Start Duel") }.frame(maxWidth: .infinity)
                    }.buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, foregroundColor: .white, fullWidth: true))
                } else if currentMatch.isFighting {
                    // Round system: use server-provided values ONLY
                    let canSubmitRound = currentMatch.canSubmitRound ?? (currentMatch.canAttack ?? false)
                    let hasSubmittedRound = currentMatch.hasSubmittedRound ?? false
                    let rollsThisRound = currentMatch.yourRoundRollsCount ?? (currentMatch.yourSwingsRemaining ?? 0)

                    let buttonText = hasSubmittedRound ? "Submitted… Waiting" : "Swing! (\(rollsThisRound) rolls)"
                    // Use server-provided can_claim_timeout ONLY
                    let canClaimTimeout = (currentMatch.canClaimTimeout ?? false) && !viewModel.isAnimating
                    
                    if canClaimTimeout {
                        // Opponent timed out - show claim button
                        Button { Task { await viewModel.claimTimeout() } } label: {
                            HStack { 
                                Image(systemName: "clock.badge.exclamationmark")
                                Text("\(opponentDisplayName) timed out! Claim Victory")
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, foregroundColor: .white, fullWidth: true))
                    } else {
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            Button { Task { await viewModel.submitRoundSwing() } } label: {
                                HStack { Image(systemName: "figure.fencing"); Text(buttonText) }.frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.brutalist(backgroundColor: (canSubmitRound && !hasSubmittedRound && !viewModel.isAnimating) ? myColor : KingdomTheme.Colors.disabled, foregroundColor: .white, fullWidth: true))
                            .disabled(!(canSubmitRound && !hasSubmittedRound && !viewModel.isAnimating))
                            
                            Button { showForfeitConfirmation = true } label: {
                                HStack { Image(systemName: "flag.fill"); Text("Forfeit") }.frame(maxWidth: .infinity)
                            }.buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonDanger.opacity(0.8), foregroundColor: .white, fullWidth: true))
                        }
                    }
                } else {
                    Button { onComplete(); dismiss() } label: {
                        HStack { Text("Continue"); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
                    }.buttonStyle(.brutalist(backgroundColor: myColor, foregroundColor: .white, fullWidth: true))
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }.background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Result Overlay
    
    private func resultOverlay(winner: DuelWinnerPerspective) -> some View {
        let didWin = winner.didIWin ?? false
        let resultColor = didWin ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        let wagerAmount = currentMatch.wagerGold
        
        return ZStack {
            // Darkened background
            Color.black.opacity(0.7).ignoresSafeArea()
            
            // Parchment card
            VStack(spacing: 20) {
                // Trophy/Shield icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(resultColor.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Image(systemName: didWin ? "trophy.fill" : "xmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(resultColor)
                        .frame(width: 90, height: 90)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black)
                                    .offset(x: 3, y: 3)
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(KingdomTheme.Colors.parchmentLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.black, lineWidth: 3)
                                    )
                            }
                        )
                }
                
                // Title
                Text(didWin ? "VICTORY!" : "DEFEAT")
                    .font(.system(size: 32, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Subtitle
                Text(didWin ? "You dominated the arena!" : "Better luck next time...")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Divider
                Rectangle()
                    .fill(KingdomTheme.Colors.inkLight.opacity(0.3))
                    .frame(height: 2)
                    .padding(.horizontal, 20)
                
                // Gold spoils section
                VStack(spacing: 12) {
                    Text("SPOILS")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(didWin ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.buttonDanger)
                        
                        if didWin {
                            Text("+\(wagerAmount) gold")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                        } else {
                            Text("-\(wagerAmount) gold")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(didWin ? KingdomTheme.Colors.imperialGold.opacity(0.15) : KingdomTheme.Colors.buttonDanger.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(didWin ? KingdomTheme.Colors.imperialGold.opacity(0.3) : KingdomTheme.Colors.buttonDanger.opacity(0.3), lineWidth: 2)
                            )
                    )
                }
                
                // Continue button
                Button(action: { onComplete(); dismiss() }) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: resultColor, foregroundColor: .white, fullWidth: true))
                .padding(.top, 8)
            }
            .padding(30)
            .background(
                ZStack {
                    // Offset shadow
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(x: 5, y: 5)
                    
                    // Main card
                    RoundedRectangle(cornerRadius: 20)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 3)
                        )
                }
            )
            .padding(.horizontal, 30)
        }
    }
    
    // MARK: - Forfeit Confirmation Overlay
    
    private var forfeitConfirmationOverlay: some View {
        ZStack {
            // Darkened background
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { showForfeitConfirmation = false }
            
            // Confirmation card
            VStack(spacing: 20) {
                // Warning icon
                Image(systemName: "flag.fill")
                    .font(.system(size: 40))
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    .frame(width: 70, height: 70)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                                .offset(x: 2, y: 2)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(KingdomTheme.Colors.buttonDanger.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                    )
                
                // Title
                Text("FORFEIT DUEL?")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Warning text
                VStack(spacing: 8) {
                    Text("You will lose this duel and forfeit")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        Text("\(currentMatch.wagerGold) gold")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                }
                .multilineTextAlignment(.center)
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        showForfeitConfirmation = false
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.disabled, foregroundColor: .white, fullWidth: true))
                    
                    Button {
                        showForfeitConfirmation = false
                        Task { await viewModel.forfeit() }
                    } label: {
                        HStack {
                            Image(systemName: "flag.fill")
                            Text("Forfeit")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonDanger, foregroundColor: .white, fullWidth: true))
                }
            }
            .padding(24)
            .background(
                ZStack {
                    // Offset shadow
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(x: 4, y: 4)
                    
                    // Main card
                    RoundedRectangle(cornerRadius: 20)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 3)
                        )
                }
            )
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Critical Hit Popup
    
    private func criticalHitPopup(data: CritPopupData) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { dismissCritPopup() }
            
            VStack(spacing: 16) {
                // Flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .shadow(color: .red, radius: 10)
                
                Text("CRITICAL HIT!")
                    .font(FontStyles.displaySmall)
                    .foregroundColor(.white)
                
                Text("\(data.attackerName.uppercased()) landed a devastating blow!")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                // Push amount
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(myColor)
                    Text("+\(Int(data.pushAmount))% BAR PUSH")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(myColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .brutalistBadge(backgroundColor: Color.black.opacity(0.5), cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                
                // Critical bonus indicator (from server config!)
                Text("\(gameConfig?.criticalMultiplierText ?? "1.5x") CRITICAL BONUS")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(.orange)
            }
            .padding(30)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.inkDark.opacity(0.95), cornerRadius: 20)
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Auto-dismiss timing from server config
            let dismissDelay = Double(critPopupDurationMs) / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                dismissCritPopup()
            }
        }
    }
    
    private func dismissCritPopup() {
        withAnimation(.easeOut(duration: 0.2)) {
            showCritPopup = false
            critPopupData = nil
        }
    }
    
    private func showCriticalHit(attackerName: String, pushAmount: Double) {
        critPopupData = CritPopupData(attackerName: attackerName, pushAmount: pushAmount)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCritPopup = true
        }
    }
    
    // MARK: - Style Reveal Overlay
    
    private func styleRevealOverlay(data: StyleRevealData) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("STYLE REVEAL")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 30) {
                    // Your style
                    VStack(spacing: 8) {
                        Text("YOU")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(.white.opacity(0.7))
                        
                        styleIconView(styleName: data.myStyle, color: myColor)
                        
                        Text(data.myStyleName)
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                    }
                    
                    Text("VS")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Opponent style
                    VStack(spacing: 8) {
                        Text(opponentDisplayName.uppercased())
                            .font(FontStyles.labelBadge)
                            .foregroundColor(.white.opacity(0.7))
                        
                        styleIconView(styleName: data.opponentStyle, color: enemyColor)
                        
                        Text(data.opponentStyleName)
                            .font(FontStyles.labelBold)
                            .foregroundColor(.white)
                    }
                }
                
                // Feint winner indicator
                if let feint = data.feintWinner {
                    let feintWinnerName = feint == "challenger" ? 
                        (currentMatch.challenger.id == playerId ? "YOU" : opponentDisplayName) :
                        (currentMatch.opponent?.id == playerId ? "YOU" : opponentDisplayName)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.yellow)
                        Text("\(feintWinnerName) WINS TIE WITH FEINT!")
                            .font(FontStyles.labelBold)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.2))
                    )
                }
            }
            .padding(30)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(KingdomTheme.Colors.inkDark.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                }
            )
        }
    }
    
    /// Get icon for a style (from server config or fallback)
    private func styleIconView(styleName: String, color: Color) -> some View {
        // Get icon from server config if available
        let icon = gameConfig?.attackStyles?.first(where: { $0.id == styleName })?.icon ?? "equal.circle.fill"
        
        return Image(systemName: icon)
            .font(.system(size: 40))
            .foregroundColor(.white)
            .frame(width: 70, height: 70)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            )
    }
    
    // MARK: - Push Popup Overlay
    
    private func pushPopupOverlay(data: PushPopupData) -> some View {
        let isBlocked = abs(data.pushAmount) < 0.1  // No push = blocked
        let isGoodPush = data.pushAmount > 0
        
        // Colors and content based on outcome
        let popupColor: Color
        let popupIcon: String
        let title: String
        let subtitle: String
        let amountText: String
        
        if isBlocked {
            // PARRIED - gray, shield icon
            popupColor = Color(white: 0.4)
            popupIcon = "shield.fill"
            title = "PARRIED!"
            subtitle = "No ground gained"
            amountText = "0%"
        } else if isGoodPush {
            // YOU PUSHED - your color
            popupColor = myColor
            popupIcon = "arrow.right.circle.fill"
            title = "PUSHED!"
            subtitle = "You gain ground!"
            amountText = "+\(String(format: "%.1f", abs(data.pushAmount)))%"
        } else {
            // PUSHED BACK - enemy color
            popupColor = enemyColor
            popupIcon = "arrow.left.circle.fill"
            title = "PUSHED BACK!"
            subtitle = "\(opponentDisplayName) gains ground!"
            amountText = "-\(String(format: "%.1f", abs(data.pushAmount)))%"
        }
        
        return ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Icon
                Image(systemName: popupIcon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .shadow(color: popupColor, radius: 15)
                
                // Title
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundColor(.white)
                
                // Subtitle
                Text(subtitle)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(.white.opacity(0.9))
                
                // Push amount
                Text(amountText)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    )
            }
            .padding(30)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(popupColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 3)
                        )
                }
            )
            .scaleEffect(viewModel.showPushPopup ? 1.0 : 0.8)
        }
    }
}

// MARK: - Push Popup Data
struct PushPopupData {
    let pushAmount: Double  // Positive = you pushed, negative = opponent pushed
    let outcome: String     // hit, critical, miss
}

// MARK: - Style Reveal Data
struct StyleRevealData {
    let myStyle: String
    let opponentStyle: String
    let myStyleName: String
    let opponentStyleName: String
    let feintWinner: String?  // If feint broke a tie
}

// MARK: - Critical Hit Data
struct CritPopupData {
    let attackerName: String
    let pushAmount: Double
}

// MARK: - Roll
/// Roll from server - simple data
struct Roll {
    let value: Int        // 0-100
    let outcome: String   // hit/miss/critical
    let attackerName: String?  // Who made this roll
    var swingNumber: Int = 1   // Which swing this is (1, 2, 3...)
}

/// Odds from server (NO DEFAULT VALUES - must come from server!)
struct Odds {
    var miss: Int?
    var hit: Int?
    var crit: Int?
    
    var isLoaded: Bool {
        miss != nil && hit != nil && crit != nil
    }
}

// MARK: - ViewModel
/// 
/// EVENT QUEUE ARCHITECTURE:
/// - All events (API responses, WebSocket) go into a single queue
/// - Events processed one at a time, in order
/// - If event has a roll, animate it fully before processing next event
/// - Simple, predictable, no race conditions
///
@MainActor
class DuelCombatViewModel: ObservableObject {
    @Published var match: DuelMatch?
    @Published var errorMessage: String?
    
    // Animation state
    @Published var currentRoll: Roll?
    @Published var isAnimating: Bool = false
    @Published var myDisplayedRoundRolls: [Roll] = []
    @Published var opponentDisplayedRoundRolls: [Roll] = []
    
    // Turn banner (controlled by event queue)
    @Published var showTurnBanner: Bool = false
    @Published var turnBannerScale: CGFloat = 1.0
    
    // Push popup (controlled by event queue)
    @Published var showPushPopup: Bool = false
    @Published var pushPopupData: PushPopupData? = nil
    
    // Style reveal popup (shows both styles after round resolution)
    @Published var showStyleReveal: Bool = false
    @Published var styleRevealData: StyleRevealData? = nil
    
    // Odds from server
    @Published var odds = Odds()
    
    // === EVENT QUEUE ===
    private var eventQueue: [DuelQueuedEvent] = []
    private var isProcessingQueue = false
    
    private let api = DuelsAPI()
    private var matchId: Int?
    private var playerId: Int?
    private var cancellables = Set<AnyCancellable>()
    
    // Continuation for waiting on animation completion
    private var animationContinuation: CheckedContinuation<Void, Never>?
    
    func load(match: DuelMatch, playerId: Int) async {
        self.match = match
        self.matchId = match.id
        self.playerId = playerId
        
        if let matchOdds = match.currentOdds {
            odds = Odds(miss: matchOdds.miss, hit: matchOdds.hit, crit: matchOdds.crit)
        }
        
        subscribeToEvents()
    }
    
    private func subscribeToEvents() {
        GameEventManager.shared.duelEventSubject
            .receive(on: DispatchQueue.main)
            .filter { [weak self] e in e.matchId == self?.matchId }
            .sink { [weak self] e in self?.enqueueWebSocketEvent(e) }
            .store(in: &cancellables)
    }
    
    // === QUEUE MANAGEMENT ===
    
    private func enqueueWebSocketEvent(_ event: DuelEvent) {
        // Legacy swing events
        if event.eventType == .swing,
           let rollData = event.data["roll"] as? [String: Any],
           let attackerName = event.data["attacker_name"] as? String,
           let value = rollData["value"] as? Double {
            let outcome = rollData["outcome"] as? String ?? "miss"
            let swingNumber = event.data["swing_number"] as? Int ?? 1
            let roll = Roll(value: Int(value), outcome: outcome, attackerName: attackerName, swingNumber: swingNumber)
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: roll, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil))
            processQueue()
            return
        }
        
        // Style locked - just update match state (opponent locked their style)
        if event.eventType == .styleLocked {
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil))
            processQueue()
            return
        }

        // New round system events
        if event.eventType == .roundResolved || event.eventType == .ended {
            let challengerName = event.data["challenger_name"] as? String
            let opponentName = event.data["opponent_name"] as? String

            let challengerRolls = event.data["challenger_rolls"] as? [[String: Any]] ?? []
            let opponentRolls = event.data["opponent_rolls"] as? [[String: Any]] ?? []
            
            // Style reveal data
            let challengerStyle = event.data["challenger_style"] as? String
            let opponentStyleData = event.data["opponent_style"] as? String
            let resultDict = event.data["result"] as? [String: Any]
            let feintWinner = resultDict?["feint_winner"] as? String

            func decodeRolls(_ rs: [[String: Any]], attacker: String?) -> [Roll] {
                rs.compactMap { d in
                    guard let value = d["value"] as? Double else { return nil }
                    let outcome = d["outcome"] as? String ?? "miss"
                    let n = d["roll_number"] as? Int ?? 1
                    return Roll(value: Int(value), outcome: outcome, attackerName: attacker, swingNumber: n)
                }
            }

            let ch = decodeRolls(challengerRolls, attacker: challengerName)
            let op = decodeRolls(opponentRolls, attacker: opponentName)

            // Interleave reveal: best UX for “compare” feeling
            var reveal: [Roll] = []
            let maxLen = max(ch.count, op.count)
            for i in 0..<maxLen {
                if i < ch.count { reveal.append(ch[i]) }
                if i < op.count { reveal.append(op[i]) }
            }

            let parried = (resultDict?["parried"] as? Bool) ?? false
            let popupOutcome = parried ? "parried" : ((resultDict?["decisive_outcome"] as? String) ?? "hit")
            
            // Build style reveal if we have style data
            var styleReveal: StyleRevealData? = nil
            if let chStyle = challengerStyle, let opStyle = opponentStyleData {
                let isChallenger = match?.challenger.id == playerId
                let myStyle = isChallenger == true ? chStyle : opStyle
                let oppStyle = isChallenger == true ? opStyle : chStyle
                styleReveal = StyleRevealData(
                    myStyle: myStyle,
                    opponentStyle: oppStyle,
                    myStyleName: myStyle.replacingOccurrences(of: "_", with: " ").capitalized,
                    opponentStyleName: oppStyle.replacingOccurrences(of: "_", with: " ").capitalized,
                    feintWinner: feintWinner
                )
            }

            eventQueue.append(DuelQueuedEvent(
                match: event.match,
                roll: nil,
                rolls: reveal,
                clearRoundRolls: true,
                showRoundPopup: true,
                popupOutcome: popupOutcome,
                styleReveal: styleReveal
            ))
            processQueue()
            return
        }

        // Round submitted just updates state (so UI can show opponent submitted)
        eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil))
        processQueue()
    }
    
    private func enqueueAPIResponse(match: DuelMatch?) {
        eventQueue.append(DuelQueuedEvent(match: match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil))
        processQueue()
    }
    
    private func processQueue() {
        guard !isProcessingQueue else { return }
        guard !eventQueue.isEmpty else { return }
        
        isProcessingQueue = true
        
        Task {
            while !eventQueue.isEmpty {
                let event = eventQueue.removeFirst()
                await processEvent(event)
            }
            isProcessingQueue = false
        }
    }
    
    private func processEvent(_ event: DuelQueuedEvent) async {
        // Remember old bar position to detect changes
        let oldBarPosition = match?.yourBarPosition ?? 50.0

        if event.clearRoundRolls {
            myDisplayedRoundRolls = []
            opponentDisplayedRoundRolls = []
        }
        
        // STEP 1: Animate roll(s) if present
        let rollsToAnimate: [Roll] = {
            if let rs = event.rolls { return rs }
            if let r = event.roll { return [r] }
            return []
        }()

        for r in rollsToAnimate {
            currentRoll = r
            isAnimating = true
            await withCheckedContinuation { continuation in
                animationContinuation = continuation
            }
            try? await Task.sleep(nanoseconds: 800_000_000)  // 0.8 seconds to see result
        }
        
        // STEP 2: Update match state
        if let m = event.match {
            match = m
            if let matchOdds = m.currentOdds {
                odds = Odds(miss: matchOdds.miss, hit: matchOdds.hit, crit: matchOdds.crit)
            }
        }
        
        // STEP 3: Show style reveal if we have style data (before push popup)
        if let styleData = event.styleReveal {
            self.styleRevealData = styleData
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showStyleReveal = true
            }
            // Show for style reveal duration from config, or default 1.5s
            let revealDuration = match?.config?.styleRevealDurationMs ?? 1500
            try? await Task.sleep(nanoseconds: UInt64(revealDuration) * 1_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                self.showStyleReveal = false
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        
        // STEP 4: Show round result popup (push/parry) when requested
        let newBarPosition = match?.yourBarPosition ?? 50.0
        let pushAmount = newBarPosition - oldBarPosition
        
        if event.showRoundPopup && match?.isFighting == true {
            let outcome = event.popupOutcome ?? "hit"
            self.pushPopupData = PushPopupData(pushAmount: pushAmount, outcome: outcome)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showPushPopup = true
            }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                self.showPushPopup = false
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
    
    /// Called by view when roll animation completes
    func finishCurrentRoll() {
        if let roll = currentRoll {
            let isMe = (roll.attackerName ?? "") == (match?.myName ?? "")
            if isMe {
                myDisplayedRoundRolls.append(roll)
            } else {
                opponentDisplayedRoundRolls.append(roll)
            }
        }
        currentRoll = nil
        isAnimating = false
        
        // Resume queue processing
        animationContinuation?.resume()
        animationContinuation = nil
    }
    
    // === API CALLS ===
    
    func lockStyle(_ style: String) async {
        guard let matchId = matchId else { return }
        guard match?.canLockStyle == true && !isAnimating else { return }
        
        do {
            let r = try await api.lockStyle(matchId: matchId, style: style)
            if let m = r.match { 
                match = m 
                if let matchOdds = m.currentOdds {
                    odds = Odds(miss: matchOdds.miss, hit: matchOdds.hit, crit: matchOdds.crit)
                }
            }
            if !r.success { errorMessage = r.message }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitRoundSwing() async {
        guard let matchId = matchId else { return }
        guard match?.canSubmitRound == true && match?.hasSubmittedRound != true && !isAnimating && !isProcessingQueue else { return }
        
        do {
            let r = try await api.submitRoundSwing(matchId: matchId)
            // Sync match state immediately; reveal happens via WebSocket when both submitted
            if let m = r.match { enqueueAPIResponse(match: m) }
            if !r.success { errorMessage = r.message }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func startMatch() async {
        guard let matchId = matchId else { return }
        do {
            let r = try await api.startMatch(matchId: matchId)
            // Always update match if provided (even on failure - syncs client state)
            if let m = r.match { match = m }
        } catch { errorMessage = error.localizedDescription }
    }
    
    func cancel() async {
        guard let matchId = matchId else { return }
        do { _ = try await api.cancel(matchId: matchId) } catch {}
    }
    
    func forfeit() async {
        guard let matchId = matchId else { return }
        do { let r = try await api.forfeit(matchId: matchId); match = r.match } catch { errorMessage = error.localizedDescription }
    }
    
    func claimTimeout() async {
        guard let matchId = matchId else { return }
        do {
            let r = try await api.claimTimeout(matchId: matchId)
            // Always update match if provided (syncs client state)
            if let m = r.match { match = m }
            if !r.success { errorMessage = r.message }
        } catch { errorMessage = error.localizedDescription }
    }
    
    deinit { cancellables.removeAll() }
}

/// Event in the processing queue
struct DuelQueuedEvent {
    let match: DuelMatch?
    let roll: Roll?
    let rolls: [Roll]?
    let clearRoundRolls: Bool
    let showRoundPopup: Bool
    let popupOutcome: String?
    let styleReveal: StyleRevealData?
}

// MARK: - Duel Control Bar

/// The main tug-of-war bar for duels - animated and polished
struct DuelControlBar: View {
    let value: Double  // 0-100, where 100 = you winning
    let myColor: Color
    let enemyColor: Color
    var isPulsing: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let progress = min(1.0, max(0.0, value / 100.0))
            let myWidth = width * progress
            
            ZStack(alignment: .leading) {
                // Enemy side (background)
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [enemyColor.opacity(0.6), enemyColor.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Your side (foreground)
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [myColor.opacity(0.9), myColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: myWidth)
                
                // Animated stripes overlay
                DuelBarStripes()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(0.15)
                
                // Center line (50% mark)
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 2, height: height - 8)
                    .position(x: width / 2, y: height / 2)
                
                // Position marker (the slider knob)
                ZStack {
                    // Glow when pulsing
                    if isPulsing {
                        Circle()
                            .fill(value >= 50 ? myColor : enemyColor)
                            .frame(width: 24, height: 24)
                            .blur(radius: 8)
                    }
                    
                    // Main knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
                .position(x: max(12, min(width - 12, myWidth)), y: height / 2)
                
                // Border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 3)
            }
        }
    }
}

/// Animated diagonal stripes for the control bar
struct DuelBarStripes: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let stripeWidth: CGFloat = 20
            let stripeCount = Int(geo.size.width / stripeWidth) + 4
            
            HStack(spacing: 0) {
                ForEach(0..<stripeCount, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color.white : Color.clear)
                        .frame(width: stripeWidth)
                }
            }
            .frame(height: geo.size.height)
            .rotationEffect(.degrees(-45))
            .offset(x: offset - stripeWidth * 2)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    offset = stripeWidth * 2
                }
            }
        }
        .clipped()
    }
}

// MARK: - Style Button

/// A button for selecting an attack style - renders from server config
struct StyleButton: View {
    let style: AttackStyleConfig
    let isSelected: Bool
    let myColor: Color
    let action: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: style.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkDark)
                
                Text(style.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black)
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? myColor : KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? myColor : Color.black, lineWidth: 2)
                        )
                }
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.3) {
            showingDetails = true
        }
        .popover(isPresented: $showingDetails) {
            styleDetailsPopover
        }
    }
    
    private var styleDetailsPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: style.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(myColor)
                Text(style.name)
                    .font(FontStyles.headingSmall)
            }
            
            Text(style.description)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(style.effectsSummary, id: \.self) { effect in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(myColor)
                            .frame(width: 6, height: 6)
                        Text(effect)
                            .font(FontStyles.labelTiny)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 200)
        .background(KingdomTheme.Colors.parchment)
    }
}

// MARK: - Style Phase Timer

/// Timer for the style selection phase
struct StylePhaseTimer: View {
    let expiresAt: String
    
    @State private var secondsRemaining: Int = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .bold))
            Text("\(secondsRemaining)s")
                .font(.system(size: 12, weight: .black, design: .monospaced))
        }
        .foregroundColor(secondsRemaining <= 3 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium)
        .onAppear {
            updateTimer()
        }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
    }
    
    private func updateTimer() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var expiry = formatter.date(from: expiresAt)
        if expiry == nil {
            formatter.formatOptions = [.withInternetDateTime]
            expiry = formatter.date(from: expiresAt)
        }
        
        if let exp = expiry {
            let remaining = exp.timeIntervalSinceNow
            secondsRemaining = max(0, Int(remaining))
        }
    }
}
