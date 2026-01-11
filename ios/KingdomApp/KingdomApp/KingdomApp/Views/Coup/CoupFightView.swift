import SwiftUI

/// Full-screen fight experience for Coup battles
/// Uses server-side roll-by-roll system (like hunting)
struct CoupFightView: View {
    let territory: CoupTerritory
    let coup: CoupEventResponse
    let onComplete: (FightResolveResponse?) -> Void
    
    // Session state (from server)
    @State private var session: FightSessionResponse?
    @State private var lastRoll: FightRollResponse?
    @State private var resolveResult: FightResolveResponse?
    
    // UI state
    @State private var isLoading = false
    @State private var isRolling = false
    @State private var isResolving = false
    @State private var error: String?
    
    // Animation state
    @State private var rollMarkerValue: Double = 0
    @State private var showRollMarker = false
    @State private var rollAnimationRunning = false
    @State private var animatedBarValue: Double = 0
    @State private var showVictory = false
    
    private var isUserAttacker: Bool {
        coup.userSide == "attackers"
    }
    
    private var sideColor: Color {
        isUserAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
    }
    
    private var enemySideColor: Color {
        isUserAttacker ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.buttonDanger
    }
    
    /// Can user roll again?
    private var canRoll: Bool {
        session?.canRoll == true && !isRolling && !rollAnimationRunning && !isResolving
    }
    
    /// Can user resolve?
    private var canResolve: Bool {
        guard let session = session else { return false }
        return !session.canRoll && !isRolling && !rollAnimationRunning && !isResolving && resolveResult == nil
    }
    
    /// Roll bar percentages from backend (no frontend calcs)
    private var injureChance: Int { session?.injureChance ?? 5 }
    private var hitChance: Int { session?.hitChance ?? 45 }
    private var missChance: Int { session?.missChance ?? 50 }
    private var totalSuccess: Int { injureChance + hitChance }
    
    // MARK: - Outcome Colors (use side colors for consistency)
    private var critColor: Color { sideColor }  // Your side color, bright
    private var hitColor: Color { sideColor.opacity(0.7) }  // Your side color, slightly faded
    private static let missColor = Color(white: 0.35)  // Dark gray for miss
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            if isLoading && session == nil {
                loadingView
            } else if let error = error {
                errorView(error: error)
            } else if session != nil {
                mainContent
            }
            
            // Victory overlay
            if showVictory, let result = resolveResult, result.territory.isCaptured {
                victoryOverlay(capturedBy: result.territory.capturedBy ?? "")
            }
        }
        .onAppear {
            animatedBarValue = territory.controlBar
            startFightSession()
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
                    probabilityBar
                    
                    rollHistoryCard
                    
                    if resolveResult != nil {
                        territoryBarSection
                    }
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: session?.territoryIcon ?? territory.icon)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(sideColor)
                    
                    Text((session?.territoryDisplayName ?? territory.displayName).uppercased())
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Text("Territory Battle")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            Button(action: { onComplete(resolveResult) }) {
                Image(systemName: "xmark")
                    .font(FontStyles.iconTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    )
            }
        }
    }
    
    // MARK: - HUD Chips
    
    private var hudChips: some View {
        HStack(spacing: KingdomTheme.Spacing.small) {
            hudChip(
                label: "SIDE",
                value: isUserAttacker ? "ATK" : "DEF",
                icon: isUserAttacker ? "figure.fencing" : "shield.fill",
                tint: sideColor
            )
            
            hudChip(
                label: "SUCCESS",
                value: "\(totalSuccess)%",
                icon: "scope",
                tint: totalSuccess >= 50 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning
            )
            
            rollsChip
        }
    }
    
    private func hudChip(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconTiny)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(value)
                    .font(FontStyles.labelBold)
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
    
    private var rollsChip: some View {
        let total = session?.maxRolls ?? 1
        let remaining = session?.rollsRemaining ?? 0
        
        return HStack(spacing: 8) {
            Image(systemName: "dice.fill")
                .font(FontStyles.iconTiny)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(KingdomTheme.Colors.inkDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("LEFT")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                HStack(spacing: 3) {
                    ForEach(0..<max(1, total), id: \.self) { i in
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
            LinearGradient(
                colors: [KingdomTheme.Colors.parchmentRich, KingdomTheme.Colors.parchmentDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack {
                HStack {
                    nameplate(title: "YOU", subtitle: isUserAttacker ? "Coupers" : "Crown")
                    Spacer()
                    nameplate(title: "ENEMY", subtitle: isUserAttacker ? "Crown" : "Coupers")
                }
                .padding(12)
                
                Spacer()
                
                HStack {
                    Image(systemName: isUserAttacker ? "figure.fencing" : "shield.fill")
                        .font(FontStyles.displayLarge)
                        .foregroundColor(sideColor)
                    
                    Spacer()
                    
                    Image(systemName: isUserAttacker ? "crown.fill" : "figure.fencing")
                        .font(FontStyles.displayLarge)
                        .foregroundColor(enemySideColor)
                        .opacity(0.7)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium))
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    private func nameplate(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FontStyles.labelBadge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            Text(subtitle)
                .font(FontStyles.labelBadge)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
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
    
    // MARK: - Roll Result Card
    
    private var rollResultCard: some View {
        VStack(spacing: 10) {
            ZStack {
                if rollAnimationRunning {
                    rollingRow
                } else if let roll = lastRoll {
                    resultRow(roll: roll.roll, message: roll.message)
                } else if let session = session, !session.canRoll {
                    finalResultRow(outcome: session.bestOutcome)
                } else {
                    promptRow
                }
            }
            .frame(height: 50)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: session?.rollsCompleted)
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    private var promptRow: some View {
        HStack {
            Image(systemName: "arrow.right.circle.fill")
                .font(FontStyles.headingLarge)
                .foregroundColor(sideColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready to strike!")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text("Tap Swing! to attack")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
    }
    
    private var rollingRow: some View {
        HStack {
            Text("SWINGING...")
                .font(FontStyles.labelBold)
                .foregroundColor(sideColor)

            Spacer()

            Image(systemName: "figure.fencing")
                .font(FontStyles.displayLarge)
                .foregroundColor(sideColor)
                .symbolEffect(.bounce, options: .repeating)
        }
    }
    
    private var rollMarkerColor: Color {
        // Backend: low roll = crit, mid = hit, high = miss
        if rollMarkerValue <= Double(injureChance) {
            return critColor
        } else if rollMarkerValue <= Double(totalSuccess) {
            return hitColor
        }
        return Self.missColor
    }
    
    private func resultRow(roll: CoupRollResult, message: String) -> some View {
        let (icon, color, label) = outcomeDisplay(roll.outcome)
        let flavorText = swingFlavorText(roll.outcome)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(FontStyles.labelTiny)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text(flavorText)
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(FontStyles.displayLarge)
                .foregroundColor(color)
        }
    }
    
    private func swingFlavorText(_ outcome: String) -> String {
        switch outcome {
        case "injure": return "Your blade finds flesh! Enemy wounded!"
        case "hit": return "A solid strike lands true!"
        default: return "Your swing is deflected..."
        }
    }
    
    private func finalResultRow(outcome: String) -> some View {
        let (icon, color, label) = finalOutcomeDisplay(outcome)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(FontStyles.labelBadge)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("Tap Push! to claim ground")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(FontStyles.displayLarge)
                .foregroundColor(color)
        }
    }
    
    private func outcomeDisplay(_ outcome: String) -> (String, Color, String) {
        switch outcome {
        case "injure": return ("flame.fill", critColor, "⚔️ CRITICAL!")
        case "hit": return ("checkmark.circle.fill", hitColor, "💥 HIT!")
        default: return ("shield.slash", Self.missColor, "BLOCKED")
        }
    }
    
    private func finalOutcomeDisplay(_ outcome: String) -> (String, Color, String) {
        switch outcome {
        case "injure": return ("flame.fill", critColor, "⚔️ ENEMY WOUNDED!")
        case "hit": return ("bolt.fill", hitColor, "💥 STRUCK TRUE!")
        default: return ("shield.fill", Self.missColor, "ALL BLOCKED")
        }
    }
    
    // MARK: - Probability Bar
    
    private var probabilityBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(rollAnimationRunning ? "SWINGING..." : (showRollMarker ? "YOUR ROLL" : "ATTACK ODDS"))
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                if !rollAnimationRunning && showRollMarker {
                    Text("Rolled: \(Int(rollMarkerValue))")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(rollMarkerColor)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Roll bar: MISS (left) | HIT (middle) | CRITICAL (right)
                    // Higher roll = better outcome (like hunting)
                    HStack(spacing: 0) {
                        // MISS zone (left)
                        let missWidth = CGFloat(missChance) / 100.0 * geo.size.width
                        Rectangle().fill(Self.missColor).frame(width: missWidth)
                        
                        // HIT zone (middle)
                        let hitWidth = CGFloat(hitChance) / 100.0 * geo.size.width
                        Rectangle().fill(hitColor).frame(width: hitWidth)
                        
                        // CRITICAL zone (right)
                        Rectangle().fill(critColor)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2)
                    
                    // Labels
                    HStack {
                        Text("MISS")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.leading, 6)
                        Spacer()
                        Text("HIT")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(.white)
                        Spacer()
                        Text("CRIT")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.trailing, 6)
                    }
                    
                    if showRollMarker {
                        // Invert marker position: low roll value = left (miss), high = right (crit)
                        let invertedValue = 100 - rollMarkerValue
                        let markerX = geo.size.width * CGFloat(invertedValue) / 100.0
                        
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(FontStyles.headingSmall)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                            .position(x: max(10, min(geo.size.width - 10, markerX)), y: -2)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3, height: 20)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                            .position(x: max(10, min(geo.size.width - 10, markerX)), y: 10)
                    }
                }
            }
            .frame(height: 20)
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    // MARK: - Roll History
    
    private var rollHistoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header changes based on state
            if let result = resolveResult {
                Text("FIGHT OUTCOME")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else {
                Text("Best Swing is Used")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            // Content: rolls OR final result (same height)
            if let result = resolveResult {
                // Show outcome inline
                outcomeRow(result: result)
            } else if let rolls = session?.rolls, !rolls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(rolls.enumerated()), id: \.offset) { index, roll in
                            rollHistoryBadge(roll: roll, index: index + 1)
                        }
                    }
                }
            } else {
                Text("No rolls yet - tap Swing! to begin")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private func outcomeRow(result: FightResolveResponse) -> some View {
        let (icon, color, title, subtitle) = finalOutcomeInfo(result)
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.displaySmall)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Text(subtitle)
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            if result.bestOutcome != "miss" {
                Text("+\(String(format: "%.1f", result.pushAmount))%")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(sideColor)
            }
        }
    }
    
    private func rollHistoryBadge(roll: CoupRollResult, index: Int) -> some View {
        let (icon, color, _) = outcomeDisplay(roll.outcome)
        
        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 44, height: 44)
                
                VStack(spacing: 2) {
                    Image(systemName: icon).font(FontStyles.iconTiny).foregroundColor(.white)
                    Text("\(Int(roll.value))").font(FontStyles.labelBadge).foregroundColor(.white)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
            
            Text("#\(index)").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    private func finalOutcomeInfo(_ result: FightResolveResponse) -> (String, Color, String, String) {
        switch result.bestOutcome {
        case "injure":
            let enemyName = result.injuredPlayerName ?? "an enemy"
            return ("flame.fill", critColor, "⚔️ CRITICAL!", "Wounded \(enemyName)!")
        case "hit":
            return ("bolt.fill", hitColor, "💥 HIT!", "Struck the enemy!")
        default:
            return ("shield.fill", Self.missColor, "🛡️ BLOCKED", "No ground gained")
        }
    }
    
    // MARK: - Territory Bar Section
    
    private var territoryBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TERRITORY PUSH")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                if let result = resolveResult, result.bestOutcome != "miss" {
                    Text("+\(String(format: "%.1f", result.pushAmount))%")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(sideColor)
                }
            }
            
            TugOfWarBar(
                value: animatedBarValue,
                isCaptured: resolveResult?.territory.isCaptured ?? false,
                capturedBy: resolveResult?.territory.capturedBy,
                userIsAttacker: isUserAttacker
            )
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black).frame(height: 3)
            
            bottomButtonContent
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    @ViewBuilder
    private var bottomButtonContent: some View {
        if isResolving {
            HStack {
                ProgressView().tint(sideColor)
                Text("Pushing territory...")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        } else if resolveResult != nil {
            Button {
                onComplete(resolveResult)
            } label: {
                HStack {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(backgroundColor: sideColor, foregroundColor: .white, fullWidth: true))
        } else {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Button { executeRoll() } label: {
                    HStack { Image(systemName: "figure.fencing"); Text("Swing!") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: canRoll ? sideColor : KingdomTheme.Colors.disabled,
                    foregroundColor: .white, fullWidth: true
                ))
                .disabled(!canRoll)
                
                Button { resolveFight() } label: {
                    HStack { Image(systemName: "arrow.right.circle.fill"); Text("Push!") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: canResolve ? sideColor : KingdomTheme.Colors.disabled,
                    foregroundColor: .white, fullWidth: true
                ))
                .disabled(!canResolve)
            }
        }
    }
    
    // MARK: - Loading & Error
    
    private var loadingView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    headerRow
                    
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5).tint(sideColor)
                        Text("Starting fight...")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.top, KingdomTheme.Spacing.medium)
            }
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(FontStyles.displayLarge)
                .foregroundColor(KingdomTheme.Colors.error)
            
            Text("Fight Failed")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(error)
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Button("Go Back") { onComplete(nil) }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Victory Overlay
    
    private func victoryOverlay(capturedBy: String) -> some View {
        let isOurCapture = (capturedBy == "attackers" && isUserAttacker) || (capturedBy == "defenders" && !isUserAttacker)
        let sideColor = capturedBy == "attackers" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        let icon = isOurCapture ? "flag.fill" : "xmark.shield.fill"
        let title = isOurCapture ? "TERRITORY CAPTURED!" : "TERRITORY LOST!"
        let subtitle = isOurCapture ? "Your side has taken control!" : "The enemy has captured this territory!"
        
        return ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(FontStyles.displayLarge)
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(backgroundColor: sideColor, cornerRadius: 25, shadowOffset: 4, borderWidth: 3)
                
                Text(title).font(FontStyles.displaySmall).foregroundColor(.white)
                Text(subtitle).font(FontStyles.labelMedium).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center)
                
                Button(action: { onComplete(resolveResult) }) {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: sideColor, foregroundColor: .white, fullWidth: true))
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            .padding(30)
        }
        .transition(.opacity)
    }
    
    // MARK: - API Actions
    
    private func startFightSession() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/coups/\(coup.id)/fight/start",
                    method: "POST",
                    body: ["territory": territory.name]
                )
                let response: FightSessionResponse = try await APIClient.shared.execute(request)
                
                await MainActor.run {
                    self.session = response
                    self.isLoading = false
                    self.animatedBarValue = response.barBefore
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func executeRoll() {
        guard canRoll else { return }
        
        isRolling = true
        rollAnimationRunning = true
        showRollMarker = true
        rollMarkerValue = 0
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/coups/\(coup.id)/fight/roll",
                    method: "POST"
                )
                let response: FightRollResponse = try await APIClient.shared.execute(request)
                
                // Run animation THEN update state
                await runRollAnimation(targetValue: response.roll.value)
                
                await MainActor.run {
                    self.lastRoll = response
                    
                    // Update session with new roll
                    if var updatedSession = self.session {
                        var rolls = updatedSession.rolls
                        rolls.append(response.roll)
                        self.session = FightSessionResponse(
                            success: true,
                            message: "",
                            territoryName: updatedSession.territoryName,
                            territoryDisplayName: updatedSession.territoryDisplayName,
                            territoryIcon: updatedSession.territoryIcon,
                            side: updatedSession.side,
                            maxRolls: updatedSession.maxRolls,
                            rollsCompleted: response.rollsCompleted,
                            rollsRemaining: response.rollsRemaining,
                            rolls: rolls,
                            missChance: updatedSession.missChance,
                            hitChance: updatedSession.hitChance,
                            injureChance: updatedSession.injureChance,
                            bestOutcome: response.bestOutcome,
                            canRoll: response.canRoll,
                            barBefore: updatedSession.barBefore
                        )
                    }
                    
                    self.isRolling = false
                    self.rollAnimationRunning = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isRolling = false
                    self.rollAnimationRunning = false
                }
            }
        }
    }
    
    @MainActor
    private func runRollAnimation(targetValue: Double) async {
        var positions: [Double] = []
        for i in stride(from: 0, through: 100, by: 3) { positions.append(Double(i)) }
        if targetValue < 100 {
            for i in stride(from: 98, through: Int(targetValue), by: -3) { positions.append(Double(i)) }
        }
        if positions.last != targetValue { positions.append(targetValue) }
        
        for pos in positions {
            rollMarkerValue = pos
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        
        rollMarkerValue = targetValue
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func resolveFight() {
        guard canResolve else { return }
        
        isResolving = true
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/coups/\(coup.id)/fight/resolve",
                    method: "POST"
                )
                let response: FightResolveResponse = try await APIClient.shared.execute(request)
                
                await MainActor.run {
                    self.resolveResult = response
                    
                    // Animate bar movement
                    withAnimation(.easeInOut(duration: 1.2)) {
                        self.animatedBarValue = response.barAfter
                    }
                    
                    self.isResolving = false
                    
                    // Show victory overlay if territory was captured
                    if response.territory.isCaptured {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                self.showVictory = true
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isResolving = false
                }
            }
        }
    }
}
