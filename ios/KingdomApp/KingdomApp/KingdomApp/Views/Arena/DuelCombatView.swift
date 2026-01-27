import SwiftUI
import Combine

struct DuelCombatView: View {
    let match: DuelMatch
    let playerId: Int
    let onComplete: () -> Void

    @StateObject private var viewModel = DuelCombatViewModel()
    
    // Animation state
    @State private var rollDisplayValue: Int = 0
    @State private var showRollMarker: Bool = false
    @State private var animatedBarValue: Double = 50
    
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
    private var critMultiplier: Double { gameConfig?.criticalMultiplier ?? 1.5 }
    private var critPopupDurationMs: Int { gameConfig?.critPopupDurationMs ?? 1500 }
    private var rollSweepStepMs: Int { gameConfig?.rollSweepStepMs ?? 15 }
    
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

            if currentMatch.isComplete, let winner = currentMatch.winnerPerspective {
                resultOverlay(winner: winner)
            } else {
                mainContent
            }
            
            // Critical hit popup overlay
            if showCritPopup, let data = critPopupData {
                criticalHitPopup(data: data)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
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
            // Initialize turn timer from server config
            secondsRemaining = turnTimeout
        }
        // Animate when there's a roll to show
        .onChange(of: viewModel.currentRoll?.value) { _, _ in
            if viewModel.currentRoll != nil {
                Task { await animateRoll() }
            }
        }
        // Update bar when match changes (use server value directly)
        .onChange(of: currentMatch.yourBarPosition) { _, newValue in
            withAnimation(.easeInOut(duration: 0.4)) {
                animatedBarValue = newValue ?? 50
            }
        }
        // Turn timer - reset when turn changes (use server config!)
        .onChange(of: currentMatch.isYourTurn) { _, _ in
            secondsRemaining = turnTimeout
            timerActive = currentMatch.isFighting
        }
        // Countdown timer
        .onReceive(timer) { _ in
            guard currentMatch.isFighting && !viewModel.isAnimating else { return }
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
    }
    
    // MARK: - Roll Animation (same for everyone)
    
    @MainActor
    private func animateRoll() async {
        guard let roll = viewModel.currentRoll else { return }
        
        showRollMarker = true
        let target = max(1, min(100, roll.value))
        
        // Sweep to target (timing from server config)
        let sweepNanos = UInt64(rollSweepStepMs) * 1_000_000
        for pos in stride(from: 1, through: target, by: 5) {
            rollDisplayValue = pos
            try? await Task.sleep(nanoseconds: sweepNanos)
        }
        rollDisplayValue = target
        
        // Hold (timing from server config)
        let holdNanos = UInt64(gameConfig?.rollAnimationMs ?? 300) * 1_000_000
        try? await Task.sleep(nanoseconds: holdNanos)
        
        showRollMarker = false
        viewModel.finishCurrentRoll()
        
        // If more in queue, pause then animate next (timing from server config)
        if viewModel.currentRoll != nil {
            let pauseMs = gameConfig?.rollPauseBetweenMs ?? 400
            let pauseNanos = UInt64(pauseMs) * 1_000_000
            try? await Task.sleep(nanoseconds: pauseNanos)
            await animateRoll()
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
                    statusCard
                    probabilityBar
                    turnSwingsCard  // Single unified card for all rolls this turn
                    controlBarSection
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.top, KingdomTheme.Spacing.medium)
                .padding(.bottom, KingdomTheme.Spacing.large)
            }
            
            bottomButtons
        }
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.fencing")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(myColor)
                    Text("PVP DUEL")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                Text("Match #\(currentMatch.id)")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            Spacer()
            Button(action: { onComplete() }) {
                Image(systemName: "xmark")
                    .font(FontStyles.iconTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(KingdomTheme.Colors.parchmentLight).overlay(Circle().stroke(Color.black, lineWidth: 2)))
            }
        }
    }
    
    // MARK: - HUD
    
    private var hudChips: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            chip(label: "ATTACK", value: "\(myAttack)", icon: "burst.fill", tint: myColor)
            
            // Use server-provided swing tracking
            let isYourTurn = currentMatch.isYourTurn ?? false
            let swingsUsed = currentMatch.yourSwingsUsed ?? 0
            let maxSwings = currentMatch.yourMaxSwings ?? (1 + myAttack)
            let swingsToShow = isYourTurn ? maxSwings : (1 + myAttack)
            let swingsUsedToShow = isYourTurn ? swingsUsed : 0
            
            HStack(spacing: 8) {
                Image(systemName: "dice.fill").font(FontStyles.iconTiny).foregroundColor(.white)
                    .frame(width: 28, height: 28).background(KingdomTheme.Colors.inkDark).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("SWINGS").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
                    HStack(spacing: 3) {
                        ForEach(0..<max(1, swingsToShow), id: \.self) { i in
                            Circle()
                                .fill(i < swingsUsedToShow ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.buttonSuccess)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 48).padding(.horizontal, 10)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
            
            // Turn indicator - use server value directly
            let turnText = (currentMatch.isYourTurn ?? false) ? "YOURS" : "THEIRS"
            let turnColor = (currentMatch.isYourTurn ?? false) ? myColor : enemyColor
            chip(label: "TURN", value: turnText, icon: "person.fill", tint: turnColor)
        }
    }
    
    private func chip(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(FontStyles.iconTiny).foregroundColor(.white)
                .frame(width: 28, height: 28).background(tint).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(value).font(FontStyles.labelBold).foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 48).padding(.horizontal, 10)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    // MARK: - Arena
    
    private var arenaCard: some View {
        ZStack {
            LinearGradient(colors: [KingdomTheme.Colors.parchmentRich, KingdomTheme.Colors.parchmentDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                HStack {
                    nameplate(name: myDisplayName, subtitle: "ATK \(myAttack) / DEF \(myDefense)", isYou: true)
                    Spacer()
                    nameplate(name: opponentDisplayName, subtitle: "ATK \(opponentAttack) / DEF \(opponentDefense)", isYou: false)
                }.padding(12)
                Spacer()
                HStack {
                    Image(systemName: "figure.fencing").font(FontStyles.displayLarge).foregroundColor(myColor)
                    Spacer()
                    Image(systemName: "figure.fencing").font(FontStyles.displayLarge).foregroundColor(enemyColor).scaleEffect(x: -1, y: 1)
                }.padding(.horizontal, 20).padding(.bottom, 16)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium))
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    private func nameplate(name: String, subtitle: String, isYou: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isYou ? "YOU" : name).font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkDark)
            Text(subtitle).font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
    }
    
    // MARK: - Status
    
    private var statusCard: some View {
        HStack {
            Image(systemName: statusIcon).font(FontStyles.headingLarge).foregroundColor(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(FontStyles.labelBold).foregroundColor(KingdomTheme.Colors.inkDark)
                Text(statusSubtitle).font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            Spacer()
            if let roll = viewModel.displayedRolls.last, !viewModel.isAnimating {
                outcomeBadge(roll.outcome)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    private var statusIcon: String {
        if viewModel.isAnimating { return "scope" }
        if currentMatch.isYourTurn ?? false { return "arrow.right.circle.fill" }
        return "hourglass.circle.fill"
    }
    
    private var statusColor: Color {
        if viewModel.isAnimating { return myColor }  // Animation always uses your color since you're watching
        if currentMatch.isYourTurn ?? false { return myColor }
        return KingdomTheme.Colors.inkMedium
    }
    
    private var statusTitle: String {
        if viewModel.isAnimating {
            // During animation, show who's attacking based on current roll
            if let roll = viewModel.currentRoll {
                return roll.attackerName.map { "\($0.uppercased()) ATTACKING..." } ?? "ATTACKING..."
            }
        }
        if let roll = viewModel.displayedRolls.last, !viewModel.isAnimating {
            return roll.outcome == "critical" ? "CRITICAL!" : (roll.outcome == "hit" ? "HIT!" : "BLOCKED")
        }
        return (currentMatch.isYourTurn ?? false) ? "Your turn" : "Waiting..."
    }
    
    private var statusSubtitle: String {
        if viewModel.isAnimating { return "Rolling..." }
        return (currentMatch.isYourTurn ?? false) ? "Tap Attack to swing" : "\(opponentDisplayName)'s turn"
    }
    
    private func outcomeBadge(_ outcome: String) -> some View {
        let label = outcome == "critical" ? "CRIT!" : (outcome == "hit" ? "HIT!" : "MISS")
        let color: Color = outcome == "critical" ? myColor : (outcome == "hit" ? myColor.opacity(0.8) : Color.gray)
        return Text(label).font(FontStyles.labelBold).foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6).background(color).clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Probability Bar
    
    private var probabilityBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(barTitle).font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                if !oddsLoaded {
                    Text("Loading...").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkLight)
                } else if showRollMarker {
                    Text("Rolled: \(rollDisplayValue)").font(FontStyles.labelBadge).foregroundColor(markerColor(rollDisplayValue))
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color(white: 0.35)).frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        Rectangle().fill(displayBarColor.opacity(0.7)).frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        Rectangle().fill(displayBarColor)
                    }.clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2)
                    
                    HStack(spacing: 0) {
                        Text("MISS").font(FontStyles.labelBadge).foregroundColor(.white).lineLimit(1).frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        Text("HIT").font(FontStyles.labelBadge).foregroundColor(.white).lineLimit(1).frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        Text("CRIT").font(FontStyles.labelBadge).foregroundColor(.white).lineLimit(1).frame(maxWidth: .infinity)
                    }
                    
                    // Roll marker
                    if showRollMarker {
                        // Color based on whose turn (from server)
                        let markerColor: Color = (currentMatch.isYourTurn ?? false) ? myColor : enemyColor
                        marker(value: rollDisplayValue, color: markerColor, geo: geo)
                    }
                }
            }.frame(height: 20)
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private var barTitle: String {
        if viewModel.isAnimating {
            if let roll = viewModel.currentRoll, let name = roll.attackerName {
                return "\(name.uppercased()) ROLLING..."
            }
            return "ROLLING..."
        }
        return (currentMatch.isYourTurn ?? false) ? "YOUR ATTACK ODDS" : "\(opponentDisplayName.uppercased())'S ODDS"
    }
    
    private var displayBarColor: Color {
        (currentMatch.isYourTurn ?? false) ? myColor : enemyColor
    }
    
    private func markerColor(_ value: Int) -> Color {
        if value >= (100 - critChance) { return myColor }
        if value >= missChance { return myColor.opacity(0.8) }
        return Color(white: 0.35)
    }
    
    private func marker(value: Int, color: Color, geo: GeometryProxy) -> some View {
        let x = geo.size.width * CGFloat(value) / 100.0
        return Group {
            Image(systemName: "arrowtriangle.down.fill").font(FontStyles.headingSmall).foregroundColor(color)
                .shadow(color: .black, radius: 0, x: 1, y: 1).position(x: max(10, min(geo.size.width - 10, x)), y: -2)
            Rectangle().fill(color).frame(width: 3, height: 20).overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                .position(x: max(10, min(geo.size.width - 10, x)), y: 10)
        }
    }
    
    // MARK: - Turn Swings Card (UNIFIED - no my/opponent split!)
    
    private var turnSwingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title shows whose turn it is
            let isYourTurn = currentMatch.isYourTurn ?? false
            let title = isYourTurn ? "YOUR SWINGS" : "\(opponentDisplayName.uppercased())'S SWINGS"
            Text(title).font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
            
            let rolls = viewModel.displayedRolls
            if rolls.isEmpty {
                let emptyText = isYourTurn ? "Attack to see your rolls!" : "Waiting for \(opponentDisplayName)..."
                Text(emptyText).font(FontStyles.labelTiny).foregroundColor(KingdomTheme.Colors.inkLight)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(rolls.enumerated()), id: \.offset) { index, roll in
                            // Color based on whose turn (from server)
                            let rollColor = isYourTurn ? myColor : enemyColor
                            rollBadge(roll: roll, index: index + 1, color: rollColor)
                        }
                    }.padding(.horizontal, 4)
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private func rollBadge(roll: Roll, index: Int, color: Color) -> some View {
        let badgeColor: Color = roll.outcome == "critical" ? color : (roll.outcome == "hit" ? color.opacity(0.8) : Color.gray)
        let icon = roll.outcome == "critical" ? "flame.fill" : (roll.outcome == "hit" ? "checkmark.circle.fill" : "xmark")
        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.black).frame(width: 44, height: 44).offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 8).fill(badgeColor).frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                VStack(spacing: 2) {
                    Image(systemName: icon).font(FontStyles.iconTiny).foregroundColor(.white)
                    Text("\(roll.value)").font(FontStyles.labelBadge).foregroundColor(.white)
                }
            }.frame(width: 48, height: 48)
            Text("#\(index)").font(.system(size: 8, weight: .black)).foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Control Bar
    
    private var controlBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CONTROL").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("\(Int(animatedBarValue))% vs \(100 - Int(animatedBarValue))%").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            // Bar shows YOUR position (higher = winning for you)
            TugOfWarBar(value: 100 - animatedBarValue, isCaptured: currentMatch.isComplete, capturedBy: currentMatch.winner?.side, userIsAttacker: true)
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
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
                    // Use server-provided values directly
                    let canAttack = currentMatch.canAttack ?? false
                    let isYourTurn = currentMatch.isYourTurn ?? false
                    let swingsRemaining = currentMatch.yourSwingsRemaining ?? (1 + myAttack)
                    let swingsUsed = currentMatch.yourSwingsUsed ?? 0
                    
                    let buttonText = isYourTurn ? (swingsUsed > 0 ? "Swing! (\(swingsRemaining) left)" : "Attack!") : "Waiting..."
                    let canClaimTimeout = !isYourTurn && secondsRemaining <= 0 && !viewModel.isAnimating
                    
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
                            Button { Task { await viewModel.attack() } } label: {
                                HStack { Image(systemName: "figure.fencing"); Text(buttonText) }.frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.brutalist(backgroundColor: (canAttack && !viewModel.isAnimating) ? myColor : KingdomTheme.Colors.disabled, foregroundColor: .white, fullWidth: true))
                            .disabled(!(canAttack && !viewModel.isAnimating))
                            
                            Button { Task { await viewModel.forfeit() } } label: {
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
        return ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: didWin ? "trophy.fill" : "xmark.shield.fill").font(FontStyles.displayLarge).foregroundColor(.white)
                    .frame(width: 100, height: 100).brutalistBadge(backgroundColor: resultColor, cornerRadius: 25, shadowOffset: 4, borderWidth: 3)
                Text(didWin ? "VICTORY!" : "DEFEAT").font(FontStyles.displaySmall).foregroundColor(.white)
                Text(didWin ? "You dominated the arena!" : "Better luck next time...").font(FontStyles.labelMedium).foregroundColor(.white.opacity(0.8))
                if let gold = winner.goldEarned, gold > 0, didWin {
                    HStack { Image(systemName: "bitcoinsign.circle.fill"); Text("+\(gold) gold") }
                        .font(FontStyles.headingMedium).foregroundColor(KingdomTheme.Colors.imperialGold)
                }
                Button(action: { onComplete(); dismiss() }) { Text("Continue").frame(maxWidth: .infinity) }
                    .buttonStyle(.brutalist(backgroundColor: resultColor, foregroundColor: .white, fullWidth: true))
                    .padding(.horizontal, 40).padding(.top, 20)
            }.padding(30)
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
}

// MARK: - Critical Hit Data
struct CritPopupData {
    let attackerName: String
    let pushAmount: Double
}

// MARK: - Roll (for animation queue)
/// Roll from server - simple data, no isMe flag needed
struct Roll {
    let value: Int        // 0-100
    let outcome: String   // hit/miss/critical
    let attackerName: String?  // Who made this roll
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
/// DUMB RENDERER ARCHITECTURE:
/// - Backend is authoritative for all game state
/// - This view model just renders what backend tells us
/// - Only sends "attack" command, backend handles everything else
/// - Receives events and triggers animations based on them
///
@MainActor
class DuelCombatViewModel: ObservableObject {
    @Published var match: DuelMatch?
    @Published var errorMessage: String?
    
    // Rolls for animation
    @Published var rollQueue: [Roll] = []
    @Published var currentRoll: Roll?
    @Published var isAnimating: Bool = false
    @Published var displayedRolls: [Roll] = []
    
    // Odds from server (fallback if not in match)
    @Published var odds = Odds()
    
    private let api = DuelsAPI()
    private var matchId: Int?
    private var playerId: Int?
    private var cancellables = Set<AnyCancellable>()
    
    func load(match: DuelMatch, playerId: Int) async {
        self.match = match
        self.matchId = match.id
        self.playerId = playerId
        
        // Initialize odds from match (server provides, we just display)
        if let matchOdds = match.currentOdds {
            odds = Odds(miss: matchOdds.miss, hit: matchOdds.hit, crit: matchOdds.crit)
        }
        
        subscribeToEvents()
    }
    
    private func subscribeToEvents() {
        GameEventManager.shared.duelEventSubject
            .receive(on: DispatchQueue.main)
            .filter { [weak self] e in e.matchId == self?.matchId }
            .sink { [weak self] e in self?.handleEvent(e) }
            .store(in: &cancellables)
    }
    
    private func handleEvent(_ event: DuelEvent) {
        // Always update match from server (already has our perspective baked in!)
        if let m = event.match { match = m }
        
        // Update odds from match (server is source of truth)
        if let matchOdds = match?.currentOdds {
            odds = Odds(miss: matchOdds.miss, hit: matchOdds.hit, crit: matchOdds.crit)
        }
        
        // === REAL-TIME: Handle individual swings as they arrive ===
        if event.eventType == .swing,
           let rollData = event.data["roll"] as? [String: Any],
           let attackerName = event.data["attacker_name"] as? String {
            
            guard let value = rollData["value"] as? Double else { return }
            let outcome = rollData["outcome"] as? String ?? "miss"
            
            // If this is the first swing of the turn, clear previous displayed rolls
            let swingNumber = event.data["swing_number"] as? Int ?? 1
            if swingNumber == 1 {
                displayedRolls = []
            }
            
            // Queue this swing - it will animate after any currently playing
            rollQueue.append(Roll(value: Int(value), outcome: outcome, attackerName: attackerName))
            startAnimation()
        }
        
        // Turn complete - match state already updated, swings already queued via .swing events
        // This just ensures final state is correct (bar position, next turn, etc.)
        if event.eventType == .turnComplete || event.eventType == .ended {
            // Match already updated above from event.match
            // No need to re-queue rolls - they came via .swing events
        }
    }
    
    func attack() async {
        guard let matchId = matchId else { return }
        
        // Use server-provided canAttack (no client-side computation!)
        guard match?.canAttack == true && !isAnimating else { return }
        
        do {
            let r = try await api.attack(matchId: matchId)
            if r.success, let roll = r.roll {
                // Update odds from response (server is source of truth)
                if let miss = r.missChance, let hit = r.hitChancePct, let crit = r.critChance {
                    odds = Odds(miss: miss, hit: hit, crit: crit)
                }
                
                // Queue my roll with my name
                let myName = match?.myName ?? "You"
                rollQueue.append(Roll(value: Int(roll.value), outcome: roll.outcome, attackerName: myName))
                
                // Update match from response (already player-perspective!)
                if let m = r.match { match = m }
                
                startAnimation()
            } else {
                errorMessage = r.message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func startAnimation() {
        guard !isAnimating, !rollQueue.isEmpty else { return }
        currentRoll = rollQueue.removeFirst()
        isAnimating = true
    }
    
    func finishCurrentRoll() {
        if let roll = currentRoll {
            displayedRolls.append(roll)
        }
        
        if rollQueue.isEmpty {
            isAnimating = false
            currentRoll = nil
        } else {
            currentRoll = rollQueue.removeFirst()
        }
    }
    
    func startMatch() async {
        guard let matchId = matchId else { return }
        do {
            let r = try await api.startMatch(matchId: matchId)
            if r.success { match = r.match }
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
            if r.success { match = r.match }
            else { errorMessage = r.message }
        } catch { errorMessage = error.localizedDescription }
    }
    
    deinit { cancellables.removeAll() }
}
