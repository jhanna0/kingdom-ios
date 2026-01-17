import SwiftUI

struct ResearchView: View {
    @StateObject private var viewModel: ResearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    // Roll animation state
    @State private var displayRollValue: Int = 0
    @State private var isAnimatingRoll: Bool = false
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: ResearchViewModel())
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                mainContent
                actionBar
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.loadInitialData()
        }
        .onChange(of: viewModel.uiState) { _, newState in
            if newState == .filling {
                displayRollValue = 0
                isAnimatingRoll = false
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flask.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    Text("RESEARCH LAB")
                        .fontStyle(FontStyles.headingSmall, color: KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill")
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Text("\(viewModel.stats?.gold ?? 0)")
                        .fontStyle(FontStyles.statMedium, color: KingdomTheme.Colors.gold)
                }
                
                Spacer()
                
                Button { dismiss() } label: {
                    Text("Done")
                        .fontStyle(FontStyles.labelBold, color: KingdomTheme.Colors.royalBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Rectangle().fill(Color.black).frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        GeometryReader { geo in
            ZStack {
                switch viewModel.uiState {
                case .loading:
                    ProgressView().tint(KingdomTheme.Colors.royalBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .idle:
                    idleView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .filling:
                    fillPhaseView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .fillResult:
                    fillResultView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .stabilizing:
                    stabilizePhaseView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .stabilizeResult:
                    stabilizeResultView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .building:
                    buildPhaseView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .result:
                    resultView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .error(let msg):
                    Text(msg)
                        .fontStyle(FontStyles.bodyMedium, color: KingdomTheme.Colors.buttonDanger)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    // MARK: - Idle View
    
    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flask.fill")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.royalBlue)
            
            Text("Mix reagents to discover blueprints")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 16) {
                statPill("SCI", viewModel.stats?.science ?? 0)
                statPill("PHI", viewModel.stats?.philosophy ?? 0)
                statPill("BLD", viewModel.stats?.building ?? 0)
            }
        }
    }
    
    private func statPill(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold))
            Text("\(value)").font(.system(size: 12, weight: .black))
        }
        .foregroundColor(KingdomTheme.Colors.inkDark)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(KingdomTheme.Colors.parchmentDark)
        .cornerRadius(8)
    }
    
    // MARK: - Fill Phase View
    
    private var fillPhaseView: some View {
        GeometryReader { geo in
            // Dynamic layout: try "regular" first; if it doesn't fit, fall back to compact; if still too small, scroll.
            ViewThatFits(in: .vertical) {
                fillPhaseLayout(size: geo.size, isCompact: false)
                fillPhaseLayout(size: geo.size, isCompact: true)
                ScrollView(.vertical, showsIndicators: false) {
                    fillPhaseLayout(size: geo.size, isCompact: true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func fillPhaseLayout(size: CGSize, isCompact: Bool) -> some View {
        let w = size.width
        let h = size.height
        
        // Match top bar + bottom action bar padding rhythm
        let sidePadding: CGFloat = 20
        let verticalPadding: CGFloat = isCompact ? 12 : 16
        let sectionSpacing: CGFloat = isCompact ? 10 : KingdomTheme.Spacing.medium
        
        // Tube sizing scales with screen, but never forces the rest to overflow.
        let tubeWidth = max(84, min(w * 0.26, 140))
        let tubeHeight = max(isCompact ? 170 : 210, min(h * (isCompact ? 0.38 : 0.42), 420))
        let rollHistoryHeight: CGFloat = isCompact ? 52 : 64
        
        return VStack(spacing: sectionSpacing) {
            fillTopMiniBars(isCompact: isCompact)
                .layoutPriority(1)
            
            HStack(alignment: .center, spacing: KingdomTheme.Spacing.large) {
                mainTubeView(tubeWidth: tubeWidth, tubeHeight: tubeHeight)
                    .layoutPriority(1)
                
                fillSideConsole(isCompact: isCompact, rollHistoryHeight: rollHistoryHeight)
                    .layoutPriority(0)
            }
            
            fillRollPanel
                .frame(minHeight: isCompact ? 110 : 130)
                .layoutPriority(2)
        }
        .padding(.horizontal, sidePadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Fill UI Sections
    
    private func fillTopMiniBars(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack {
                Text("PHASE 1: FILL")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
                Text("Target: 50%")
                    .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, isCompact ? 4 : 6)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8, borderWidth: 2)
            }
            .frame(height: isCompact ? 16 : 18)
            
            VStack(spacing: isCompact ? 5 : 6) {
                ForEach(0..<3, id: \.self) { idx in
                    miniBarRow(index: idx, isCompact: isCompact)
                }
            }
        }
        .padding(isCompact ? 8 : 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
        .frame(maxWidth: .infinity)
    }
    
    private func miniBarRow(index: Int, isCompact: Bool) -> some View {
        let isActive = viewModel.currentBarIndex == index
        let barNames = ["COMPOSURE", "CALCULATION", "PRECISION"]
        let fill = min(1, max(0, viewModel.miniBarFills[index]))
        
        let barColor = isActive ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.buttonSuccess
        let borderColor = isActive ? KingdomTheme.Colors.royalBlue : Color.black
        
        let labelWidth: CGFloat = isCompact ? 96 : 104
        let rowHeight: CGFloat = isCompact ? 22 : 26
        let barHeight: CGFloat = isCompact ? 18 : 20
        let pctWidth: CGFloat = isCompact ? 46 : 52
        
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(barNames[index])
                    .fontStyle(FontStyles.statSmall, color: isActive ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkMedium)
                if !isCompact {
                    Text(isActive ? "ACTIVE" : "READY")
                        .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium.opacity(isActive ? 1 : 0.7))
                }
            }
            .frame(width: labelWidth, alignment: .leading)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barColor.opacity(isActive ? 0.9 : 0.6))
                        .overlay(
                            LinearGradient(
                                colors: [KingdomTheme.Colors.parchmentHighlight.opacity(0.35), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        )
                        .frame(width: max(6, geo.size.width * fill))
                        .animation(.easeOut(duration: 0.25), value: fill)
                }
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isActive ? 3 : 2)
            }
            .frame(height: barHeight)
            
            Text("\(Int(fill * 100))%")
                .fontStyle(isCompact ? FontStyles.statMedium : FontStyles.statMedium, color: KingdomTheme.Colors.inkDark)
                .frame(width: pctWidth, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }
    
    private func fillSideConsole(isCompact: Bool, rollHistoryHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: viewModel.showMasterRoll ? "scope" : "dial.medium.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text(viewModel.showMasterRoll ? "MASTER ROLL" : "INSTRUMENTS")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            .frame(height: 22)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Current: \(currentBarName)")
                    .fontStyle(FontStyles.labelMedium, color: KingdomTheme.Colors.inkMedium)
                if !isCompact {
                    Text(viewModel.showMasterRoll ? "Confirm the mixture result" : "Roll to fill the bar")
                        .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            fillRollHistory
                .frame(height: rollHistoryHeight)
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mixture")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    Spacer()
                    Text("\(Int(viewModel.mainTubeFill * 100))%")
                        .fontStyle(FontStyles.statMedium, color: viewModel.mainTubeFill >= 0.5 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.royalBlue)
                }
                
                GeometryReader { geo in
                    let clamped = min(1, max(0, viewModel.mainTubeFill))
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.parchmentDark)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.mainTubeFill >= 0.5 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.royalBlue)
                            .frame(width: max(6, geo.size.width * clamped), height: geo.size.height)
                            .animation(.easeOut(duration: 0.35), value: clamped)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                }
                .frame(height: 20)
                
                Text(viewModel.mainTubeFill >= 0.5 ? "Ready to stabilize" : "Need 50% to proceed")
                    .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
                    .frame(height: 14, alignment: .leading)
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
        .frame(maxWidth: .infinity)
    }
    
    private var fillRollHistory: some View {
        let rolls = viewModel.currentMiniBar?.rolls ?? []
        let shownCount = max(0, viewModel.currentRollIndex + 1)
        
        return ZStack {
            if rolls.isEmpty {
                Text("No rolls yet")
                    .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if shownCount <= 0 {
                Text("Tap ROLL")
                    .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(rolls.prefix(shownCount).enumerated()), id: \.offset) { idx, roll in
                            ResearchRollCard(roll: roll, index: idx + 1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
    }
    
    private var fillRollPanel: some View {
        GeometryReader { geo in
            let panelH = geo.size.height
            let mainFontSize = min(72, max(32, panelH * 0.46))
            let subFont = min(18, max(12, panelH * 0.14))
            
            let statusText: String = {
                if isAnimatingRoll { return "SPINNING..." }
                if let roll = viewModel.currentRoll { return roll.hit ? "HIT!" : "MISS" }
                if viewModel.showMasterRoll { return (viewModel.currentMiniBar?.masterHit == true) ? "MASTER HIT!" : "MASTER MISS" }
                return "READY"
            }()
            
            let statusColor: Color = {
                if isAnimatingRoll { return KingdomTheme.Colors.inkMedium }
                if let roll = viewModel.currentRoll { return roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger }
                if viewModel.showMasterRoll { return (viewModel.currentMiniBar?.masterHit == true) ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger }
                return KingdomTheme.Colors.inkMedium
            }()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ROLL #")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                        .frame(height: 14)
                    
                    Text("\(displayRollValue)")
                        .font(.system(size: mainFontSize, weight: .black, design: .monospaced))
                        .foregroundColor(rollColor)
                        .frame(height: mainFontSize * 1.05, alignment: .leading)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text(statusText)
                        .font(.system(size: subFont, weight: .black, design: .serif))
                        .foregroundColor(statusColor)
                        .frame(height: subFont * 1.2, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(viewModel.showMasterRoll ? "CONFIRM" : "FILL")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                        .frame(height: 14)
                    
                    Text(viewModel.showMasterRoll ? "MASTER" : currentBarName)
                        .fontStyle(FontStyles.headingSmall, color: viewModel.showMasterRoll ? KingdomTheme.Colors.gold : KingdomTheme.Colors.royalBlue)
                        .frame(height: 22)
                    
                    Text(stepHintText)
                        .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.trailing)
                        .frame(height: 28, alignment: .trailing)
                }
                .frame(width: min(170, geo.size.width * 0.42), alignment: .trailing)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var currentBarName: String {
        let barNames = ["COMPOSURE", "CALCULATION", "PRECISION"]
        let idx = min(2, max(0, viewModel.currentBarIndex))
        return barNames[idx]
    }
    
    private var stepHintText: String {
        if isAnimatingRoll { return "…" }
        if viewModel.showMasterRoll { return "Master roll: chance = bar fill %\nHIT adds more to the tube" }
        if let bar = viewModel.currentMiniBar {
            let remaining = max(0, bar.rolls.count - (viewModel.currentRollIndex + 1))
            let base = remaining > 0 ? "\(remaining) rolls left on this bar" : "Next: master roll"
            return "\(base)\nNormal: 61+ = HIT"
        }
        return "Tap ROLL\nNormal: 61+ = HIT"
    }
    
    private var rollColor: Color {
        if isAnimatingRoll {
            return KingdomTheme.Colors.royalBlue
        }
        if let roll = viewModel.currentRoll {
            return roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        }
        if viewModel.showMasterRoll {
            return viewModel.currentMiniBar?.masterHit == true ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger
        }
        return KingdomTheme.Colors.inkLight
    }
    
    // MARK: - Roll Animation
    
    private func animateRoll(to finalValue: Int) async {
        isAnimatingRoll = true
        
        // Slot-machine style: fast cycle 1→100, then decelerate into final value
        let clampedFinal = min(100, max(1, finalValue))
        
        var positions: [Int] = []
        positions.append(contentsOf: stride(from: 1, through: 100, by: 4))
        
        if clampedFinal < 100 {
            positions.append(contentsOf: stride(from: 100, through: max(1, clampedFinal), by: -4))
        }
        if positions.last != clampedFinal {
            positions.append(clampedFinal)
        }
        
        for (i, pos) in positions.enumerated() {
            displayRollValue = pos
            // Slight deceleration near the end
            let sleepNs: UInt64 = (i > positions.count - 10) ? 45_000_000 : 22_000_000
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        
        displayRollValue = clampedFinal
        isAnimatingRoll = false
    }
    
    @MainActor
    private func doFillRollWithAnimation() async {
        guard !isAnimatingRoll else { return }

        // Animate FIRST, then advance model state.
        // This prevents HIT/MISS from appearing before the roll animation completes.
        guard viewModel.uiState == .filling, let bar = viewModel.currentMiniBar else { return }

        if viewModel.showMasterRoll {
            // Reveal master roll, then apply its contribution (same click).
            await animateRoll(to: bar.masterRoll)
            await Task.yield()
            viewModel.doNextFillRoll()
            return
        }

        let nextRollIdx = viewModel.currentRollIndex + 1
        if nextRollIdx < bar.rolls.count {
            // Reveal the next normal roll.
            await animateRoll(to: bar.rolls[nextRollIdx].roll)
            await Task.yield()
            viewModel.doNextFillRoll()
        } else {
            // No normal rolls left: reveal master roll, then auto-apply into the main tube.
            await animateRoll(to: bar.masterRoll)
            await Task.yield()
            viewModel.doNextFillRoll() // flips into master roll state
            try? await Task.sleep(nanoseconds: 200_000_000) // tiny beat so the UI can show MASTER HIT/MISS
            viewModel.doNextFillRoll() // apply contribution + advance
        }
    }
    
    @MainActor
    private func doStabilizeRollWithAnimation() async {
        guard !isAnimatingRoll else { return }
        
        viewModel.doNextStabilizeRoll()
        
        if let roll = viewModel.currentStabilizeRoll {
            await animateRoll(to: roll.roll)
        }
    }
    
    private func miniBarView(index: Int, barWidth: CGFloat) -> some View {
        let isActive = viewModel.currentBarIndex == index
        let barNames = ["COMPOSURE", "CALCULATION", "PRECISION"]
        let fill = viewModel.miniBarFills[index]
        let actualBarWidth = barWidth * 0.6
        
        return VStack(alignment: .leading, spacing: 4) {
            // Label + Percentage
            HStack {
                Text(barNames[index])
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(isActive ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("\(Int(fill * 100))%")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .frame(width: actualBarWidth)
            
            // Bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.buttonSuccess)
                    .frame(width: max(4, actualBarWidth * fill))
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? KingdomTheme.Colors.royalBlue : Color.black, lineWidth: isActive ? 3 : 2)
            }
            .frame(width: actualBarWidth, height: 28)
        }
    }
    
    private func rollDisplay(roll: Int, hit: Bool) -> some View {
        HStack(spacing: 20) {
            // Roll number
            Text("\(roll)")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundColor(hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
            
            // Result
            Text(hit ? "HIT!" : "MISS")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger, lineWidth: 3)
        )
    }
    
    private var masterRollDisplay: some View {
        let hit = viewModel.currentMiniBar?.masterHit ?? false
        
        return VStack(spacing: 8) {
            Text("MASTER ROLL")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(KingdomTheme.Colors.gold)
            
            Text("\(viewModel.masterRollValue)")
                .font(.system(size: 50, weight: .black, design: .monospaced))
                .foregroundColor(hit ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
            
            Text(hit ? "SUCCESS!" : "MISS")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(hit ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.gold, lineWidth: 3)
        )
    }
    
    private func mainTubeView(tubeWidth: CGFloat, tubeHeight: CGFloat) -> some View {
        let clampedFill = min(1, max(0, viewModel.mainTubeFill))
        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                // Fill
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewModel.mainTubeFill >= 0.5 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.royalBlue)
                    .frame(height: max(4, tubeHeight * clampedFill))
                    .overlay(
                        LinearGradient(
                            colors: [KingdomTheme.Colors.parchmentHighlight.opacity(0.25), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 3)
                
                // 50% line
                Rectangle()
                    .fill(Color.black)
                    .frame(width: tubeWidth + 10, height: 2)
                    .offset(y: -tubeHeight * 0.5)
            }
            .frame(width: tubeWidth, height: tubeHeight)

            Text("need 50%")
                .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    // MARK: - Fill Result View
    
    private var fillResultView: some View {
        let success = viewModel.experiment?.phase1Fill.success ?? false
        
        return VStack(spacing: 16) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
            
            Text(success ? "MIXTURE READY!" : "MIXTURE FAILED")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
            
            Text("Main tube: \(Int(viewModel.mainTubeFill * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Stabilize Phase View
    
    private var stabilizePhaseView: some View {
        VStack(spacing: 20) {
            Text("STABILIZING")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(KingdomTheme.Colors.gold)
            
            // Stability dots
            HStack(spacing: 12) {
                ForEach(0..<(viewModel.experiment?.phase2Stabilize.hitsNeeded ?? 1), id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.stabilizeHits ? KingdomTheme.Colors.gold : KingdomTheme.Colors.parchmentDark)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(KingdomTheme.Colors.gold, lineWidth: 2))
                }
            }
            
            // Current roll
            if let roll = viewModel.currentStabilizeRoll {
                rollDisplay(roll: roll.roll, hit: roll.hit)
            }
        }
    }
    
    private var stabilizeResultView: some View {
        let success = viewModel.experiment?.phase2Stabilize.success ?? false
        
        return VStack(spacing: 16) {
            Image(systemName: success ? "atom" : "flame.fill")
                .font(.system(size: 50))
                .foregroundColor(success ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
            
            Text(success ? "STABILIZED!" : "EXPLOSION!")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(success ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger)
        }
    }
    
    // MARK: - Build Phase View
    
    private var buildPhaseView: some View {
        VStack(spacing: 20) {
            Text("BUILD")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchmentDark)
                    .frame(width: 250, height: 30)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.buttonSuccess)
                    .frame(width: CGFloat(viewModel.buildProgress) / 100.0 * 250, height: 30)
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 250, height: 30)
            }
            
            Text("\(viewModel.buildProgress)%")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            
            let tapsLeft = (viewModel.experiment?.phase3Build.taps.count ?? 0) - viewModel.currentTapIndex
            Text("\(tapsLeft) taps left")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        let outcome = viewModel.experiment?.outcome
        
        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: outcomeIcon(outcome))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(outcomeColor(outcome))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RESULT")
                            .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                        Text(outcomeTitle(outcome))
                            .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Text(outcomeBadge(outcome))
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.parchmentLight,
                            cornerRadius: 10,
                            borderWidth: 2
                        )
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                
                Text(outcome?.message ?? "No result available.")
                    .fontStyle(FontStyles.bodyMedium, color: KingdomTheme.Colors.inkDark)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let outcome, (outcome.blueprints > 0 || outcome.gp > 0) {
                    HStack(spacing: 10) {
                        if outcome.blueprints > 0 {
                            rewardPill(icon: "scroll.fill", iconColor: KingdomTheme.Colors.royalBlue, text: "+\(outcome.blueprints) Blueprint")
                        }
                        if outcome.gp > 0 {
                            rewardPill(icon: "g.circle.fill", iconColor: KingdomTheme.Colors.gold, text: "+\(outcome.gp) Gold")
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(14)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }
    
    private func rewardPill(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(text)
                .fontStyle(FontStyles.labelMedium, color: KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12, borderWidth: 2)
    }
    
    private func outcomeIcon(_ outcome: OutcomeResult?) -> String {
        guard let outcome else { return "questionmark.circle.fill" }
        if outcome.success { return outcome.isCritical ? "star.fill" : "scroll.fill" }
        return "xmark.circle.fill"
    }
    
    private func outcomeColor(_ outcome: OutcomeResult?) -> Color {
        guard let outcome else { return KingdomTheme.Colors.inkMedium }
        if outcome.success { return outcome.isCritical ? KingdomTheme.Colors.gold : KingdomTheme.Colors.royalBlue }
        return KingdomTheme.Colors.buttonDanger
    }
    
    private func outcomeTitle(_ outcome: OutcomeResult?) -> String {
        guard let outcome else { return "UNKNOWN" }
        if outcome.success { return outcome.isCritical ? "Critical discovery" : "Discovery" }
        return "Failed experiment"
    }
    
    private func outcomeBadge(_ outcome: OutcomeResult?) -> String {
        guard let outcome else { return "—" }
        if outcome.success { return outcome.isCritical ? "CRITICAL" : "SUCCESS" }
        return "FAIL"
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black).frame(height: 3)
            
            Group {
                switch viewModel.uiState {
                case .idle:
                    Button {
                        Task { await viewModel.startExperiment() }
                    } label: {
                        HStack {
                            Image(systemName: "flask.fill")
                            Text("BEGIN (\(viewModel.config?.goldCost ?? 25)g)")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KingdomTheme.Colors.royalBlue)
                        .cornerRadius(8)
                    }
                    
                case .filling:
                    Button {
                        Task {
                            await doFillRollWithAnimation()
                        }
                    } label: {
                        Text(isAnimatingRoll ? "..." : "ROLL")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isAnimatingRoll ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.royalBlue)
                            .cornerRadius(8)
                    }
                    .disabled(isAnimatingRoll)
                    
                case .fillResult:
                    Button {
                        Task { await viewModel.startStabilize() }
                    } label: {
                        Text(viewModel.experiment?.phase1Fill.success == true ? "STABILIZE" : "SEE RESULT")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.gold)
                            .cornerRadius(8)
                    }
                    
                case .stabilizing:
                    Button {
                        Task {
                            await doStabilizeRollWithAnimation()
                        }
                    } label: {
                        Text(isAnimatingRoll ? "..." : "ROLL")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isAnimatingRoll ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.gold)
                            .cornerRadius(8)
                    }
                    .disabled(isAnimatingRoll)
                    
                case .stabilizeResult:
                    Button {
                        Task { await viewModel.startBuild() }
                    } label: {
                        Text(viewModel.experiment?.phase2Stabilize.success == true ? "BUILD" : "SEE RESULT")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.buttonSuccess)
                            .cornerRadius(8)
                    }
                    
                case .building:
                    Button {
                        viewModel.handleTap()
                    } label: {
                        Text("TAP!")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.buttonSuccess)
                            .cornerRadius(8)
                    }
                    
                case .result:
                    Button {
                        Task { await viewModel.reset() }
                    } label: {
                        Text("TRY AGAIN")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.royalBlue)
                            .cornerRadius(8)
                    }
                    
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Small Components

private struct ResearchRollCard: View {
    let roll: MiniRoll
    let index: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: 2, y: 2)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 2)
                )
            
            Text("\(roll.roll)")
                .fontStyle(FontStyles.statMedium, color: textColor)
        }
        .frame(width: 48, height: 48)
    }
    
    private var cardBackground: Color {
        if roll.hit {
            return KingdomTheme.Colors.parchmentHighlight
        }
        return KingdomTheme.Colors.parchment
    }
    
    private var cardBorder: Color {
        roll.hit ? KingdomTheme.Colors.buttonSuccess : Color.black
    }
    
    private var textColor: Color {
        roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium
    }
}

#Preview {
    NavigationStack {
        ResearchView(apiClient: APIClient.shared)
    }
}
