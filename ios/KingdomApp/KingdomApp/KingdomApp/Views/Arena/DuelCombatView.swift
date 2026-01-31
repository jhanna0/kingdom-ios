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
    
    // Idle fighting animation (continuous)
    @State private var idleFightPhase: Int = 0  // 0-3: different poses in the cycle
    let idleFightTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    @State private var showImpact: Bool = false
    @State private var lastOutcome: String = ""
    
    // Forfeit confirmation
    @State private var showForfeitConfirmation: Bool = false
    
    // Style picker overlay
    @State private var showStylePicker: Bool = false  // User taps to open, no auto-popup
    
    // Critical hit popup
    @State private var showCritPopup: Bool = false
    @State private var critPopupData: CritPopupData? = nil
    
    // Animated probability bar values
    @State private var animatedMiss: CGFloat = 50
    @State private var animatedHit: CGFloat = 40
    @State private var animatedCrit: CGFloat = 10
    @State private var showOddsChange: Bool = false
    @State private var oddsChangeText: String = ""
    
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
    
    // MARK: - Idle Fight Animation (continuous sparring)
    
    // My character animation values
    private var myCharacterRotation: Double {
        if myCharacterSwinging { return 20 }
        // Idle: phases 0,2 are ready stance, 1 is attack, 3 is recover
        switch idleFightPhase {
        case 1: return 15   // Attacking
        case 3: return -5   // Dodging back
        default: return 3   // Ready stance slight lean
        }
    }
    
    private var myCharacterOffset: CGFloat {
        if myCharacterSwinging { return 25 }
        if myCharacterPushing { return 35 }
        // Idle movement
        switch idleFightPhase {
        case 1: return 12   // Lunge forward
        case 3: return -4   // Step back
        default: return 0
        }
    }
    
    private var myCharacterBounce: CGFloat {
        // Small bounce during idle
        if myCharacterSwinging || myCharacterPushing { return 0 }
        return idleFightPhase % 2 == 0 ? 0 : -3
    }
    
    // Enemy character animation values (mirrored timing - when I attack, they defend)
    private var enemyCharacterRotation: Double {
        if enemyCharacterSwinging { return -20 }
        // Opposite phase to player
        switch idleFightPhase {
        case 1: return 5    // Blocking/dodging
        case 3: return -15  // Counter-attacking
        default: return -3  // Ready stance
        }
    }
    
    private var enemyCharacterOffset: CGFloat {
        if enemyCharacterSwinging { return -25 }
        if enemyCharacterPushing { return -35 }
        // Opposite movement to player
        switch idleFightPhase {
        case 1: return 4    // Step back (dodging)
        case 3: return -12  // Counter-lunge
        default: return 0
        }
    }
    
    private var enemyCharacterBounce: CGFloat {
        if enemyCharacterSwinging || enemyCharacterPushing { return 0 }
        return idleFightPhase % 2 == 1 ? 0 : -3
    }

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
            // Skip if match already ended via round popup (integrated victory/defeat)
            if currentMatch.isComplete, let winner = currentMatch.winnerPerspective, !viewModel.isAnimating, !viewModel.matchEndedViaRoundPopup {
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
            
            // Full-screen style picker (shown during style selection)
            if showStylePicker && currentMatch.isFighting && currentMatch.myStyleLocked != true {
                stylePickerOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(45)
            }
            
            // Round result popup (shows head-to-head comparison)
            // If match complete, this popup also shows victory/defeat integrated
            if viewModel.showRoundResult, let data = viewModel.roundResultData {
                RoundResultPopup(
                    data: data,
                    myColor: myColor,
                    enemyColor: enemyColor,
                    myName: currentMatch.myName,
                    opponentName: opponentDisplayName,
                    gameConfig: gameConfig,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.showRoundResult = false
                        }
                    },
                    onMatchComplete: {
                        // Match ended - dismiss popup and navigate back to arena
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.showRoundResult = false
                            viewModel.matchEndedViaRoundPopup = true
                        }
                        onComplete()
                        dismiss()
                    }
                )
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
            // Initialize animated odds - use BASE if styles not locked yet, else CURRENT
            if currentMatch.bothStylesLocked == true {
                // Styles already locked, show final values
                animatedMiss = CGFloat(currentMatch.currentOdds?.miss ?? 50)
                animatedHit = CGFloat(currentMatch.currentOdds?.hit ?? 40)
                animatedCrit = CGFloat(currentMatch.currentOdds?.crit ?? 10)
            } else {
                // Styles not locked yet, show base values (animation will play when they lock)
                animatedMiss = CGFloat(currentMatch.baseOdds?.miss ?? currentMatch.currentOdds?.miss ?? 50)
                animatedHit = CGFloat(currentMatch.baseOdds?.hit ?? currentMatch.currentOdds?.hit ?? 40)
                animatedCrit = CGFloat(currentMatch.baseOdds?.crit ?? currentMatch.currentOdds?.crit ?? 10)
            }
            // Initialize turn timer from SERVER's turn_expires_at (not hardcoded 30s)
            updateTimerFromServer()
        }
        // Animate when there's a roll to show
        .onChange(of: viewModel.currentRoll?.value) { _, _ in
            if viewModel.currentRoll != nil {
                Task { await animateRoll() }
            }
        }
        // Round changed - no auto-popup, user taps "Choose Style" card when ready
        .onChange(of: currentMatch.roundNumber) { _, _ in
            // Just tracking round changes, style picker is manually opened
        }
        // Hide style picker when style is locked
        .onChange(of: currentMatch.myStyleLocked) { _, isLocked in
            if isLocked == true {
                withAnimation(.easeOut(duration: 0.2)) {
                    showStylePicker = false
                }
            }
        }
        // Animate probability bar when styles lock (style effects!)
        // Uses baseOdds and currentOdds from server - NO CLIENT CALCULATIONS
        .onChange(of: currentMatch.bothStylesLocked) { oldLocked, newLocked in
            guard newLocked == true else { return }
            
            // Server sends base_odds and current_odds
            // Animate from base → current to show style effects
            let baseHit = currentMatch.baseOdds?.hit ?? 50
            let finalHit = currentMatch.currentOdds?.hit ?? baseHit
            let hitDelta = finalHit - baseHit
            
            // Only animate if there's a style effect (delta != 0)
            if hitDelta != 0 {
                // Start at base values
                animatedMiss = CGFloat(currentMatch.baseOdds?.miss ?? 50)
                animatedHit = CGFloat(baseHit)
                animatedCrit = CGFloat(currentMatch.baseOdds?.crit ?? 10)
                
                // Show change indicator from SERVER values
                oddsChangeText = hitDelta > 0 ? "HIT +\(hitDelta)%" : "HIT \(hitDelta)%"
                
                // Delay then animate to final values
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showOddsChange = true
                    }
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        animatedMiss = CGFloat(currentMatch.currentOdds?.miss ?? 50)
                        animatedHit = CGFloat(finalHit)
                        animatedCrit = CGFloat(currentMatch.currentOdds?.crit ?? 10)
                    }
                }
                
                // Hide change indicator after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showOddsChange = false
                    }
                }
            } else {
                // No style effect, just set directly
                animatedMiss = CGFloat(currentMatch.currentOdds?.miss ?? 50)
                animatedHit = CGFloat(finalHit)
                animatedCrit = CGFloat(currentMatch.currentOdds?.crit ?? 10)
            }
        }
        // Also update if odds change mid-round (shouldn't happen but safety)
        .onChange(of: currentMatch.currentOdds?.hit) { _, newHit in
            guard let newHit = newHit else { return }
            // Only direct update if styles already locked (animation already played)
            if currentMatch.bothStylesLocked == true && !showOddsChange {
                animatedMiss = CGFloat(currentMatch.currentOdds?.miss ?? 50)
                animatedHit = CGFloat(newHit)
                animatedCrit = CGFloat(currentMatch.currentOdds?.crit ?? 10)
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
        .onReceive(idleFightTimer) { _ in
            // Continuous idle fighting animation
            guard currentMatch.isFighting && !currentMatch.isComplete else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                idleFightPhase = (idleFightPhase + 1) % 4
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
                    
                    // Style chips (shown after both styles locked)
                    if currentMatch.bothStylesLocked == true {
                        activeStyleChips
                            .id("styleChips-\(currentMatch.myStyle ?? "")-\(currentMatch.opponentStyle ?? "")")
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
            
            // Locked status - show the style with its ACTIVE EFFECTS
            if currentMatch.myStyleLocked == true {
                if let myStyle = currentMatch.myStyle,
                   let styleConfig = gameConfig?.attackStyles?.first(where: { $0.id == myStyle }) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Style name with icon
                        HStack(spacing: 8) {
                            Image(systemName: styleConfig.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(myColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(styleConfig.name.uppercased())
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(myColor)
                                Text("ACTIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(myColor.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(myColor)
                        }
                        
                        // Show active effects
                        if !styleConfig.effectsSummary.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(styleConfig.effectsSummary, id: \.self) { effect in
                                    HStack(spacing: 4) {
                                        Image(systemName: effect.contains("+") ? "arrow.up.circle.fill" : 
                                              effect.contains("-") ? "arrow.down.circle.fill" : "equal.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(effect.contains("+") ? .green : 
                                                           effect.contains("-") && !effect.contains("Enemy") ? .orange : 
                                                           effect.contains("Enemy") ? .green : KingdomTheme.Colors.inkMedium)
                                        Text(effect)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(KingdomTheme.Colors.inkDark)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(myColor.opacity(0.1))
                            )
                        }
                    }
                }
            } else {
                // Button to open full style picker
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showStylePicker = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 16, weight: .bold))
                        Text("Tap to Choose Style")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(myColor)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(myColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(myColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
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
    
    // MARK: - Active Style Chips (shown after both styles locked)
    
    private var activeStyleChips: some View {
        let myStyle = currentMatch.myStyle ?? "balanced"
        let oppStyle = currentMatch.opponentStyle ?? "balanced"
        let myStyleConfig = gameConfig?.attackStyles?.first(where: { $0.id == myStyle })
        let oppStyleConfig = gameConfig?.attackStyles?.first(where: { $0.id == oppStyle })
        
        // ALL VALUES FROM SERVER - NO CALCULATIONS
        let myBaseSwings = currentMatch.baseMaxSwings ?? 1
        let myFinalSwings = currentMatch.maxSwings ?? 1
        let mySwingDelta = currentMatch.swingDelta ?? 0
        let oppBaseSwings = currentMatch.opponentBaseSwings ?? 1
        let oppFinalSwings = currentMatch.opponentMaxSwings ?? 1
        let oppSwingDelta = currentMatch.opponentSwingDelta ?? 0
        
        return VStack(spacing: 10) {
            // Style chips row
            HStack(spacing: 12) {
                // YOUR STYLE
                AnimatedStyleChip(
                    label: "YOU",
                    styleName: myStyleConfig?.name ?? myStyle.capitalized,
                    icon: myStyleConfig?.icon ?? "equal.circle.fill",
                    color: myColor,
                    baseSwings: myBaseSwings,
                    finalSwings: myFinalSwings,
                    swingDelta: mySwingDelta,
                    effects: myStyleConfig?.effectsSummary ?? [],
                    delay: 0
                )
                
                // VS divider
                Text("VS")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                // OPPONENT STYLE
                AnimatedStyleChip(
                    label: opponentDisplayName.uppercased(),
                    styleName: oppStyleConfig?.name ?? oppStyle.capitalized,
                    icon: oppStyleConfig?.icon ?? "equal.circle.fill",
                    color: enemyColor,
                    baseSwings: oppBaseSwings,
                    finalSwings: oppFinalSwings,
                    swingDelta: oppSwingDelta,
                    effects: oppStyleConfig?.effectsSummary ?? [],
                    delay: 0.15
                )
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private func effectColor(_ effect: String) -> Color {
        if effect.contains("+") && !effect.contains("Enemy") {
            return .green
        } else if effect.contains("-") && !effect.contains("Enemy") {
            return .orange
        } else if effect.contains("Enemy") {
            return .purple
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    // MARK: - Compact Header
    
    /// Computed status for the round header
    private var roundStatus: (text: String, color: Color) {
        let roundNum = currentMatch.roundNumber ?? 1
        let phase = currentMatch.roundPhase ?? "style_selection"
        let submitted = currentMatch.submitted ?? (currentMatch.hasSubmittedRound ?? false)
        let myStyleLocked = currentMatch.myStyleLocked ?? false
        let swingsUsed = currentMatch.swingsUsed ?? 0
        let swingsRemaining = currentMatch.swingsRemaining ?? 0
        
        switch phase {
        case "style_selection":
            if myStyleLocked {
                return ("ROUND \(roundNum) — STYLE LOCKED", myColor)
            } else {
                return ("ROUND \(roundNum) — PICK STYLE", KingdomTheme.Colors.imperialGold)
            }
        case "style_reveal":
            return ("ROUND \(roundNum) — STYLES REVEALED", KingdomTheme.Colors.imperialGold)
        case "swinging":
            if submitted {
                return ("ROUND \(roundNum) — WAITING", enemyColor)
            } else if swingsUsed > 0 {
                return ("ROUND \(roundNum) — \(swingsRemaining) SWINGS LEFT", myColor)
            } else {
                return ("ROUND \(roundNum) — SWING!", myColor)
            }
        case "resolving":
            return ("ROUND \(roundNum) — RESOLVING", KingdomTheme.Colors.imperialGold)
        default:
            return ("ROUND \(roundNum)", KingdomTheme.Colors.inkMedium)
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
            
            // Forfeit button (replaces close button during combat)
            if currentMatch.isFighting {
                Button(action: { showForfeitConfirmation = true }) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(KingdomTheme.Colors.parchmentLight).overlay(Circle().stroke(Color.black, lineWidth: 2)))
                }
            } else {
                // Close button (only when not fighting)
                Button(action: { onComplete() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(KingdomTheme.Colors.parchmentLight).overlay(Circle().stroke(Color.black, lineWidth: 2)))
                }
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
                    
                    // Character with idle fight animation
                    Image(systemName: "figure.fencing")
                        .font(.system(size: 44))
                        .foregroundColor(myColor)
                        .shadow(color: myCharacterSwinging ? myColor : .clear, radius: myCharacterSwinging ? 12 : 0)
                        .rotationEffect(.degrees(myCharacterRotation), anchor: .bottom)
                        .offset(x: myCharacterOffset, y: myCharacterBounce)
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
                    
                    // Character (facing left) with idle fight animation
                    Image(systemName: "figure.fencing")
                        .font(.system(size: 44))
                        .foregroundColor(enemyColor)
                        .scaleEffect(x: -1, y: 1)
                        .shadow(color: enemyCharacterSwinging ? enemyColor : .clear, radius: enemyCharacterSwinging ? 12 : 0)
                        .rotationEffect(.degrees(enemyCharacterRotation), anchor: .bottom)
                        .offset(x: enemyCharacterOffset, y: enemyCharacterBounce)
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
                
                // Show odds change indicator
                if showOddsChange {
                    Text(oddsChangeText)
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(oddsChangeText.contains("+") ? .green : .orange)
                        .transition(.scale.combined(with: .opacity))
                } else if !oddsLoaded {
                    Text("Loading...")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                } else if showRollMarker {
                    Text("Rolled: \(rollDisplayValue)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(markerColor(rollDisplayValue))
                } else {
                    // Show current hit chance
                    Text("\(Int(animatedHit))% HIT")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(myColor)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Gradient-filled sections - ANIMATED widths
                    HStack(spacing: 0) {
                        // Miss zone - dark gray gradient
                        LinearGradient(
                            colors: [Color(white: 0.4), Color(white: 0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: animatedMiss / 100.0 * geo.size.width)
                        
                        // Hit zone - medium color
                        LinearGradient(
                            colors: [displayBarColor.opacity(0.8), displayBarColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: animatedHit / 100.0 * geo.size.width)
                        
                        // Crit zone - bright color
                        LinearGradient(
                            colors: [displayBarColor, displayBarColor.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedMiss)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedHit)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2.5)
                    
                    // Labels - also animated
                    HStack(spacing: 0) {
                        Text("MISS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .frame(width: animatedMiss / 100.0 * geo.size.width)
                        Text("HIT")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .frame(width: animatedHit / 100.0 * geo.size.width)
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
    
    // MARK: - Round History Card
    
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
                    // Swing-by-swing system
                    let canSwing = currentMatch.canSwing ?? false
                    let canStop = currentMatch.canStop ?? false
                    let submitted = currentMatch.submitted ?? (currentMatch.hasSubmittedRound ?? false)
                    let swingsRemaining = currentMatch.swingsRemaining ?? (currentMatch.yourSwingsRemaining ?? 0)
                    let bestOutcome = currentMatch.bestOutcome ?? "none"
                    let opponentSubmitted = currentMatch.opponentSubmitted ?? false
                    
                    // Server sends swingPhaseExpiresAt - just check if it's passed
                    let canClaimTimeout: Bool = {
                        guard submitted && !opponentSubmitted else { return false }
                        guard let expiresStr = currentMatch.swingPhaseExpiresAt,
                              let expires = ISO8601DateFormatter().date(from: expiresStr) else { return false }
                        return Date() > expires
                    }()
                    
                    if submitted {
                        // Already submitted - waiting for opponent
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(myColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SUBMITTED").font(FontStyles.labelBold).foregroundColor(myColor)
                                    Text("Best: \(bestOutcome.uppercased()) • Waiting for \(opponentDisplayName)...")
                                        .font(FontStyles.labelTiny).foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                                Spacer()
                                if !canClaimTimeout {
                                    ProgressView().tint(myColor)
                                }
                            }
                            // Show claim timeout button if opponent timed out
                            if canClaimTimeout {
                                Button { Task { await viewModel.claimTimeout() } } label: {
                                    HStack { 
                                        Image(systemName: "clock.badge.exclamationmark")
                                        Text("\(opponentDisplayName) timed out! Claim Victory")
                                    }.frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, foregroundColor: .white, fullWidth: true))
                            }
                        }
                    } else if canSwing || canStop {
                        // SWING-BY-SWING CONTROLS - ALWAYS show both buttons 50/50
                        // This prevents layout shift and accidental taps when buttons appear/disappear
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            // SWING button - always visible, disabled when can't swing
                            Button { Task { await viewModel.swing() } } label: {
                                VStack(spacing: 2) {
                                    HStack { 
                                        Image(systemName: "figure.fencing")
                                        Text("SWING")
                                    }
                                    Text(canSwing ? "\(swingsRemaining) left" : "Done")
                                        .font(.system(size: 10, weight: .bold))
                                        .opacity(0.8)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.brutalist(
                                backgroundColor: (!canSwing || viewModel.isAnimating) ? KingdomTheme.Colors.disabled : myColor,
                                foregroundColor: .white,
                                fullWidth: true
                            ))
                            .disabled(!canSwing || viewModel.isAnimating)
                            
                            // STOP button - always visible, disabled when can't stop
                            Button { Task { await viewModel.stop() } } label: {
                                VStack(spacing: 2) {
                                    HStack { 
                                        Image(systemName: "hand.raised.fill")
                                        Text("SUBMIT")
                                    }
                                    Text(canStop ? "Lock \(bestOutcome.uppercased())" : "Swing first")
                                        .font(.system(size: 10, weight: .bold))
                                        .opacity(0.8)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.brutalist(
                                backgroundColor: (!canStop || viewModel.isAnimating) ? KingdomTheme.Colors.disabled : KingdomTheme.Colors.imperialGold,
                                foregroundColor: .white,
                                fullWidth: true
                            ))
                            .disabled(!canStop || viewModel.isAnimating)
                        }
                    } else {
                        // In style phase or waiting
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            if currentMatch.inStylePhase == true || currentMatch.canLockStyle == true {
                                Text("Pick your style above!").font(FontStyles.labelMedium).foregroundColor(KingdomTheme.Colors.inkMedium)
                            } else {
                                Text("Waiting...").font(FontStyles.labelMedium).foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            Spacer()
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
    
    // MARK: - Style Picker Overlay (Full Screen)
    
    private var stylePickerOverlay: some View {
        DuelStylePickerView(
            roundNumber: currentMatch.roundNumber ?? 1,
            styles: gameConfig?.attackStyles ?? [],
            expiresAt: currentMatch.styleLockExpiresAt,
            roundHistory: viewModel.roundHistory,
            myName: currentMatch.myName,
            opponentName: opponentDisplayName,
            myColor: myColor,
            enemyColor: enemyColor,
            onSelectStyle: { styleId in
                showStylePicker = false
                Task { await viewModel.lockStyle(styleId) }
            }
        )
    }
    
    // MARK: - Style Reveal Overlay
    
    private func styleRevealOverlay(data: StyleRevealData) -> some View {
        StyleRevealPopup(
            data: data,
            myColor: myColor,
            enemyColor: enemyColor,
            opponentName: opponentDisplayName,
            isChallenger: currentMatch.challenger.id == playerId,
            gameConfig: gameConfig,
            onDismiss: {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.showStyleReveal = false
                }
            }
        )
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
}

// MARK: - Style Reveal Popup with Animations (Full Screen)
struct StyleRevealPopup: View {
    let data: StyleRevealData
    let myColor: Color
    let enemyColor: Color
    let opponentName: String
    let isChallenger: Bool
    let gameConfig: DuelGameConfig?
    let onDismiss: () -> Void
    
    // Animation state
    @State private var hasAppeared = false
    @State private var myDisplayedSwings: Int = 0
    @State private var oppDisplayedSwings: Int = 0
    @State private var showSwingDeltas = false
    
    // My animated odds (when I attack)
    @State private var animatedMiss: CGFloat = 50
    @State private var animatedHit: CGFloat = 40
    @State private var animatedCrit: CGFloat = 10
    
    // Opponent's animated odds (when they attack me)
    @State private var oppAnimatedMiss: CGFloat = 50
    @State private var oppAnimatedHit: CGFloat = 40
    @State private var oppAnimatedCrit: CGFloat = 10
    
    @State private var showOddsChange = false
    
    var body: some View {
        ZStack {
            // SOLID parchment background - full screen
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Title
                Text("STYLES REVEALED")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // YOUR STYLE card with YOUR odds
                playerStyleCard(
                    label: "YOU",
                    styleName: data.myStyleName,
                    styleId: data.myStyle,
                    color: myColor,
                    swings: myDisplayedSwings,
                    baseSwings: data.myBaseSwings,
                    finalSwings: data.myFinalSwings,
                    swingDelta: data.mySwingDelta,
                    animatedMiss: animatedMiss,
                    animatedHit: animatedHit,
                    animatedCrit: animatedCrit,
                    baseHit: data.baseHit,
                    finalHit: data.finalHit
                )
                
                // VS Divider
                HStack {
                    Rectangle().fill(KingdomTheme.Colors.inkLight.opacity(0.3)).frame(height: 2)
                    Text("VS")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                        .padding(.horizontal, 20)
                    Rectangle().fill(KingdomTheme.Colors.inkLight.opacity(0.3)).frame(height: 2)
                }
                .padding(.horizontal, 40)
                
                // OPPONENT'S STYLE card with THEIR odds
                playerStyleCard(
                    label: opponentName.uppercased(),
                    styleName: data.opponentStyleName,
                    styleId: data.opponentStyle,
                    color: enemyColor,
                    swings: oppDisplayedSwings,
                    baseSwings: data.oppBaseSwings,
                    finalSwings: data.oppFinalSwings,
                    swingDelta: data.oppSwingDelta,
                    animatedMiss: oppAnimatedMiss,
                    animatedHit: oppAnimatedHit,
                    animatedCrit: oppAnimatedCrit,
                    baseHit: data.oppBaseHit,
                    finalHit: data.oppFinalHit
                )
                
                // Feint winner (if applicable)
                if let feint = data.feintWinner {
                    feintWinnerBadge(feint: feint)
                }
                
                Spacer()
                
                // FIGHT Button
                Button(action: onDismiss) {
                    Text("FIGHT!")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.parchment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                                    .offset(x: 4, y: 4)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(KingdomTheme.Colors.buttonDanger)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 3))
                            }
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                startAnimation()
            }
        }
    }
    
    // MARK: - Player Style Card (Full Width with Probability Bar)
    
    private func playerStyleCard(
        label: String,
        styleName: String,
        styleId: String,
        color: Color,
        swings: Int,
        baseSwings: Int,
        finalSwings: Int,
        swingDelta: Int,
        animatedMiss: CGFloat,
        animatedHit: CGFloat,
        animatedCrit: CGFloat,
        baseHit: Int,
        finalHit: Int
    ) -> some View {
        let icon = gameConfig?.attackStyles?.first(where: { $0.id == styleId })?.icon ?? "equal.circle.fill"
        
        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Style icon - big and prominent
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .offset(x: 3, y: 3)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                        .frame(width: 64, height: 64)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 3))
                    
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    // Player name - FULL NAME shown
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // Style name
                    Text(styleName.uppercased())
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(color)
                    
                    // Swings - shows base → final with animation
                    HStack(spacing: 4) {
                        ForEach(0..<max(baseSwings, finalSwings), id: \.self) { i in
                            Image(systemName: "figure.fencing")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(i < swings ? color : KingdomTheme.Colors.disabled.opacity(0.3))
                                .scaleEffect(i < swings ? 1.0 : 0.7)
                        }
                        
                        if showSwingDeltas && swingDelta != 0 {
                            Text(swingDelta > 0 ? "+\(swingDelta)" : "\(swingDelta)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(swingDelta > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                                .padding(.leading, 2)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Probability bar for THIS player's hit chance
            VStack(spacing: 4) {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Miss - gray gradient
                        LinearGradient(
                            colors: [Color(white: 0.4), Color(white: 0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: max(0, animatedMiss / 100.0 * geo.size.width))
                        
                        // Hit - player color gradient (medium opacity)
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: max(0, animatedHit / 100.0 * geo.size.width))
                        
                        // Crit - player color gradient (bright)
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                }
                .frame(height: 24)
                
                // Percentage labels
                HStack {
                    Text("MISS \(Int(animatedMiss))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.disabled)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Text("HIT \(Int(animatedHit))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(color)
                        
                        if showOddsChange && finalHit != baseHit {
                            let delta = finalHit - baseHit
                            Text(delta > 0 ? "(+\(delta))" : "(\(delta))")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(delta > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                        }
                    }
                    
                    Spacer()
                    
                    Text("CRIT \(Int(animatedCrit))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 14)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: 2))
            }
        )
        .padding(.horizontal, 4)
    }
    
    
    // MARK: - Feint Winner Badge
    
    private func feintWinnerBadge(feint: String) -> some View {
        let feintWinnerName = feint == "challenger" ?
            (isChallenger ? "YOU" : opponentName.uppercased()) :
            (!isChallenger ? "YOU" : opponentName.uppercased())
        
        return HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.imperialGold)
            Text("\(feintWinnerName) WINS TIES!")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KingdomTheme.Colors.imperialGold.opacity(0.2))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(KingdomTheme.Colors.imperialGold, lineWidth: 2))
        )
    }
    
    // MARK: - Animation (BASE → FINAL, then LOOPS)
    
    private func startAnimation() {
        // Set to BASE values first
        myDisplayedSwings = data.myBaseSwings
        oppDisplayedSwings = data.oppBaseSwings
        
        // My odds (base)
        animatedMiss = CGFloat(data.baseMiss)
        animatedHit = CGFloat(data.baseHit)
        animatedCrit = CGFloat(data.baseCrit)
        
        // Opponent's odds (base)
        oppAnimatedMiss = CGFloat(data.oppBaseMiss)
        oppAnimatedHit = CGFloat(data.oppBaseHit)
        oppAnimatedCrit = CGFloat(data.oppBaseCrit)
        
        showSwingDeltas = false
        showOddsChange = false
        
        // Animate to FINAL values after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                myDisplayedSwings = data.myFinalSwings
                oppDisplayedSwings = data.oppFinalSwings
                showSwingDeltas = true
            }
        }
        
        // Animate probability bars (both)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showOddsChange = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                // My odds (final)
                animatedMiss = CGFloat(data.finalMiss)
                animatedHit = CGFloat(data.finalHit)
                animatedCrit = CGFloat(data.finalCrit)
                
                // Opponent's odds (final)
                oppAnimatedMiss = CGFloat(data.oppFinalMiss)
                oppAnimatedHit = CGFloat(data.oppFinalHit)
                oppAnimatedCrit = CGFloat(data.oppFinalCrit)
            }
        }
        
        // LOOP the animation after showing final values
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            loopAnimation()
        }
    }
    
    private func loopAnimation() {
        // Reset to BASE values
        withAnimation(.easeOut(duration: 0.3)) {
            myDisplayedSwings = data.myBaseSwings
            oppDisplayedSwings = data.oppBaseSwings
            
            // My odds (base)
            animatedMiss = CGFloat(data.baseMiss)
            animatedHit = CGFloat(data.baseHit)
            animatedCrit = CGFloat(data.baseCrit)
            
            // Opponent's odds (base)
            oppAnimatedMiss = CGFloat(data.oppBaseMiss)
            oppAnimatedHit = CGFloat(data.oppBaseHit)
            oppAnimatedCrit = CGFloat(data.oppBaseCrit)
            
            showSwingDeltas = false
            showOddsChange = false
        }
        
        // Animate back to FINAL
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                myDisplayedSwings = data.myFinalSwings
                oppDisplayedSwings = data.oppFinalSwings
                showSwingDeltas = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showOddsChange = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                // My odds (final)
                animatedMiss = CGFloat(data.finalMiss)
                animatedHit = CGFloat(data.finalHit)
                animatedCrit = CGFloat(data.finalCrit)
                
                // Opponent's odds (final)
                oppAnimatedMiss = CGFloat(data.oppFinalMiss)
                oppAnimatedHit = CGFloat(data.oppFinalHit)
                oppAnimatedCrit = CGFloat(data.oppFinalCrit)
            }
        }
        
        // Loop again
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            loopAnimation()
        }
    }
}

// Continue DuelCombatView extension
extension DuelCombatView {
    
}

// MARK: - Style Reveal Data
struct StyleRevealData {
    let myStyle: String
    let opponentStyle: String
    let myStyleName: String
    let opponentStyleName: String
    let feintWinner: String?  // If feint broke a tie
    
    // Animation data from server - NO CLIENT CALCS
    let myBaseSwings: Int
    let myFinalSwings: Int
    let mySwingDelta: Int
    let oppBaseSwings: Int
    let oppFinalSwings: Int
    let oppSwingDelta: Int
    
    // MY odds (when I attack opponent)
    let baseMiss: Int
    let baseHit: Int
    let baseCrit: Int
    let finalMiss: Int
    let finalHit: Int
    let finalCrit: Int
    
    // OPPONENT's odds (when they attack me)
    let oppBaseMiss: Int
    let oppBaseHit: Int
    let oppBaseCrit: Int
    let oppFinalMiss: Int
    let oppFinalHit: Int
    let oppFinalCrit: Int
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
    
    // Round result popup (controlled by event queue)
    @Published var showRoundResult: Bool = false
    @Published var roundResultData: RoundResultData? = nil
    @Published var matchEndedViaRoundPopup: Bool = false  // Skip separate result overlay if match ended in round popup
    
    // Style reveal popup (shows both styles after round resolution)
    @Published var showStyleReveal: Bool = false
    @Published var styleRevealData: StyleRevealData? = nil
    
    // Round history (tracks all rounds in this duel)
    @Published var roundHistory: [DuelRoundHistoryEntry] = []
    
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
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: roll, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil, resolutionPushAmount: nil, roundResultData: nil))
            processQueue()
            return
        }
        
        // Style locked - just update match state (opponent locked their style)
        if event.eventType == .styleLocked {
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil, resolutionPushAmount: nil, roundResultData: nil))
            processQueue()
            return
        }
        
        // Styles revealed - both players locked, transition to swing phase
        if event.eventType == .stylesRevealed {
            // Build style reveal data for animation - ALL VALUES FROM SERVER
            let challengerStyle = event.data["challenger_style"] as? String
            let opponentStyle = event.data["opponent_style"] as? String
            
            var styleReveal: StyleRevealData? = nil
            if let chStyle = challengerStyle, let opStyle = opponentStyle, let m = event.match {
                let isChallenger = m.challenger.id == playerId
                let myStyle = isChallenger ? chStyle : opStyle
                let oppStyle = isChallenger ? opStyle : chStyle
                
                // All animation values from server
                styleReveal = StyleRevealData(
                    myStyle: myStyle,
                    opponentStyle: oppStyle,
                    myStyleName: myStyle.replacingOccurrences(of: "_", with: " ").capitalized,
                    opponentStyleName: oppStyle.replacingOccurrences(of: "_", with: " ").capitalized,
                    feintWinner: nil,
                    myBaseSwings: m.baseMaxSwings ?? 1,
                    myFinalSwings: m.maxSwings ?? 1,
                    mySwingDelta: m.swingDelta ?? 0,
                    oppBaseSwings: m.opponentBaseSwings ?? 1,
                    oppFinalSwings: m.opponentMaxSwings ?? 1,
                    oppSwingDelta: m.opponentSwingDelta ?? 0,
                    // My odds (when I attack)
                    baseMiss: m.baseOdds?.miss ?? 50,
                    baseHit: m.baseOdds?.hit ?? 40,
                    baseCrit: m.baseOdds?.crit ?? 10,
                    finalMiss: m.currentOdds?.miss ?? 50,
                    finalHit: m.currentOdds?.hit ?? 40,
                    finalCrit: m.currentOdds?.crit ?? 10,
                    // Opponent's odds (when they attack me)
                    oppBaseMiss: m.opponentBaseOdds?.miss ?? 50,
                    oppBaseHit: m.opponentBaseOdds?.hit ?? 40,
                    oppBaseCrit: m.opponentBaseOdds?.crit ?? 10,
                    oppFinalMiss: m.opponentOdds?.miss ?? 50,
                    oppFinalHit: m.opponentOdds?.hit ?? 40,
                    oppFinalCrit: m.opponentOdds?.crit ?? 10
                )
            }
            
            // Update match state with style reveal animation
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: styleReveal, resolutionPushAmount: nil, roundResultData: nil))
            processQueue()
            return
        }
        
        // Player submitted - opponent finished swinging
        if event.eventType == .playerSubmitted {
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil, resolutionPushAmount: nil, roundResultData: nil))
            processQueue()
            return
        }

        // Round resolved - show results popup (NOT for ended/forfeit)
        if event.eventType == .roundResolved {
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
            
            // YOUR push amount comes directly from backend with correct sign for your perspective
            // Positive = you won, Negative = you lost, Zero = parried
            let yourPushAmount = event.data["your_push_amount"] as? Double ?? 0
            
            // Record round history from WebSocket event
            let isChallenger = match?.challenger.id == playerId
            let winnerSide = resultDict?["winner_side"] as? String
            let rawPushAmount = resultDict?["push_amount"] as? Double ?? 0
            let roundNumber = event.data["round_number"] as? Int ?? (match?.roundNumber ?? 1)
            let chBest = resultDict?["challenger_best"] as? String ?? ch.map { $0.outcome }.max(by: { outcomeRank($0) < outcomeRank($1) }) ?? "miss"
            let opBest = resultDict?["opponent_best"] as? String ?? op.map { $0.outcome }.max(by: { outcomeRank($0) < outcomeRank($1) }) ?? "miss"
            
            let myBest = isChallenger == true ? chBest : opBest
            let oppBest = isChallenger == true ? opBest : chBest
            
            // Get styles for history (styles were already revealed, don't show reveal again!)
            let myStyle = isChallenger == true ? (challengerStyle ?? "balanced") : (opponentStyleData ?? "balanced")
            let oppStyle = isChallenger == true ? (opponentStyleData ?? "balanced") : (challengerStyle ?? "balanced")
            
            // Create RollDisplay arrays for the popup (NOT interleaved - clearly separated)
            let myRolls: [RollDisplay] = (isChallenger == true ? ch : op).map { 
                RollDisplay(value: $0.value, outcome: $0.outcome)
            }
            let oppRolls: [RollDisplay] = (isChallenger == true ? op : ch).map {
                RollDisplay(value: $0.value, outcome: $0.outcome)
            }
            
            // Extract tiebreaker data from result (for feint animation)
            var tiebreakerDisplay: TiebreakerDisplay? = nil
            if let tiebreakerDict = resultDict?["tiebreaker"] as? [String: Any] {
                let tbType = tiebreakerDict["type"] as? String ?? "feint_wins"
                let tbWinnerRaw = tiebreakerDict["winner"] as? String
                
                // Convert from challenger/opponent to me/opponent perspective
                let tbWinner: String? = {
                    guard let w = tbWinnerRaw else { return nil }
                    if isChallenger == true {
                        return w == "challenger" ? "me" : "opponent"
                    } else {
                        return w == "opponent" ? "me" : "opponent"
                    }
                }()
                
                // For feint_vs_feint, extract roll values (already as percentages from backend)
                let chRoll = tiebreakerDict["challenger_roll"] as? Double
                let opRoll = tiebreakerDict["opponent_roll"] as? Double
                
                // Map rolls to my/opp perspective
                let myRollValue = isChallenger == true ? chRoll : opRoll
                let oppRollValue = isChallenger == true ? opRoll : chRoll
                
                tiebreakerDisplay = TiebreakerDisplay(
                    type: tbType,
                    winner: tbWinner,
                    myRollValue: myRollValue,
                    oppRollValue: oppRollValue
                )
            }
            
            let historyEntry = DuelRoundHistoryEntry(
                id: roundNumber,
                myStyle: myStyle,
                opponentStyle: oppStyle,
                myBestOutcome: myBest,
                opponentBestOutcome: oppBest,
                winnerSide: winnerSide,
                iWon: yourPushAmount > 0,  // Positive = you won
                pushAmount: rawPushAmount,
                parried: parried,
                feintWinner: feintWinner
            )
            
            if !roundHistory.contains(where: { $0.id == historyEntry.id }) {
                roundHistory.append(historyEntry)
            }

            // NOTE: styleReveal is nil - styles were already revealed at round START
            // Don't show style reveal animation again after round resolution
            // yourPushAmount comes from backend with correct sign (positive=won, negative=lost)
            
            // Check if this round ended the match
            let isMatchComplete = event.match?.isComplete == true
            let didWinMatch = event.match?.winnerPerspective?.didIWin
            let wagerGold = event.match?.wagerGold
            
            // Build round result data for the popup - includes rolls for clear display
            let roundResult = RoundResultData(
                pushAmount: yourPushAmount,
                outcome: popupOutcome,
                myBestOutcome: myBest,
                oppBestOutcome: oppBest,
                myStyle: myStyle,
                oppStyle: oppStyle,
                roundNumber: roundNumber,
                parried: parried,
                myRolls: myRolls,
                opponentRolls: oppRolls,
                tiebreaker: tiebreakerDisplay,
                isMatchComplete: isMatchComplete,
                didWinMatch: didWinMatch,
                wagerGold: wagerGold
            )
            
            // NOTE: rolls is nil - we don't want the confusing one-by-one animation
            // The popup now handles displaying all rolls clearly
            eventQueue.append(DuelQueuedEvent(
                match: event.match,
                roll: nil,
                rolls: nil,
                clearRoundRolls: true,
                showRoundPopup: true,
                popupOutcome: popupOutcome,
                styleReveal: nil,
                resolutionPushAmount: yourPushAmount,
                roundResultData: roundResult
            ))
            processQueue()
            return
        }
        
        // Match ended (forfeit, timeout win, final win) - just update state, no popup
        if event.eventType == .ended {
            eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: true, showRoundPopup: false, popupOutcome: nil, styleReveal: nil, resolutionPushAmount: nil, roundResultData: nil))
            processQueue()
            return
        }

        // Round submitted just updates state (so UI can show opponent submitted)
        eventQueue.append(DuelQueuedEvent(match: event.match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil, resolutionPushAmount: nil, roundResultData: nil))
        processQueue()
    }
    
    private func enqueueAPIResponse(match: DuelMatch?) {
        eventQueue.append(DuelQueuedEvent(match: match, roll: nil, rolls: nil, clearRoundRolls: false, showRoundPopup: false, popupOutcome: nil, styleReveal: nil, resolutionPushAmount: nil, roundResultData: nil))
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
            isAnimating = false  // Re-enable buttons after queue is done
        }
    }
    
    private func processEvent(_ event: DuelQueuedEvent) async {
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
            // No delay here - animation itself shows the result.
            // Match state updates immediately after animation completes.
        }
        
        // STEP 2: Update match state AND re-enable buttons ATOMICALLY
        // This ensures canSwing/canStop/swingsRemaining are correct when buttons enable
        if let m = event.match {
            match = m
            if let matchOdds = m.currentOdds {
                odds = Odds(miss: matchOdds.miss, hit: matchOdds.hit, crit: matchOdds.crit)
            }
        }
        isAnimating = false  // Buttons now enabled with correct state
        
        // STEP 3: Show style reveal if we have style data (before push popup)
        // NOTE: This should ONLY happen for stylesRevealed event, NOT for roundResolved
        // User dismisses manually with FIGHT button - no auto-dismiss
        if let styleData = event.styleReveal {
            self.styleRevealData = styleData
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showStyleReveal = true
            }
            // Wait for user to dismiss - but don't block the queue forever
            // Poll until dismissed (user taps FIGHT button)
            while self.showStyleReveal {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // Brief pause after dismiss
        }
        
        // STEP 4: Show round result popup (head-to-head comparison) when requested
        // User dismisses manually, then bar animates
        if event.showRoundPopup, let resultData = event.roundResultData {
            self.roundResultData = resultData
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showRoundResult = true
            }
            // Wait for user to dismiss
            while self.showRoundResult {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // Brief pause after dismiss
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
        // NOTE: Do NOT set isAnimating = false here!
        // processEvent() manages button state to ensure atomic update with match state.
        // Setting it here caused desync where buttons enabled with stale canSwing/canStop values.
        
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
                
                // If both styles now locked, show the style reveal animation
                if r.bothStylesLocked == true,
                   let myStyle = m.myStyle,
                   let oppStyle = m.opponentStyle {
                    let revealData = StyleRevealData(
                        myStyle: myStyle,
                        opponentStyle: oppStyle,
                        myStyleName: m.myName,
                        opponentStyleName: m.opponentName,
                        feintWinner: nil,
                        myBaseSwings: m.baseMaxSwings ?? 1,
                        myFinalSwings: m.maxSwings ?? 1,
                        mySwingDelta: m.swingDelta ?? 0,
                        oppBaseSwings: m.opponentBaseSwings ?? 1,
                        oppFinalSwings: m.opponentMaxSwings ?? 1,
                        oppSwingDelta: m.opponentSwingDelta ?? 0,
                        // My odds (when I attack)
                        baseMiss: m.baseOdds?.miss ?? 50,
                        baseHit: m.baseOdds?.hit ?? 40,
                        baseCrit: m.baseOdds?.crit ?? 10,
                        finalMiss: m.currentOdds?.miss ?? 50,
                        finalHit: m.currentOdds?.hit ?? 40,
                        finalCrit: m.currentOdds?.crit ?? 10,
                        // Opponent's odds (when they attack me)
                        oppBaseMiss: m.opponentBaseOdds?.miss ?? 50,
                        oppBaseHit: m.opponentBaseOdds?.hit ?? 40,
                        oppBaseCrit: m.opponentBaseOdds?.crit ?? 10,
                        oppFinalMiss: m.opponentOdds?.miss ?? 50,
                        oppFinalHit: m.opponentOdds?.hit ?? 40,
                        oppFinalCrit: m.opponentOdds?.crit ?? 10
                    )
                    self.styleRevealData = revealData
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self.showStyleReveal = true
                    }
                    // User dismisses manually with FIGHT button - no auto-dismiss
                }
            }
            if !r.success { errorMessage = r.message }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Execute ONE swing - the core mechanic
    ///
    /// ARCHITECTURE: API response updates state ONLY. WebSocket events trigger popups.
    /// This prevents duplicate popups when both API and WebSocket return round_resolved.
    func swing() async {
        guard let matchId = matchId else { return }
        guard match?.canSwing == true && !isAnimating && !isProcessingQueue else { return }
        
        isAnimating = true  // Block immediately to prevent double-taps
        
        do {
            let r = try await api.swing(matchId: matchId)
            
            // Record round history if round resolved (for state tracking)
            if r.roundResolved == true, let res = r.resolution {
                recordRoundHistory(resolution: res)
            }
            
            // Animate the roll if we got one
            if let roll = r.roll {
                let rollData = Roll(
                    value: Int(roll.value),
                    outcome: roll.outcome,
                    attackerName: match?.myName,
                    swingNumber: r.swingNumber ?? 1
                )
                // NOTE: showRoundPopup=false - we DON'T trigger popup from API response
                // The WebSocket DUEL_ROUND_RESOLVED event will trigger the popup for BOTH players
                // This prevents Player A from seeing duplicate popups (API + WebSocket)
                eventQueue.append(DuelQueuedEvent(
                    match: r.match,
                    roll: rollData,
                    rolls: nil,
                    clearRoundRolls: false,
                    showRoundPopup: false,  // WebSocket handles popup
                    popupOutcome: nil,
                    styleReveal: nil,
                    resolutionPushAmount: nil,
                    roundResultData: nil
                ))
                processQueue()
            } else if let m = r.match {
                enqueueAPIResponse(match: m)
            }
            
            if !r.success {
                errorMessage = r.message
                isAnimating = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isAnimating = false
        }
    }
    
    /// Helper to rank outcomes for comparison
    private func outcomeRank(_ outcome: String) -> Int {
        switch outcome.lowercased() {
        case "critical", "crit": return 2
        case "hit": return 1
        default: return 0
        }
    }
    
    /// Record a round in history
    private func recordRoundHistory(resolution: DuelRoundResolution) {
        // Determine if I'm challenger or opponent
        let isChallenger = match?.challenger.id == playerId
        
        let myStyle = isChallenger ? (resolution.challengerStyle ?? "balanced") : (resolution.opponentStyle ?? "balanced")
        let oppStyle = isChallenger ? (resolution.opponentStyle ?? "balanced") : (resolution.challengerStyle ?? "balanced")
        let myBest = isChallenger ? (resolution.challengerBest ?? "miss") : (resolution.opponentBest ?? "miss")
        let oppBest = isChallenger ? (resolution.opponentBest ?? "miss") : (resolution.challengerBest ?? "miss")
        
        let iWon: Bool
        if resolution.parried == true {
            iWon = false
        } else if let winner = resolution.winnerSide {
            iWon = (isChallenger && winner == "challenger") || (!isChallenger && winner == "opponent")
        } else {
            iWon = false
        }
        
        let entry = DuelRoundHistoryEntry(
            id: resolution.roundNumber ?? roundHistory.count + 1,
            myStyle: myStyle,
            opponentStyle: oppStyle,
            myBestOutcome: myBest,
            opponentBestOutcome: oppBest,
            winnerSide: resolution.winnerSide,
            iWon: iWon,
            pushAmount: resolution.pushAmount ?? 0,
            parried: resolution.parried ?? false,
            feintWinner: resolution.feintWinner
        )
        
        // Avoid duplicates
        if !roundHistory.contains(where: { $0.id == entry.id }) {
            roundHistory.append(entry)
        }
    }
    
    /// Stop swinging and lock in current best roll
    func stop() async {
        guard let matchId = matchId else { return }
        guard match?.canStop == true && !isAnimating && !isProcessingQueue else { return }
        
        isAnimating = true  // Block immediately to prevent double-taps
        
        do {
            let r = try await api.stop(matchId: matchId)
            if let m = r.match { enqueueAPIResponse(match: m) }
            if !r.success {
                errorMessage = r.message
                isAnimating = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isAnimating = false
        }
    }
    
    /// Legacy: Submit all swings at once
    func submitRoundSwing() async {
        guard let matchId = matchId else { return }
        guard match?.canSubmitRound == true && match?.hasSubmittedRound != true && !isAnimating && !isProcessingQueue else { return }
        
        do {
            let r = try await api.submitRoundSwing(matchId: matchId)
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
    // Push amount from resolution - positive = you won, negative = you lost, nil = calculate from bar
    let resolutionPushAmount: Double?
    // Round result data for the popup
    let roundResultData: RoundResultData?
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

// MARK: - Animated Style Chip

/// Shows a style chip with animated swing count
struct AnimatedStyleChip: View {
    let label: String
    let styleName: String
    let icon: String
    let color: Color
    let baseSwings: Int
    let finalSwings: Int
    let swingDelta: Int
    let effects: [String]
    let delay: Double
    
    @State private var appeared = false
    @State private var showSwingChange = false
    @State private var displayedSwings: Int = 0
    
    var body: some View {
        VStack(spacing: 6) {
            // Label
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Style icon + name (slides in)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    )
                    .scaleEffect(appeared ? 1.0 : 0.5)
                
                Text(styleName.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(color)
                    .lineLimit(1)
            }
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 10)
            
            // Swings indicator with animation
            HStack(spacing: 4) {
                // Swing icons that grow/shrink
                HStack(spacing: 2) {
                    ForEach(0..<max(baseSwings, finalSwings), id: \.self) { i in
                        Image(systemName: "figure.fencing")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(i < displayedSwings ? color : KingdomTheme.Colors.inkLight.opacity(0.3))
                            .scaleEffect(i < displayedSwings ? 1.0 : 0.6)
                            .opacity(i < displayedSwings ? 1.0 : 0.3)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(i) * 0.1), value: displayedSwings)
                    }
                }
                
                // Delta indicator
                if showSwingChange && swingDelta != 0 {
                    Text(swingDelta > 0 ? "+\(swingDelta)" : "\(swingDelta)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(swingDelta > 0 ? .green : .orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 20)
            
            // Effects (fade in)
            if !effects.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(effects.prefix(2).enumerated()), id: \.offset) { index, effect in
                        Text(effect)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(effectColor(effect))
                            .lineLimit(1)
                            .opacity(appeared ? 1.0 : 0.0)
                            .offset(y: appeared ? 0 : 5)
                            .animation(.easeOut(duration: 0.3).delay(delay + 0.3 + Double(index) * 0.1), value: appeared)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Initial state
            displayedSwings = baseSwings
            
            // Stage 1: Chip appears
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay)) {
                appeared = true
            }
            
            // Stage 2: Swing count animates to final value
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    displayedSwings = finalSwings
                    showSwingChange = true
                }
            }
        }
    }
    
    private func effectColor(_ effect: String) -> Color {
        if effect.contains("+") && !effect.contains("Enemy") {
            return .green
        } else if effect.contains("-") && !effect.contains("Enemy") {
            return .orange
        } else if effect.contains("Enemy") {
            return .purple
        }
        return KingdomTheme.Colors.inkMedium
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


