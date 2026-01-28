import SwiftUI

// MARK: - Roll Display Data (simplified for popup)
struct RollDisplay: Identifiable {
    let id = UUID()
    let value: Int
    let outcome: String  // hit, miss, critical
}

// MARK: - Round Result Data
struct RoundResultData {
    let pushAmount: Double  // Positive = you pushed, negative = opponent pushed
    let outcome: String     // hit, critical, parried
    let myBestOutcome: String
    let oppBestOutcome: String
    let myStyle: String
    let oppStyle: String
    let roundNumber: Int
    let parried: Bool
    // NEW: actual rolls for display
    let myRolls: [RollDisplay]
    let opponentRolls: [RollDisplay]
}

// MARK: - Round Result Popup
struct RoundResultPopup: View {
    let data: RoundResultData
    let myColor: Color
    let enemyColor: Color
    let myName: String
    let opponentName: String
    let gameConfig: DuelGameConfig?
    let onDismiss: () -> Void
    
    // Animation phases
    @State private var phase: AnimationPhase = .initial
    @State private var myRollsRevealed: Int = 0
    @State private var oppRollsRevealed: Int = 0
    @State private var animatedPush: Double = 0
    
    enum AnimationPhase {
        case initial
        case showingMySwings
        case showingOppSwings
        case showingResult
        case showingPush
        case complete
    }
    
    private var isParried: Bool { data.parried || abs(data.pushAmount) < 0.1 }
    private var iWon: Bool { data.pushAmount > 0 }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Round number header
                Text("ROUND \(data.roundNumber) RESULTS")
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // YOUR SWINGS
                swingsSection(
                    title: "YOUR SWINGS",
                    rolls: data.myRolls,
                    revealedCount: myRollsRevealed,
                    color: myColor,
                    style: data.myStyle,
                    isVisible: phase != .initial
                )
                
                // OPPONENT'S SWINGS
                swingsSection(
                    title: "\(opponentName.uppercased())'S SWINGS",
                    rolls: data.opponentRolls,
                    revealedCount: oppRollsRevealed,
                    color: enemyColor,
                    style: data.oppStyle,
                    isVisible: phase.rawValue >= AnimationPhase.showingOppSwings.rawValue
                )
                
                // RESULT BANNER
                if phase.rawValue >= AnimationPhase.showingResult.rawValue {
                    resultBanner
                        .transition(.scale.combined(with: .opacity))
                }
                
                // BAR PUSH
                if phase.rawValue >= AnimationPhase.showingPush.rawValue {
                    VStack(spacing: 6) {
                        Text("BAR PUSH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        
                        Text(pushText)
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundColor(pushColor)
                            .contentTransition(.numericText())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Continue button (only when complete)
                if phase == .complete {
                    Button(action: onDismiss) {
                        Text("CONTINUE")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.parchment)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                        .fill(Color.black)
                                        .offset(x: 3, y: 3)
                                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                        .fill(resultColor)
                                        .overlay(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall).stroke(Color.black, lineWidth: 2))
                                }
                            )
                    }
                    .padding(.horizontal, 16)
                    .transition(.opacity)
                }
            }
            .padding(20)
            .frame(width: 340)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
        }
        .onAppear {
            runAnimationSequence()
        }
    }
    
    // MARK: - Swings Section
    
    private func swingsSection(title: String, rolls: [RollDisplay], revealedCount: Int, color: Color, style: String, isVisible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with style chip
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(color)
                
                Spacer()
                
                styleChip(style: style, color: color)
            }
            
            // Roll badges
            HStack(spacing: 8) {
                if rolls.isEmpty {
                    Text("No swings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                } else {
                    ForEach(Array(rolls.enumerated()), id: \.element.id) { index, roll in
                        rollBadge(roll: roll, color: color, isRevealed: index < revealedCount)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
    }
    
    private func rollBadge(roll: RollDisplay, color: Color, isRevealed: Bool) -> some View {
        let config = getOutcomeConfig(roll.outcome)
        
        return VStack(spacing: 4) {
            ZStack {
                // Shadow
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                    .offset(x: 2, y: 2)
                
                // Badge - just the icon, no number
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRevealed ? config.color : KingdomTheme.Colors.disabled.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                
                if isRevealed {
                    Image(systemName: config.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("?")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Outcome label from server config
            if isRevealed {
                Text(config.label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(config.color)
            }
        }
        .scaleEffect(isRevealed ? 1.0 : 0.9)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRevealed)
    }
    
    /// Get outcome display config from server, with fallback
    private func getOutcomeConfig(_ outcome: String) -> (label: String, icon: String, color: Color) {
        // Try to get from server config
        if let serverConfig = gameConfig?.outcomes?[outcome.lowercased()] {
            let color = KingdomTheme.Colors.color(fromThemeName: serverConfig.color)
            return (serverConfig.label, serverConfig.icon, color)
        }
        
        // Fallback if server config not available
        switch outcome.lowercased() {
        case "critical", "crit":
            return ("CRIT", "flame.fill", KingdomTheme.Colors.imperialGold)
        case "hit":
            return ("HIT", "checkmark.circle.fill", KingdomTheme.Colors.buttonSuccess)
        default:
            return ("MISS", "xmark.circle.fill", KingdomTheme.Colors.disabled)
        }
    }
    
    // MARK: - Result Banner
    
    private var resultBanner: some View {
        HStack(spacing: 16) {
            // Your final outcome
            VStack(spacing: 4) {
                Text("YOU")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                outcomeIcon(outcome: data.myBestOutcome, isWinner: iWon && !isParried)
                outcomeLabel(outcome: data.myBestOutcome)
            }
            
            // Result in middle
            VStack(spacing: 4) {
                if isParried {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.disabled)
                    Text("PARRIED")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.disabled)
                } else if iWon {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(myColor)
                    Text("YOU WIN!")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(myColor)
                } else {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(enemyColor)
                    Text("YOU LOSE")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(enemyColor)
                }
            }
            .frame(minWidth: 70)
            
            // Opponent final outcome
            VStack(spacing: 4) {
                Text("OPP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                outcomeIcon(outcome: data.oppBestOutcome, isWinner: !iWon && !isParried)
                outcomeLabel(outcome: data.oppBestOutcome)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(resultColor.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(resultColor.opacity(0.5), lineWidth: 2))
        )
    }
    
    private func outcomeLabel(outcome: String) -> some View {
        let config = getOutcomeConfig(outcome)
        
        return Text(config.label)
            .font(.system(size: 11, weight: .black))
            .foregroundColor(config.color)
    }
    
    private func outcomeIcon(outcome: String, isWinner: Bool) -> some View {
        let config = getOutcomeConfig(outcome)
        
        return ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 36, height: 36)
                .offset(x: 1, y: 1)
            
            Circle()
                .fill(KingdomTheme.Colors.parchmentLight)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(config.color, lineWidth: isWinner ? 3 : 2))
            
            Image(systemName: config.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(config.color)
        }
        .scaleEffect(isWinner ? 1.15 : 1.0)
    }
    
    // MARK: - Helpers
    
    private var pushText: String {
        if isParried {
            return "0%"
        } else if iWon {
            return "+\(String(format: "%.1f", animatedPush))%"
        } else {
            return "-\(String(format: "%.1f", abs(animatedPush)))%"
        }
    }
    
    private var pushColor: Color {
        if isParried { return KingdomTheme.Colors.disabled }
        return iWon ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private var resultColor: Color {
        if isParried { return KingdomTheme.Colors.buttonSecondary }
        return iWon ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private func styleChip(style: String, color: Color) -> some View {
        let icon = gameConfig?.attackStyles?.first(where: { $0.id == style })?.icon ?? "equal.circle.fill"
        let name = gameConfig?.attackStyles?.first(where: { $0.id == style })?.name ?? style.capitalized
        
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(name.uppercased())
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.4), lineWidth: 1))
        )
    }
    
    // MARK: - Animation Sequence
    
    private func runAnimationSequence() {
        // Phase 1: Show my swings section, reveal rolls one by one
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            phase = .showingMySwings
        }
        
        // Reveal my rolls one by one
        for i in 0..<data.myRolls.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.25) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    myRollsRevealed = i + 1
                }
            }
        }
        
        let myRollsTime = 0.3 + Double(data.myRolls.count) * 0.25 + 0.3
        
        // Phase 2: Show opponent swings section
        DispatchQueue.main.asyncAfter(deadline: .now() + myRollsTime) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                phase = .showingOppSwings
            }
        }
        
        // Reveal opponent rolls one by one
        for i in 0..<data.opponentRolls.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + myRollsTime + 0.3 + Double(i) * 0.25) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    oppRollsRevealed = i + 1
                }
            }
        }
        
        let oppRollsTime = myRollsTime + 0.3 + Double(data.opponentRolls.count) * 0.25 + 0.4
        
        // Phase 3: Show result
        DispatchQueue.main.asyncAfter(deadline: .now() + oppRollsTime) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                phase = .showingResult
            }
        }
        
        // Phase 4: Show push
        DispatchQueue.main.asyncAfter(deadline: .now() + oppRollsTime + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                phase = .showingPush
            }
            withAnimation(.easeOut(duration: 0.8)) {
                animatedPush = abs(data.pushAmount)
            }
        }
        
        // Phase 5: Complete - show button
        DispatchQueue.main.asyncAfter(deadline: .now() + oppRollsTime + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .complete
            }
        }
    }
}

// Extension for comparing phases
extension RoundResultPopup.AnimationPhase: Comparable {
    var rawValue: Int {
        switch self {
        case .initial: return 0
        case .showingMySwings: return 1
        case .showingOppSwings: return 2
        case .showingResult: return 3
        case .showingPush: return 4
        case .complete: return 5
        }
    }
    
    static func < (lhs: RoundResultPopup.AnimationPhase, rhs: RoundResultPopup.AnimationPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
