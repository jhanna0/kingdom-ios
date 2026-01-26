import SwiftUI
import Combine

struct DuelCombatView: View {
    let match: DuelMatch
    let playerId: Int
    let onComplete: () -> Void

    @StateObject private var viewModel = DuelCombatViewModel()
    
    // YOUR roll animation
    @State private var rollDisplayValue: Int = 0
    @State private var showRollMarker: Bool = false
    @State private var currentRollIndex: Int = -1  // which roll we're showing
    @State private var yourAnimationStarted: Bool = false  // guard flag
    
    // OPPONENT roll animation
    @State private var opponentRollDisplayValue: Int = 0
    @State private var showOpponentRollMarker: Bool = false
    @State private var opponentAnimationStarted: Bool = false  // guard flag
    
    // Bar - ONLY animate when we explicitly trigger it
    @State private var animatedBarValue: Double = 50
    
    @Environment(\.dismiss) private var dismiss

    private var currentMatch: DuelMatch { viewModel.match ?? match }
    private var isChallenger: Bool { currentMatch.challenger.id == playerId }
    private var me: DuelPlayer? { isChallenger ? currentMatch.challenger : currentMatch.opponent }
    private var opponent: DuelPlayer? { isChallenger ? currentMatch.opponent : currentMatch.challenger }
    private var myStats: DuelPlayerStats? { me?.stats }
    private var opponentStats: DuelPlayerStats? { opponent?.stats }
    private var myDisplayName: String { me?.name ?? "You" }
    private var opponentDisplayName: String { opponent?.name ?? "Opponent" }
    
    private var myColor: Color { KingdomTheme.Colors.royalBlue }
    private var enemyColor: Color { KingdomTheme.Colors.royalCrimson }

    private var missChance: Int { viewModel.missChance }
    private var hitChance: Int { viewModel.hitChance }
    private var critChance: Int { viewModel.critChance }

    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()

            if currentMatch.isComplete, let winner = currentMatch.winner {
                resultOverlay(winner: winner)
            } else {
                mainContent
            }
            
        }
        .navigationTitle("Duel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.load(match: match, playerId: playerId)
            animatedBarValue = currentMatch.barForPlayer(playerId: playerId)
        }
        // YOUR ATTACK: animate rolls one by one
        .onChange(of: viewModel.animationPhase) { _, phase in
            if phase == .rolling && !yourAnimationStarted {
                yourAnimationStarted = true
                print("🎯 Starting YOUR attack animation with \(viewModel.pendingRolls.count) rolls")
                Task { await runYourAttackAnimation() }
            } else if phase == .none {
                yourAnimationStarted = false
            }
        }
        // OPPONENT ATTACK: animate their roll (but wait for player animation first)
        .onChange(of: viewModel.opponentAnimationPhase) { _, phase in
            if phase == .rolling && !opponentAnimationStarted {
                opponentAnimationStarted = true
                print("🎯 Opponent attack queued, waiting for player animation...")
                Task {
                    // Wait for player animation to finish first
                    while viewModel.animationPhase != .none {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    print("🎯 Starting OPPONENT attack animation")
                    await runOpponentAttackAnimation()
                }
            } else if phase == .none {
                opponentAnimationStarted = false
            }
        }
    }
    
    // MARK: - YOUR Attack Animation
    
    @MainActor
    private func runYourAttackAnimation() async {
        let rolls = viewModel.pendingRolls
        print("🎲 runYourAttackAnimation called with \(rolls.count) rolls")
        
        guard !rolls.isEmpty else {
            print("⚠️ No rolls to animate!")
            viewModel.finishYourAttackAnimation()
            return
        }
        
        showRollMarker = true
        currentRollIndex = -1
        
        // Animate each roll one by one
        for (index, roll) in rolls.enumerated() {
            print("🎲 Animating roll \(index + 1): value=\(roll.value), outcome=\(roll.outcome)")
            
            // Sweep animation for this roll
            await sweepMarker(to: Int(roll.value))
            
            // Show this roll badge
            currentRollIndex = index
            
            // Pause between rolls
            if index < rolls.count - 1 {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        
        // Hold final result
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // NOW animate the bar
        let newBarValue = viewModel.pendingBarValue
        print("📊 Animating bar to \(newBarValue)")
        withAnimation(.easeInOut(duration: 0.6)) {
            animatedBarValue = newBarValue
        }
        
        try? await Task.sleep(nanoseconds: 700_000_000)
        
        // Done
        print("✅ Animation complete")
        viewModel.finishYourAttackAnimation()
        showRollMarker = false
    }
    
    @MainActor
    private func sweepMarker(to target: Int) async {
        let clamped = max(1, min(100, target))
        
        // Sweep up (slower - 25ms per step)
        for pos in stride(from: 1, through: 100, by: 3) {
            rollDisplayValue = pos
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        
        // Sweep back down to target (slower)
        if clamped < 100 {
            for pos in stride(from: 97, through: clamped, by: -3) {
                rollDisplayValue = pos
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
        }
        
        rollDisplayValue = clamped
        try? await Task.sleep(nanoseconds: 300_000_000)  // Hold on result longer
    }
    
    // MARK: - OPPONENT Attack Animation
    
    @MainActor
    private func runOpponentAttackAnimation() async {
        showOpponentRollMarker = true
        opponentRollDisplayValue = 0
        
        // Sweep animation (same speed as player)
        let target = max(1, min(100, Int(viewModel.opponentRollValue * 100)))
        
        // Sweep up
        for pos in stride(from: 1, through: 100, by: 3) {
            opponentRollDisplayValue = pos
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        
        // Sweep back down
        if target < 100 {
            for pos in stride(from: 97, through: target, by: -3) {
                opponentRollDisplayValue = pos
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
        }
        
        opponentRollDisplayValue = target
        
        // Hold on result
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        // Animate bar
        let newBarValue = viewModel.pendingBarValueForOpponent(playerId: playerId)
        withAnimation(.easeInOut(duration: 0.6)) {
            animatedBarValue = newBarValue
        }
        
        try? await Task.sleep(nanoseconds: 700_000_000)
        
        // Done
        showOpponentRollMarker = false
        viewModel.finishOpponentAnimation()
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
                    yourSwingsCard
                    opponentSwingsCard
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
            chip(label: "ATTACK", value: "\(myStats?.attack ?? 0)", icon: "burst.fill", tint: myColor)
            
            let maxRolls = 1 + (myStats?.attack ?? 0)
            HStack(spacing: 8) {
                Image(systemName: "dice.fill").font(FontStyles.iconTiny).foregroundColor(.white)
                    .frame(width: 28, height: 28).background(KingdomTheme.Colors.inkDark).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("SWINGS").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
                    HStack(spacing: 3) {
                        ForEach(0..<max(1, maxRolls), id: \.self) { _ in
                            Circle().fill(KingdomTheme.Colors.buttonSuccess).frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
            
            let isMyTurn = viewModel.isMyTurn && !viewModel.isAnimating
            HStack(spacing: 8) {
                Image(systemName: isMyTurn ? "bolt.fill" : "hourglass").font(FontStyles.iconTiny).foregroundColor(.white)
                    .frame(width: 28, height: 28).background(isMyTurn ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TURN").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text(isMyTurn ? "YOUR" : "WAIT").font(FontStyles.labelBold).foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
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
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    // MARK: - Arena
    
    private var arenaCard: some View {
        ZStack {
            LinearGradient(colors: [KingdomTheme.Colors.parchmentRich, KingdomTheme.Colors.parchmentDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                HStack {
                    nameplate(title: myDisplayName, subtitle: "ATK \(myStats?.attack ?? 0) / DEF \(myStats?.defense ?? 0)", isYou: true)
                    Spacer()
                    nameplate(title: opponentDisplayName, subtitle: "ATK \(opponentStats?.attack ?? 0) / DEF \(opponentStats?.defense ?? 0)", isYou: false)
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
    
    private func nameplate(title: String, subtitle: String, isYou: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isYou ? "YOU" : "ENEMY").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkDark)
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
            if let action = viewModel.lastAction, viewModel.animationPhase == .none {
                outcomeBadge(action.outcome)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
    }
    
    private var statusIcon: String {
        if viewModel.opponentAnimationPhase == .rolling { return "scope" }
        if viewModel.animationPhase == .rolling { return "scope" }
        if viewModel.isMyTurn { return "arrow.right.circle.fill" }
        return "hourglass.circle.fill"
    }
    private var statusColor: Color {
        if viewModel.opponentAnimationPhase == .rolling { return enemyColor }
        if viewModel.animationPhase == .rolling || viewModel.isMyTurn { return myColor }
        return KingdomTheme.Colors.inkMedium
    }
    private var statusTitle: String {
        if viewModel.opponentAnimationPhase == .rolling { return "ENEMY ATTACKING..." }
        if viewModel.animationPhase == .rolling { return "ATTACKING..." }
        if let a = viewModel.lastAction, viewModel.animationPhase == .none {
            return a.outcome == "critical" ? "CRITICAL!" : (a.outcome == "hit" ? "HIT!" : "BLOCKED")
        }
        return viewModel.isMyTurn ? "Your turn" : "Waiting..."
    }
    private var statusSubtitle: String {
        if viewModel.opponentAnimationPhase == .rolling { return "Enemy is rolling..." }
        if viewModel.animationPhase == .rolling { return "Rolling..." }
        if let a = viewModel.lastAction, viewModel.animationPhase == .none {
            return a.pushAmount > 0 ? "Pushed \(Int(a.pushAmount))%" : "No damage"
        }
        return viewModel.isMyTurn ? "Tap Attack to swing" : "Opponent's turn"
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
                if showRollMarker { Text("Rolled: \(rollDisplayValue)").font(FontStyles.labelBadge).foregroundColor(markerColor(rollDisplayValue)) }
                if showOpponentRollMarker { Text("Enemy: \(opponentRollDisplayValue)").font(FontStyles.labelBadge).foregroundColor(enemyColor) }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color(white: 0.35)).frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        Rectangle().fill(myColor.opacity(0.7)).frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        Rectangle().fill(myColor)
                    }.clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2)
                    
                    HStack(spacing: 0) {
                        Text("MISS").font(FontStyles.labelBadge).foregroundColor(.white).lineLimit(1).frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        Text("HIT").font(FontStyles.labelBadge).foregroundColor(.white).lineLimit(1).frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        Text("CRIT").font(FontStyles.labelBadge).foregroundColor(.white).lineLimit(1).frame(maxWidth: .infinity)
                    }
                    
                    // Your marker
                    if showRollMarker {
                        marker(value: rollDisplayValue, color: .white, geo: geo)
                    }
                    
                    // Opponent marker
                    if showOpponentRollMarker {
                        marker(value: opponentRollDisplayValue, color: enemyColor, geo: geo)
                    }
                }
            }.frame(height: 20)
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private var barTitle: String {
        if viewModel.opponentAnimationPhase == .rolling { return "ENEMY ROLLING..." }
        if viewModel.animationPhase == .rolling { return "YOUR ROLL" }
        return "ATTACK ODDS"
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
    
    // MARK: - Your Swings Card
    
    private var rollsToShow: [DuelRoll] {
        if viewModel.animationPhase == .rolling {
            return Array(viewModel.pendingRolls.prefix(max(0, currentRollIndex + 1)))
        } else {
            return viewModel.lastRolls
        }
    }
    
    private var yourSwingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR SWINGS").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if rollsToShow.isEmpty {
                Text("Attack to see your rolls!").font(FontStyles.labelTiny).foregroundColor(KingdomTheme.Colors.inkLight)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(rollsToShow.enumerated()), id: \.offset) { index, roll in
                            rollBadge(roll: roll, index: index + 1, isBest: roll.outcome == viewModel.lastAction?.outcome, color: myColor)
                        }
                    }.padding(.horizontal, 4)
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    // MARK: - Opponent Swings Card
    
    private var opponentSwingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENEMY SWINGS").font(FontStyles.labelBadge).foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if viewModel.opponentLastRolls.isEmpty {
                Text("Waiting for enemy...").font(FontStyles.labelTiny).foregroundColor(KingdomTheme.Colors.inkLight)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.opponentLastRolls.enumerated()), id: \.offset) { index, roll in
                            opponentRollBadge(roll: roll, index: index + 1)
                        }
                    }.padding(.horizontal, 4)
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private func rollBadge(roll: DuelRoll, index: Int, isBest: Bool, color: Color) -> some View {
        let badgeColor: Color = roll.outcome == "critical" ? color : (roll.outcome == "hit" ? color.opacity(0.8) : Color.gray)
        let icon = roll.outcome == "critical" ? "flame.fill" : (roll.outcome == "hit" ? "checkmark.circle.fill" : "xmark")
        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.black).frame(width: 44, height: 44).offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 8).fill(badgeColor).frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isBest ? Color.white : Color.black, lineWidth: isBest ? 3 : 2))
                VStack(spacing: 2) {
                    Image(systemName: icon).font(FontStyles.iconTiny).foregroundColor(.white)
                    Text("\(Int(roll.value))").font(FontStyles.labelBadge).foregroundColor(.white)
                }
            }.frame(width: 48, height: 48)
            Text(isBest ? "BEST" : "#\(index)").font(.system(size: 8, weight: .black))
                .foregroundColor(isBest ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
        }
    }
    
    private func opponentRollBadge(roll: OpponentRollDisplay, index: Int) -> some View {
        let badgeColor: Color = roll.outcome == "critical" ? enemyColor : (roll.outcome == "hit" ? enemyColor.opacity(0.8) : Color.gray)
        let icon = roll.outcome == "critical" ? "flame.fill" : (roll.outcome == "hit" ? "checkmark.circle.fill" : "xmark")
        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.black).frame(width: 44, height: 44).offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 8).fill(badgeColor).frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                VStack(spacing: 2) {
                    Image(systemName: icon).font(FontStyles.iconTiny).foregroundColor(.white)
                    Text("+\(Int(roll.pushAmount))").font(FontStyles.labelBadge).foregroundColor(.white)
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
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        Button { Task { await viewModel.attack() } } label: {
                            HStack { Image(systemName: "figure.fencing"); Text("Attack!") }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.brutalist(backgroundColor: viewModel.canAttack ? myColor : KingdomTheme.Colors.disabled, foregroundColor: .white, fullWidth: true))
                        .disabled(!viewModel.canAttack)
                        
                        Button { Task { await viewModel.forfeit() } } label: {
                            HStack { Image(systemName: "flag.fill"); Text("Forfeit") }.frame(maxWidth: .infinity)
                        }.buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonDanger.opacity(0.8), foregroundColor: .white, fullWidth: true))
                    }
                } else {
                    Button { onComplete() } label: {
                        HStack { Text("Continue"); Image(systemName: "arrow.right") }.frame(maxWidth: .infinity)
                    }.buttonStyle(.brutalist(backgroundColor: myColor, foregroundColor: .white, fullWidth: true))
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }.background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Result Overlay
    
    private func resultOverlay(winner: DuelWinner) -> some View {
        let didWin = winner.id == playerId
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
                Button(action: { onComplete() }) { Text("Continue").frame(maxWidth: .infinity) }
                    .buttonStyle(.brutalist(backgroundColor: resultColor, foregroundColor: .white, fullWidth: true))
                    .padding(.horizontal, 40).padding(.top, 20)
            }.padding(30)
        }
    }
}

// MARK: - Animation Phase

enum YourAnimationPhase { case none, rolling }
enum OpponentAnimationPhase { case none, rolling }

// Simple struct for opponent roll history display
struct OpponentRollDisplay {
    let rollValue: Double  // 0.0-1.0
    let outcome: String
    let pushAmount: Double
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
    @Published var lastAction: DuelActionResult?
    @Published var lastRolls: [DuelRoll] = []
    @Published var errorMessage: String?
    
    // YOUR animation (when YOU attack)
    @Published var animationPhase: YourAnimationPhase = .none
    @Published var pendingRolls: [DuelRoll] = []
    @Published var pendingBarValue: Double = 50
    
    // OPPONENT animation (when they attack - from WS event)
    @Published var opponentAnimationPhase: OpponentAnimationPhase = .none
    @Published var opponentRollValue: Double = 0      // 0.0-1.0
    @Published var opponentOutcome: String = "miss"
    @Published var opponentPushAmount: Double = 0
    @Published var opponentLastRolls: [OpponentRollDisplay] = []  // History of opponent attacks
    
    // Turn info (from backend)
    @Published var turnTimeoutSeconds: Int = 30
    @Published var turnExpiresAt: Date?
    
    // Chances (display only)
    @Published var missChance: Int = 50
    @Published var hitChance: Int = 40
    @Published var critChance: Int = 10
    
    private let api = DuelsAPI()
    private var matchId: Int?
    private var playerId: Int?
    
    private var pendingMatch: DuelMatch?
    private var cancellables = Set<AnyCancellable>()
    
    /// Is it my turn? Based on match state from backend
    var isMyTurn: Bool {
        guard let m = match, let p = playerId else { return false }
        return m.isPlayersTurn(playerId: p)
    }
    
    var isAnimating: Bool { animationPhase != .none || opponentAnimationPhase != .none }
    
    /// Can I attack? Only if backend says it's my turn AND we're not animating
    var canAttack: Bool { isMyTurn && !isAnimating }
    
    func pendingBarValueForOpponent(playerId: Int) -> Double {
        pendingMatch?.barForPlayer(playerId: playerId) ?? 50
    }
    
    func load(match: DuelMatch, playerId: Int) async {
        self.match = match
        self.matchId = match.id
        self.playerId = playerId
        await refresh()
        subscribeToEvents()
    }
    
    private func subscribeToEvents() {
        guard let matchId = matchId else { return }
        GameEventManager.shared.duelEventSubject
            .receive(on: DispatchQueue.main)
            .filter { [weak self] e in e.matchId == self?.matchId }
            .sink { [weak self] e in self?.handleEvent(e) }
            .store(in: &cancellables)
    }
    
    /// Handle events from backend - this is the core of "dumb renderer"
    private func handleEvent(_ event: DuelEvent) {
        print("🎮 DuelCombatVM received event: \(event.eventType.rawValue)")
        
        switch event.eventType {
        case .opponentJoined:
            if let m = event.match { match = m }
            
        case .started:
            // Backend tells us who goes first
            if let m = event.match { match = m }
            if let firstTurn = event.data["first_turn"] as? [String: Any] {
                turnTimeoutSeconds = firstTurn["timeout_seconds"] as? Int ?? 30
            }
            
        case .turnChanged:
            if let m = event.match { match = m }
            
        case .turnComplete:
            // NEW: Comprehensive turn result from backend
            handleTurnComplete(event)
            
        case .attack:
            // Legacy event - handle for backwards compatibility
            handleLegacyAttackEvent(event)
            
        case .ended, .timeout:
            // Game over - just update match state
            if let m = event.match { match = m }
            
        case .cancelled:
            if let m = event.match { match = m }
            
        case .invitation:
            break
        }
    }
    
    /// Handle the new TURN_COMPLETE event
    private func handleTurnComplete(_ event: DuelEvent) {
        guard let attackerId = event.data["attacker_id"] as? Int else { return }
        
        let isMyAttack = attackerId == playerId
        
        if isMyAttack {
            if let m = event.match { pendingMatch = m }
        } else {
            if let actionDict = event.data["action"] as? [String: Any] {
                opponentRollValue = actionDict["roll_value"] as? Double ?? 0
                opponentOutcome = actionDict["outcome"] as? String ?? "miss"
                opponentPushAmount = actionDict["push_amount"] as? Double ?? 0
                
                pendingMatch = event.match
                opponentAnimationPhase = .rolling
            }
        }
    }
    
    /// Handle legacy attack event for backwards compatibility
    private func handleLegacyAttackEvent(_ event: DuelEvent) {
        if let m = event.match {
            match = m
        }
    }
    
    func finishOpponentAnimation() {
        opponentLastRolls.append(OpponentRollDisplay(
            rollValue: opponentRollValue,
            outcome: opponentOutcome,
            pushAmount: opponentPushAmount
        ))
        
        opponentAnimationPhase = .none
        if let m = pendingMatch { match = m; pendingMatch = nil }
    }
    
    private func refresh() async {
        guard let matchId = matchId else { return }
        do {
            let r = try await api.getMatch(matchId: matchId)
            if let m = r.match { match = m }
        } catch {}
    }
    
    func startMatch() async {
        guard let matchId = matchId else { return }
        do {
            let r = try await api.startMatch(matchId: matchId)
            if r.success { match = r.match }
        } catch { errorMessage = error.localizedDescription }
    }
    
    /// Send attack command to backend
    func attack() async {
        guard let matchId = matchId, canAttack else { return }
        do {
            let r = try await api.attack(matchId: matchId)
            if r.success {
                lastAction = r.action
                lastRolls = r.rolls ?? []
                missChance = r.missChance ?? 50
                hitChance = r.hitChancePct ?? 40
                critChance = r.critChance ?? 10
                
                pendingRolls = r.rolls ?? []
                pendingMatch = r.match
                pendingBarValue = r.match?.barForPlayer(playerId: playerId ?? 0) ?? 50
                
                animationPhase = .rolling
            } else {
                errorMessage = r.message
            }
        } catch { 
            errorMessage = error.localizedDescription 
        }
    }
    
    func finishYourAttackAnimation() {
        animationPhase = .none
        if let m = pendingMatch { match = m; pendingMatch = nil }
    }
    
    func cancel() async {
        guard let matchId = matchId else { return }
        do { _ = try await api.cancel(matchId: matchId) } catch {}
    }
    
    func forfeit() async {
        guard let matchId = matchId else { return }
        do { let r = try await api.forfeit(matchId: matchId); match = r.match } catch { errorMessage = error.localizedDescription }
    }
    
    /// Claim timeout win if opponent's turn expired (backend validates)
    func claimTimeout() async {
        guard let matchId = matchId else { return }
        do { 
            let r = try await api.claimTimeout(matchId: matchId)
            if r.success {
                match = r.match 
            } else {
                errorMessage = r.message
            }
        } catch { 
            errorMessage = error.localizedDescription 
        }
    }
    
    deinit { cancellables.removeAll() }
}
