import SwiftUI

/// Battle simulator for coup combat design.
///
/// TWO BARS:
/// 1. Tug of War (0-100) - who's winning overall
/// 2. Roll Outcome Bar - when you roll: MISS | HIT | INJURE
///
/// Each player rolls ONCE per round. Everyone participates.
/// 10,000 players = 10,000 rolls.
///
/// Roll outcomes:
///   MISS - enemy defense blocks, nothing happens
///   HIT - pushes the tug of war bar (value scales with army size + leadership)
///   INJURE - removes an enemy player from battle (10% of attack section)
///
/// PUSH VALUE PER HIT:
///   Bigger army = each hit worth LESS (diminishing returns)
///   Leadership DAMPENS size penalty (higher = less penalty)
///   Formula: 1 / size^(kSizeExponentBase - leadership × kLeadershipDampeningPerTier)
///   See kSizeExponentBase and kLeadershipDampeningPerTier constants at top of struct
struct BattleSimulatorView: View {
    
    // ============================================================
    // TUNING CONSTANTS - ADJUST THESE TO BALANCE COMBAT
    // ============================================================
    
    /// Base exponent for size penalty (before leadership)
    /// Higher = harsher penalty for large armies
    /// 0.70 = numbers still matter a lot
    /// 0.85 = near equilibrium (equal stats = roughly equal push)
    /// 1.00 = pure equilibrium (size doesn't matter at all)
    static let kSizeExponentBase: Double = 0.85
    
    /// How much leadership reduces the size penalty (per tier)
    /// T5 leadership reduces exponent by: 5 × this value
    static let kLeadershipDampeningPerTier: Double = 0.02
    
    /// Injury scaling exponent (lower = more injuries get through)
    /// 0.5 = sqrt (harsh scaling), 0.3 = gentler, 0.0 = no scaling
    static let kInjuryScaleExponent: Double = 0.30
    
    // Example results with current values:
    // T1 leadership: exponent = 0.70 - 0.04 = 0.66
    // T5 leadership: exponent = 0.70 - 0.20 = 0.50
    
    // ============================================================
    
    // Side A inputs
    @State private var sideASize: Int = 10_000
    @State private var sideAAvgAttack: Int = 5
    @State private var sideAAvgDefense: Int = 3
    @State private var sideAAvgLeadership: Int = 3
    
    // Side B inputs
    @State private var sideBSize: Int = 300
    @State private var sideBAvgAttack: Int = 5
    @State private var sideBAvgDefense: Int = 5
    @State private var sideBAvgLeadership: Int = 5
    
    // Active players (not currently injured)
    @State private var sideAActive: Int = 10_000
    @State private var sideBActive: Int = 300
    
    // Injured players sitting out this round (return next round)
    @State private var sideASittingOut: Int = 0
    @State private var sideBSittingOut: Int = 0

    // Tug of War bar (0..100) - 50 = tied, 100 = A wins, 0 = B wins
    @State private var bar: Double = 50.0
    @State private var stepCount: Int = 0
    @State private var stepEvents: [StepEvent] = []
    @State private var isAutoStepping = false
    @State private var consoleLoggingEnabled = true
    @State private var resolvedWinner: String? = nil
    
    var body: some View {
        Form {
            Section("Side A (Claimant)") {
                sideInputs(
                    size: $sideASize,
                    attack: $sideAAvgAttack,
                    defense: $sideAAvgDefense,
                    leadership: $sideAAvgLeadership
                )
            }
            
            Section("Side B (Crown)") {
                sideInputs(
                    size: $sideBSize,
                    attack: $sideBAvgAttack,
                    defense: $sideBAvgDefense,
                    leadership: $sideBAvgLeadership
                )
            }
            
            Section("Battle") {
                // Tug of War bar
                battleBar(value: bar)
                    .frame(height: 44)
                    .padding(.vertical, 6)
                
                if let resolvedWinner {
                    Text("Winner: \(resolvedWinner)")
                        .font(.headline)
                        .foregroundStyle(resolvedWinner == "Side A" ? .green : .red)
                }
                
                // Active players
                HStack {
                    VStack(alignment: .leading) {
                        Text("A Active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(sideAActive.formatted())\(sideASittingOut > 0 ? " (\(sideASittingOut) out)" : "")")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("B Active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(sideBActive.formatted())\(sideBSittingOut > 0 ? " (\(sideBSittingOut) out)" : "")")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.red)
                    }
                }
                
                Divider()
                
                // Roll bars for each side
                let rollBarA = RollBar.create(yourAttack: sideAAvgAttack, enemyDefense: sideBAvgDefense)
                let rollBarB = RollBar.create(yourAttack: sideBAvgAttack, enemyDefense: sideAAvgDefense)
                
                let sideA = CombatSide(activeSize: sideAActive, avgAttack: sideAAvgAttack, avgDefense: sideAAvgDefense, avgLeadership: sideAAvgLeadership)
                let sideB = CombatSide(activeSize: sideBActive, avgAttack: sideBAvgAttack, avgDefense: sideBAvgDefense, avgLeadership: sideBAvgLeadership)
                
                Group {
                    HStack {
                        Text("A: \(sideA.rollCount.formatted()) rolls")
                            .font(.caption.bold())
                        Spacer()
                        Text("push/hit: \(sideA.pushPerHit, specifier: "%.4f")")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    rollBarView(bar: rollBarA, color: .blue)
                        .frame(height: 24)
                }
                
                Group {
                    HStack {
                        Text("B: \(sideB.rollCount.formatted()) rolls")
                            .font(.caption.bold())
                        Spacer()
                        Text("push/hit: \(sideB.pushPerHit, specifier: "%.4f")")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    rollBarView(bar: rollBarB, color: .red)
                        .frame(height: 24)
                }
                
                Toggle("Console logging", isOn: $consoleLoggingEnabled)
                    .tint(KingdomTheme.Colors.royalBlue)
                
                HStack {
                    Button("Reset") {
                        resetBattle()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Step") {
                        stepOnce()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAutoStepping)
                    
                    Button(isAutoStepping ? "Stop" : "Auto x20") {
                        if isAutoStepping {
                            isAutoStepping = false
                        } else {
                            Task { await autoStep(times: 20) }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                if !stepEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Rounds")
                            .font(.headline)
                        
                        ForEach(stepEvents.suffix(10)) { e in
                            HStack(alignment: .firstTextBaseline) {
                                Text("#\(e.step)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(e.summary)
                                    .font(.caption)
                                Spacer()
                                Text(e.delta >= 0 ? "+\(e.delta.formatted(.number.precision(.fractionLength(1))))" : e.delta.formatted(.number.precision(.fractionLength(1))))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(e.delta >= 0 ? .blue : .red)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle("Battle Simulator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            resetBattle()
        }
    }
    
    @ViewBuilder
    private func sideInputs(size: Binding<Int>, attack: Binding<Int>, defense: Binding<Int>, leadership: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Players: \(size.wrappedValue.formatted())", value: size, in: 1...100_000, step: 500)
            Stepper("Avg Attack: \(attack.wrappedValue)", value: attack, in: 1...5)
            Stepper("Avg Defense: \(defense.wrappedValue)", value: defense, in: 1...5)
            Stepper("Avg Leadership: \(leadership.wrappedValue)", value: leadership, in: 1...5)
        }
    }
}

// MARK: - Combat Model
//
// TWO BARS:
// 1. Tug of War (0-100) - battle progress
// 2. Roll Outcome Bar - MISS | HIT | INJURE
//
// Roll bar formula:
//   MISS slots = enemy_def × 2
//   HIT slots = your_att × 0.9
//   INJURE slots = your_att × 0.1
//
// Each round:
//   - Each player rolls ONCE (everyone participates)
//   - Hit VALUE scales: bigger army = less push per hit
//   - Leadership mitigates size penalty

/// Roll bar with 3 sections: MISS | HIT | INJURE
/// Formula:
///   MISS slots = enemy_def × 2
///   HIT slots = your_att × 0.9
///   INJURE slots = your_att × 0.1
private struct RollBar {
    let missSlots: Double
    let hitSlots: Double
    let injureSlots: Double
    
    var totalSlots: Double { missSlots + hitSlots + injureSlots }
    
    var missChance: Double { missSlots / totalSlots }
    var hitChance: Double { hitSlots / totalSlots }
    var injureChance: Double { injureSlots / totalSlots }
    
    /// Roll and return outcome
    func roll() -> BattleRollOutcome {
        let roll = Double.random(in: 0..<totalSlots)
        if roll < missSlots {
            return .miss
        } else if roll < missSlots + hitSlots {
            return .hit
        } else {
            return .injure
        }
    }
    
    /// Create roll bar: MISS = enemy_def × 2, HIT = att × 0.9, INJURE = att × 0.1
    static func create(yourAttack: Int, enemyDefense: Int) -> RollBar {
        let att = Double(max(1, yourAttack))
        let def = Double(max(1, enemyDefense))
        return RollBar(
            missSlots: def * 2.0,
            hitSlots: att * 0.9,
            injureSlots: att * 0.1
        )
    }
}

private enum BattleRollOutcome {
    case miss
    case hit
    case injure
}

private struct CombatSide {
    let activeSize: Int
    let avgAttack: Int
    let avgDefense: Int
    let avgLeadership: Int
    
    /// Each player rolls once
    var rollCount: Int {
        activeSize
    }
    
    /// Push value per hit - scales DOWN with army size
    /// Leadership DAMPENS the size penalty (higher = less penalty)
    /// Both large and small armies converge toward similar effectiveness
    var pushPerHit: Double {
        let base = BattleSimulatorView.kSizeExponentBase
        let dampen = BattleSimulatorView.kLeadershipDampeningPerTier
        let exponent = base - (Double(avgLeadership) * dampen)
        return 1.0 / pow(Double(max(1, activeSize)), exponent)
    }
    
    /// Injury effectiveness - uses tunable exponent
    /// Lower exponent = more injuries get through
    var injuryScale: Double {
        let leadershipBonus = 1.0 + (Double(avgLeadership) * 0.1)
        let exp = BattleSimulatorView.kInjuryScaleExponent
        return leadershipBonus / pow(Double(max(1, activeSize)), exp)
    }
}

// MARK: - Battle Simulation

private struct StepEvent: Identifiable {
    let id = UUID()
    let step: Int
    let summary: String
    let delta: Double
}

extension BattleSimulatorView {
    private func resetBattle() {
        isAutoStepping = false
        stepCount = 0
        stepEvents = []
        bar = 50.0
        resolvedWinner = nil
        sideAActive = sideASize
        sideBActive = sideBSize
        sideASittingOut = 0
        sideBSittingOut = 0
        
        if consoleLoggingEnabled {
            print("[BattleSim] Reset. A=\(sideASize), B=\(sideBSize), Bar=50")
        }
    }
    
    private func stepOnce() {
        guard resolvedWinner == nil else { return }
        
        // Return injured players from last round
        let aReturning = sideASittingOut
        let bReturning = sideBSittingOut
        sideAActive += aReturning
        sideBActive += bReturning
        sideASittingOut = 0
        sideBSittingOut = 0
        
        guard sideAActive > 0 && sideBActive > 0 else {
            resolvedWinner = sideAActive > 0 ? "Side A" : "Side B"
            return
        }
        
        let sideA = CombatSide(activeSize: sideAActive, avgAttack: sideAAvgAttack, avgDefense: sideAAvgDefense, avgLeadership: sideAAvgLeadership)
        let sideB = CombatSide(activeSize: sideBActive, avgAttack: sideBAvgAttack, avgDefense: sideBAvgDefense, avgLeadership: sideBAvgLeadership)
        
        let rollBarA = RollBar.create(yourAttack: sideAAvgAttack, enemyDefense: sideBAvgDefense)
        let rollBarB = RollBar.create(yourAttack: sideBAvgAttack, enemyDefense: sideAAvgDefense)
        
        // A rolls against B
        var aHits = 0
        var aInjuries = 0
        for _ in 0..<sideA.rollCount {
            switch rollBarA.roll() {
            case .miss: break
            case .hit: aHits += 1
            case .injure: aInjuries += 1
            }
        }
        
        // B rolls against A
        var bHits = 0
        var bInjuries = 0
        for _ in 0..<sideB.rollCount {
            switch rollBarB.roll() {
            case .miss: break
            case .hit: bHits += 1
            case .injure: bInjuries += 1
            }
        }
        
        // Apply injuries - scaled, then sit out next round
        let bInjured = min(Int(Double(aInjuries) * sideA.injuryScale), sideBActive)
        let aInjured = min(Int(Double(bInjuries) * sideB.injuryScale), sideAActive)
        sideBActive -= bInjured
        sideAActive -= aInjured
        sideBSittingOut = bInjured  // Will return next round
        sideASittingOut = aInjured  // Will return next round
        
        // Hits push the tug of war bar
        // Push value per hit scales with army size & leadership
        let aPush = Double(aHits) * sideA.pushPerHit
        let bPush = Double(bHits) * sideB.pushPerHit
        let netPush = aPush - bPush
        
        stepCount += 1
        let oldBar = bar
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            bar = min(100.0, max(0.0, bar + netPush))
        }
        
        let summary = "A:\(aHits)h/\(bInjured)i B:\(bHits)h/\(aInjured)i"
        stepEvents.append(StepEvent(step: stepCount, summary: summary, delta: netPush))
        if stepEvents.count > 200 {
            stepEvents.removeFirst(stepEvents.count - 200)
        }
        
        if consoleLoggingEnabled {
            let aReturnStr = aReturning > 0 ? " (+\(aReturning) returned)" : ""
            let bReturnStr = bReturning > 0 ? " (+\(bReturning) returned)" : ""
            print(
                """
                [BattleSim] Round #\(stepCount)
                  A: \(sideAActive) active\(aReturnStr), \(aHits) hits → \(String(format: "%.2f", aPush)) push, \(bInjured) injured on B
                  B: \(sideBActive) active\(bReturnStr), \(bHits) hits → \(String(format: "%.2f", bPush)) push, \(aInjured) injured on A
                  Bar: \(String(format: "%.1f", oldBar)) → \(String(format: "%.1f", bar)) (net \(String(format: "%+.2f", netPush)))
                """
            )
        }
        
        // Check for winner - either bar reaches end OR one side eliminated
        if bar <= 0 || sideAActive <= 0 {
            resolvedWinner = "Side B"
            if consoleLoggingEnabled {
                print("[BattleSim] Side B wins! (A: \(sideAActive) left, Bar: \(String(format: "%.1f", bar)))")
            }
        } else if bar >= 100 || sideBActive <= 0 {
            resolvedWinner = "Side A"
            if consoleLoggingEnabled {
                print("[BattleSim] Side A wins! (B: \(sideBActive) left, Bar: \(String(format: "%.1f", bar)))")
            }
        }
    }
    
    private func autoStep(times: Int) async {
        isAutoStepping = true
        if consoleLoggingEnabled {
            print("[BattleSim] Auto-stepping \(times) rounds...")
        }
        for _ in 0..<times {
            if !isAutoStepping { break }
            if resolvedWinner != nil { break }
            await MainActor.run { stepOnce() }
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }
        await MainActor.run { isAutoStepping = false }
        if consoleLoggingEnabled {
            print("[BattleSim] Auto-step complete.")
        }
    }
    
    @ViewBuilder
    private func rollBarView(bar: RollBar, color: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let missW = w * bar.missChance
            let hitW = w * bar.hitChance
            let injureW = w * bar.injureChance
            
            HStack(spacing: 0) {
                // MISS section (gray)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: missW)
                    .overlay(
                        Text("\(Int(bar.missChance * 100))%")
                            .font(.system(size: 9).bold())
                            .foregroundStyle(.white)
                    )
                
                // HIT section (color)
                Rectangle()
                    .fill(color.opacity(0.7))
                    .frame(width: hitW)
                    .overlay(
                        Text("\(Int(bar.hitChance * 100))%")
                            .font(.system(size: 9).bold())
                            .foregroundStyle(.white)
                    )
                
                // INJURE section (gold/yellow)
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: injureW)
                    .overlay(
                        Text("\(Int(bar.injureChance * 100))%")
                            .font(.system(size: 9).bold())
                            .foregroundStyle(.black)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func battleBar(value: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let progress = min(1.0, max(0.0, value / 100.0))
            let fillW = w * progress
            
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                // A's progress (blue)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: fillW)
                
                // Border on top
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 2)
                
                // Mid marker (50%)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: h - 10)
                    .position(x: w / 2, y: h / 2)
                
                // Current position marker
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: h - 6)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                    .position(x: max(4, min(w - 4, fillW)), y: h / 2)
                
                // Labels
                HStack {
                    Text("A Side")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("B Side")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BattleSimulatorView()
    }
}
