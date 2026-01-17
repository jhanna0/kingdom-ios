import SwiftUI

struct ResearchView: View {
    @StateObject private var viewModel: ResearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    // Roll animation state
    @State private var displayRollValue: Int = 0
    @State private var isAnimatingRoll: Bool = false
    
    // Reagent selection bar marker animation
    @State private var barMarkerValue: Int = 0
    @State private var showBarMarker: Bool = false
    
    // Cooking phase marker animation
    @State private var cookingMarkerPosition: CGFloat = 0
    
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
                showBarMarker = false
                barMarkerValue = 0
            } else if newState == .cooking {
                cookingMarkerPosition = 0
                isAnimatingRoll = false
            }
        }
        .onChange(of: viewModel.currentBarIndex) { _, _ in
            showBarMarker = false
            barMarkerValue = 0
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
                    
                case .cooking:
                    cookingPhaseView
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
            
            // Show reward tiers from config
            if let tiers = viewModel.config?.phase2Cooking.rewardTiers, !tiers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("REWARD TIERS")
                        .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                    
                    ForEach(Array(tiers.enumerated()), id: \.offset) { _, tier in
                        HStack {
                            Text("\(tier.minPercent)-\(tier.maxPercent)%")
                                .fontStyle(FontStyles.statSmall, color: KingdomTheme.Colors.inkMedium)
                                .frame(width: 60, alignment: .leading)
                            Text(tier.label)
                                .fontStyle(FontStyles.labelSmall, color: colorForTierId(tier.id))
                            Spacer()
                            if tier.blueprints > 0 {
                                Text("\(tier.blueprints) BP")
                                    .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.royalBlue)
                            }
                        }
                    }
                }
                .padding(12)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                .frame(maxWidth: 280)
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
        let sidePadding: CGFloat = 20
        let verticalPadding: CGFloat = isCompact ? 12 : 16
        let sectionSpacing: CGFloat = isCompact ? 10 : KingdomTheme.Spacing.medium
        let tubeWidth = max(84, min(w * 0.26, 140))
        let tubeHeight = max(isCompact ? 170 : 210, min(h * (isCompact ? 0.38 : 0.42), 420))
        
        return VStack(spacing: sectionSpacing) {
            fillTopMiniBars(isCompact: isCompact)
                .layoutPriority(1)
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                mainTubeView(tubeWidth: tubeWidth, tubeHeight: tubeHeight, showCookingMarker: false)
                
                fillSideConsole(isCompact: isCompact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            
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
        return VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack {
                Text("PHASE 1: FILL")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            .frame(height: isCompact ? 16 : 18)
            
            VStack(spacing: isCompact ? 5 : 6) {
                ForEach(0..<viewModel.miniBarNames.count, id: \.self) { idx in
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
        let barNames = viewModel.miniBarNames
        let barName = index < barNames.count ? barNames[index] : "BAR \(index + 1)"
        let fill = index < viewModel.miniBarFills.count ? min(1, max(0, viewModel.miniBarFills[index])) : 0
        
        let showMarkerOnThisBar = isActive && showBarMarker
        let barColor = isActive ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.buttonSuccess
        let borderColor = isActive ? KingdomTheme.Colors.royalBlue : Color.black
        
        let labelWidth: CGFloat = isCompact ? 96 : 104
        let rowHeight: CGFloat = isCompact ? 28 : 32
        let barHeight: CGFloat = isCompact ? 22 : 26
        let pctWidth: CGFloat = isCompact ? 46 : 52
        
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(barName)
                    .fontStyle(FontStyles.statSmall, color: isActive ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkMedium)
                if !isCompact {
                    Text(isActive && viewModel.showReagentSelect ? "SELECTING" : (isActive ? "ACTIVE" : "READY"))
                        .fontStyle(FontStyles.captionLarge, color: isActive && viewModel.showReagentSelect ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium.opacity(isActive ? 1 : 0.7))
                }
            }
            .frame(width: labelWidth, alignment: .leading)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
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
                        
                        if showMarkerOnThisBar {
                            let markerX = geo.size.width * CGFloat(barMarkerValue) / 100.0
                            
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(KingdomTheme.Colors.gold)
                                .shadow(color: .black, radius: 1, x: 1, y: 1)
                                .position(x: max(8, markerX), y: barHeight / 2)
                        }
                    }
                }
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isActive ? 3 : 2)
            }
            .frame(height: barHeight)
            
            Text(showMarkerOnThisBar ? "\(barMarkerValue)" : "\(Int(fill * 100))%")
                .fontStyle(isCompact ? FontStyles.statMedium : FontStyles.statMedium, color: showMarkerOnThisBar ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark)
                .frame(width: pctWidth, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }
    
    private func fillSideConsole(isCompact: Bool) -> some View {
        let statusText: String = {
            if isAnimatingRoll { return "..." }
            if viewModel.showReagentSelect { return "+\(viewModel.currentMiniBar?.reagentSelect ?? 0)%" }
            if let roll = viewModel.currentRoll { return roll.hit ? "+\(Int(roll.fillAdded * 100))%" : "+\(Int(roll.fillAdded * 100))%" }
            return "TAP ROLL"
        }()
        
        let statusColor: Color = {
            if isAnimatingRoll { return KingdomTheme.Colors.inkMedium }
            if viewModel.showReagentSelect { return KingdomTheme.Colors.gold }
            if let roll = viewModel.currentRoll { return roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger }
            return KingdomTheme.Colors.inkMedium
        }()
        
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: viewModel.showReagentSelect ? "scope" : "dial.medium.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(viewModel.showReagentSelect ? KingdomTheme.Colors.gold : KingdomTheme.Colors.royalBlue)
                Text(viewModel.showReagentSelect ? "REAGENT SELECT" : "INSTRUMENTS")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            
            Spacer(minLength: 0)
            
            Text("\(displayRollValue)")
                .font(.system(size: isCompact ? 48 : 64, weight: .black, design: .monospaced))
                .foregroundColor(rollColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text(statusText)
                .font(.system(size: isCompact ? 12 : 14, weight: .black, design: .serif))
                .foregroundColor(statusColor)
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mixture")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    Spacer()
                    Text("\(Int(viewModel.mainTubeFill * 100))%")
                        .fontStyle(FontStyles.statMedium, color: KingdomTheme.Colors.royalBlue)
                }
                
                GeometryReader { geo in
                    let clamped = min(1, max(0, viewModel.mainTubeFill))
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.parchmentDark)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.royalBlue)
                            .frame(width: max(6, geo.size.width * clamped), height: geo.size.height)
                            .animation(.easeOut(duration: 0.35), value: clamped)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                }
                .frame(height: 16)
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    private var fillRollPanel: some View {
        let rolls = viewModel.currentMiniBar?.rolls ?? []
        let shownCount = max(0, viewModel.currentRollIndex + 1)
        
        return VStack(spacing: 8) {
            HStack {
                Text("ROLL HISTORY")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            if rolls.isEmpty || shownCount <= 0 {
                HStack {
                    Text("Tap ROLL to begin")
                        .fontStyle(FontStyles.labelMedium, color: KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(rolls.prefix(shownCount).enumerated()), id: \.offset) { idx, roll in
                            ResearchRollCard(roll: roll, index: idx + 1)
                        }
                        
                        if viewModel.showReagentSelect, let bar = viewModel.currentMiniBar {
                            ReagentSelectCard(value: bar.reagentSelect)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(minHeight: 60)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
        .frame(maxWidth: .infinity)
    }
    
    private var rollColor: Color {
        if isAnimatingRoll {
            return KingdomTheme.Colors.royalBlue
        }
        if viewModel.showReagentSelect {
            return KingdomTheme.Colors.gold
        }
        if let roll = viewModel.currentRoll {
            return roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        }
        return KingdomTheme.Colors.inkLight
    }
    
    // MARK: - Cooking Phase View
    
    private var cookingPhaseView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sidePadding: CGFloat = 20
            let sectionSpacing: CGFloat = 12
            
            // One stable top row (tube + tiers) with matched heights, then a full-width result area below.
            let topRowHeight = max(240, min(h * 0.44, 360))
            let tubeWidth = max(86, min(w * 0.22, 132))
            let tubeHeight = max(200, topRowHeight - 24)
            
            VStack(spacing: sectionSpacing) {
                // Header
                HStack {
                    Text(viewModel.isExperimentComplete ? "COMPLETE" : "PHASE 2: COOKING")
                        .fontStyle(FontStyles.labelBlackSerif, color: viewModel.isExperimentComplete ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.gold)
                    Spacer()
                    if !viewModel.isExperimentComplete {
                        Text("\(viewModel.remainingAttempts + 1) left")
                            .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 6, borderWidth: 2)
                    }
                }
                .padding(.horizontal, sidePadding)
                
                // Top row: tube + potential tiers (stable)
                HStack(alignment: .top, spacing: 14) {
                    cookingTubeView(tubeWidth: tubeWidth, tubeHeight: tubeHeight)
                        .frame(maxHeight: .infinity, alignment: .top)
                    
                    rewardTiersPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: topRowHeight)
                .padding(.horizontal, sidePadding)
                
                // Bottom: big payoff/result area (reserved space; never collapses)
                cookingBigResultCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, sidePadding)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private func cookingTubeView(tubeWidth: CGFloat, tubeHeight: CGFloat) -> some View {
        let clampedFill = min(1, max(0, viewModel.mainTubeFill))
        
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchmentDark)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.royalBlue)
                .frame(height: max(4, tubeHeight * clampedFill))
                .overlay(BubblingOverlay())
            
            // Tier lines
            ForEach(Array(viewModel.rewardTiers.enumerated()), id: \.offset) { _, tier in
                if tier.minPercent > 0 {
                    let yOffset = tubeHeight * (1 - CGFloat(tier.minPercent) / 100.0)
                    Rectangle()
                        .fill(colorForTierId(tier.id))
                        .frame(height: 2)
                        .offset(y: -tubeHeight + yOffset)
                }
            }
            
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black, lineWidth: 2)
            
            // Marker
            // `cookingMarkerPosition` can overshoot during animation; clamp so it never renders outside the tube.
            let markerY = min(tubeHeight, max(0, tubeHeight * cookingMarkerPosition))
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(KingdomTheme.Colors.gold)
                .shadow(color: .black, radius: 1, x: 1, y: 1)
                .offset(x: -tubeWidth / 2 - 12, y: -markerY)
        }
        .frame(width: tubeWidth, height: tubeHeight)
        .padding(8)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    private var cookingBigResultCard: some View {
        let isComplete = viewModel.isExperimentComplete
        let landing = viewModel.bestLandingSoFar
        // Server-driven when complete (landedTierId), otherwise we can preview based on current best landing.
        let tier = isComplete ? viewModel.landedTier : viewModel.tierForLanding(landing)
        let outcome = viewModel.experiment?.outcome
        
        let titleColor: Color = isComplete ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkDark
        let landingColor = colorForLanding(landing)
        
        return ViewThatFits(in: .vertical) {
            cookingBigResultCardLayout(
                isCompact: false,
                isComplete: isComplete,
                landing: landing,
                landingColor: landingColor,
                titleColor: titleColor,
                tier: tier,
                outcome: outcome
            )
            cookingBigResultCardLayout(
                isCompact: true,
                isComplete: isComplete,
                landing: landing,
                landingColor: landingColor,
                titleColor: titleColor,
                tier: tier,
                outcome: outcome
            )
        }
    }
    
    private func cookingBigResultCardLayout(
        isCompact: Bool,
        isComplete: Bool,
        landing: Int,
        landingColor: Color,
        titleColor: Color,
        tier: RewardTier?,
        outcome: OutcomeResult?
    ) -> some View {
        // Big payoff only when complete; otherwise keep it informative (no giant % yet).
        let landingFontSize: CGFloat = {
            if isComplete { return isCompact ? 56 : 72 }
            return isCompact ? 40 : 44
        }()
        let tierFontSize: CGFloat = isCompact ? 18 : 22
        let padding: CGFloat = isCompact ? 12 : 16
        let vSpacing: CGFloat = isCompact ? 10 : 12
        
        return VStack(alignment: .leading, spacing: vSpacing) {
            HStack(spacing: 10) {
                Image(systemName: isComplete ? "checkmark.seal.fill" : "flame.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(isComplete ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.gold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isComplete ? "EXPERIMENT COMPLETE" : "COOKING IN PROGRESS")
                        .fontStyle(FontStyles.labelBlackSerif, color: titleColor)
                    Text(isComplete ? "Here’s what you earned" : "Potential rewards are listed above")
                        .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
                }
                
                Spacer(minLength: 0)
                
                if let tier {
                    Text(tier.label)
                        .font(.system(size: 12, weight: .black, design: .serif))
                        .foregroundColor(colorForTierId(tier.id))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.parchment,
                            cornerRadius: 12,
                            borderWidth: 2
                        )
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(landing)%")
                    .font(.system(size: landingFontSize, weight: .black, design: .monospaced))
                    .foregroundColor(landingColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                VStack(alignment: .leading, spacing: 6) {
                    if isComplete {
                        if let tier {
                            Text(tier.label)
                                .font(.system(size: tierFontSize, weight: .black, design: .serif))
                                .foregroundColor(colorForTierId(tier.id))
                        } else {
                            Text("Result")
                                .font(.system(size: tierFontSize, weight: .black, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    } else {
                        Text("Best landing so far")
                            .font(.system(size: tierFontSize, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
                    Text(isComplete ? "Final landing" : "Not final yet")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                }
                
                Spacer(minLength: 0)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("REWARDS")
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if isComplete, let outcome, (outcome.blueprints > 0 || outcome.gp > 0) {
                    HStack(spacing: 10) {
                        if outcome.blueprints > 0 {
                            rewardPill(icon: "scroll.fill", iconColor: KingdomTheme.Colors.royalBlue, text: "+\(outcome.blueprints) Blueprint\(outcome.blueprints == 1 ? "" : "s")")
                        }
                        if outcome.gp > 0 {
                            rewardPill(icon: "g.circle.fill", iconColor: KingdomTheme.Colors.gold, text: "+\(outcome.gp) Gold")
                        }
                        Spacer(minLength: 0)
                    }
                } else if isComplete {
                    Text("No rewards this time.")
                        .fontStyle(FontStyles.bodyMedium, color: KingdomTheme.Colors.inkMedium)
                } else {
                    Text("Complete all attempts to reveal your rewards.")
                        .fontStyle(FontStyles.bodyMedium, color: KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(padding)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private var rewardTiersPanel: some View {
        let currentTierId = viewModel.tierForLanding(viewModel.bestLandingSoFar)?.id
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REWARD TIERS")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer(minLength: 0)
                Text("RANGE")
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.rewardTiers.enumerated()), id: \.offset) { _, tier in
                        let isCurrentTier = currentTierId == tier.id
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorForTierId(tier.id))
                                    .frame(width: 10, height: 10)
                                
                                Text(tier.label)
                                    .font(.system(size: 14, weight: .black, design: .serif))
                                    .foregroundColor(colorForTierId(tier.id))
                                
                                Spacer(minLength: 0)
                                
                                Text("\(tier.minPercent)-\(tier.maxPercent)%")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            // Rewards per tier (BP + gold range)
                            HStack(spacing: 10) {
                                if tier.blueprints > 0 {
                                    Text("\(tier.blueprints) Blueprints")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                                }
                                if tier.gpMax > 0 {
                                    Text("Gold: \(goldRangeText(min: tier.gpMin, max: tier.gpMax))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                }
                                
                                Spacer(minLength: 0)
                                
                                if isCurrentTier {
                                    Text("CURRENT")
                                        .font(.system(size: 10, weight: .black, design: .serif))
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, borderWidth: 2)
                                }
                            }
                        }
                        .padding(12)
                        .background(isCurrentTier ? colorForTierId(tier.id).opacity(0.18) : KingdomTheme.Colors.parchment.opacity(0.18))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: isCurrentTier ? 3 : 2)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func goldRangeText(min: Int, max: Int) -> String {
        if max <= 0 { return "" }
        if min == max { return "\(max)g" }
        if min <= 0 { return "up to \(max)g" }
        return "\(min)-\(max)g"
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
    
    // MARK: - Main Tube View
    
    private func mainTubeView(tubeWidth: CGFloat, tubeHeight: CGFloat, showCookingMarker: Bool) -> some View {
        let clampedFill = min(1, max(0, viewModel.mainTubeFill))
        
        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                // Fill
                RoundedRectangle(cornerRadius: 16)
                    .fill(KingdomTheme.Colors.royalBlue)
                    .frame(height: max(4, tubeHeight * clampedFill))
                    .overlay(
                        // Bubbling effect for cooking phase
                        Group {
                            if showCookingMarker {
                                BubblingOverlay()
                            } else {
                                LinearGradient(
                                    colors: [KingdomTheme.Colors.parchmentHighlight.opacity(0.25), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    )
                    .animation(.easeOut(duration: 0.6), value: clampedFill)
                
                // Reward tier lines (from config)
                if showCookingMarker {
                    ForEach(Array(viewModel.rewardTiers.enumerated()), id: \.offset) { _, tier in
                        if tier.minPercent > 0 {
                            let yOffset = tubeHeight * (1 - CGFloat(tier.minPercent) / 100.0)
                            Rectangle()
                                .fill(colorForTierId(tier.id))
                                .frame(width: tubeWidth + 10, height: 2)
                                .offset(y: -tubeHeight + yOffset)
                        }
                    }
                }
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 3)
                
                // Cooking marker - animates from BOTTOM (0) to TOP (fill level)
                if showCookingMarker {
                    let maxFill = min(1, max(0, viewModel.mainTubeFill))
                    let markerY = tubeHeight * min(maxFill, max(0, cookingMarkerPosition))
                    
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                        .offset(x: -tubeWidth / 2 - 15, y: -markerY)
                }
            }
            .frame(width: tubeWidth, height: tubeHeight)

            Text(showCookingMarker ? "reagent level" : "main tube")
                .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
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
                    
                case .cooking:
                    if viewModel.isExperimentComplete {
                        Button {
                            Task { await viewModel.reset() }
                        } label: {
                            Text("TRY AGAIN")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(KingdomTheme.Colors.royalBlue)
                                .cornerRadius(8)
                        }
                    } else {
                        Button {
                            Task {
                                await doCookingLandingWithAnimation()
                            }
                        } label: {
                            Text(isAnimatingRoll ? "..." : "COOK")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isAnimatingRoll ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.gold)
                                .cornerRadius(8)
                        }
                        .disabled(isAnimatingRoll)
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
    
    // MARK: - Animations
    
    private func animateRoll(to finalValue: Int) async {
        isAnimatingRoll = true
        
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
            let sleepNs: UInt64 = (i > positions.count - 10) ? 45_000_000 : 22_000_000
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        
        displayRollValue = clampedFinal
        isAnimatingRoll = false
    }
    
    @MainActor
    private func doFillRollWithAnimation() async {
        guard !isAnimatingRoll else { return }
        guard viewModel.uiState == .filling, let bar = viewModel.currentMiniBar else { return }

        if viewModel.showReagentSelect {
            viewModel.doNextFillRoll()
            return
        }

        let nextRollIdx = viewModel.currentRollIndex + 1
        if nextRollIdx < bar.rolls.count {
            await animateRoll(to: bar.rolls[nextRollIdx].roll)
            await Task.yield()
            viewModel.doNextFillRoll()
        } else {
            let fillPct = max(1, Int(bar.finalFill * 100))
            await animateReagentSelection(maxValue: fillPct, finalValue: bar.reagentSelect)
            await Task.yield()
            viewModel.doNextFillRoll()
        }
    }
    
    @MainActor
    private func animateReagentSelection(maxValue: Int, finalValue: Int) async {
        isAnimatingRoll = true
        showBarMarker = true
        
        let clampedFinal = min(maxValue, max(1, finalValue))
        
        var positions: [Int] = []
        positions.append(contentsOf: stride(from: 1, through: maxValue, by: max(1, maxValue / 25)))
        if clampedFinal < maxValue {
            positions.append(contentsOf: stride(from: maxValue, through: clampedFinal, by: -max(1, maxValue / 25)))
        }
        if positions.last != clampedFinal {
            positions.append(clampedFinal)
        }
        
        for (i, pos) in positions.enumerated() {
            barMarkerValue = pos
            displayRollValue = pos
            let sleepNs: UInt64 = (i > positions.count - 8) ? 50_000_000 : 25_000_000
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        
        barMarkerValue = clampedFinal
        displayRollValue = clampedFinal
        isAnimatingRoll = false
    }
    
    // MARK: - Cooking Animations
    
    @MainActor
    private func doCookingLandingWithAnimation() async {
        guard !isAnimatingRoll else { return }
        isAnimatingRoll = true
        
        // Marker should never exceed the actual reagent fill level.
        let maxFill = min(1, max(0, viewModel.mainTubeFill))
        func clampToReagent(_ v: CGFloat) -> CGFloat {
            min(maxFill, max(0, v))
        }
        
        // Get the landing result first so we know where to end
        viewModel.doNextLanding()
        let finalPosition = clampToReagent(viewModel.currentLanding.map { CGFloat($0.landingPosition) / 100.0 } ?? 0)
        
        // Normal, clean animation:
        // - smooth move to a small overshoot
        // - spring settle to final
        let overshoot = clampToReagent(finalPosition + 0.06)
        withAnimation(.easeInOut(duration: 0.35)) {
            cookingMarkerPosition = overshoot
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            cookingMarkerPosition = finalPosition
        }
        try? await Task.sleep(nanoseconds: 420_000_000)
        
        isAnimatingRoll = false
    }
    
    // MARK: - Helpers
    
    private func colorForLanding(_ landing: Int) -> Color {
        if let tier = viewModel.tierForLanding(landing) {
            return colorForTierId(tier.id)
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private func colorForTierId(_ tierId: String) -> Color {
        switch tierId {
        case "critical": return KingdomTheme.Colors.gold
        case "success": return KingdomTheme.Colors.buttonSuccess
        case "fail": return KingdomTheme.Colors.buttonDanger
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Bubbling Overlay

private struct BubblingOverlay: View {
    @State private var bubbles: [(id: Int, x: CGFloat, delay: Double)] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles, id: \.id) { bubble in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: CGFloat.random(in: 4...12), height: CGFloat.random(in: 4...12))
                        .modifier(BubbleAnimation(height: geo.size.height, delay: bubble.delay))
                        .position(x: bubble.x, y: geo.size.height)
                }
            }
            .onAppear {
                bubbles = (0..<8).map { i in
                    (id: i, x: CGFloat.random(in: 10...(geo.size.width - 10)), delay: Double(i) * 0.3)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BubbleAnimation: ViewModifier {
    let height: CGFloat
    let delay: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -height : 0)
            .opacity(isAnimating ? 0 : 0.6)
            .animation(
                Animation.easeOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
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

private struct ReagentSelectCard: View {
    let value: Int
    
    var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchmentHighlight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(KingdomTheme.Colors.gold, lineWidth: 3)
                    )
                
                    Text("\(value)")
                .fontStyle(FontStyles.statMedium, color: KingdomTheme.Colors.gold)
        }
        .frame(width: 48, height: 48)
    }
}

#Preview {
    NavigationStack {
        ResearchView(apiClient: APIClient.shared)
    }
}
