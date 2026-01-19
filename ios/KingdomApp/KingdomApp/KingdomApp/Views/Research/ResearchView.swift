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
    
    // Cooking phase marker animation - only for FINAL roll
    @State private var cookingMarkerPosition: CGFloat = 0
    @State private var showFinalRollMarker: Bool = false
    
    // Crystallization reveal state - shows "REVEAL" button after last roll
    @State private var showingFinalReveal: Bool = false
    
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
                // Reset for crystallization phase
                displayRollValue = 0
                cookingMarkerPosition = 0
                isAnimatingRoll = false
                showingFinalReveal = false
                showFinalRollMarker = false
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
                    HStack(spacing: 8) {
                        ForEach(Array(rolls.prefix(shownCount).enumerated()), id: \.offset) { idx, roll in
                            ResearchRollCard(roll: roll, index: idx + 1)
                        }
                        
                        if viewModel.showReagentSelect, let bar = viewModel.currentMiniBar {
                            ReagentSelectCard(value: bar.reagentSelect)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(height: 60)
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
    
    // MARK: - Cooking Phase View (Crystallization)
    
    private var cookingPhaseView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let isCompact = h < 700
            let sidePadding: CGFloat = 20
            let sectionSpacing: CGFloat = isCompact ? 10 : KingdomTheme.Spacing.medium
            let tubeWidth = max(84, min(w * 0.26, 140))
            let tubeHeight = max(isCompact ? 170 : 210, min(h * (isCompact ? 0.38 : 0.42), 420))
            
            VStack(spacing: sectionSpacing) {
                // Top card (like mini bars in Phase 1)
                crystalResultCard
                    .layoutPriority(1)
                
                // Middle: tube + side console
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    crystallizationTubeView(tubeWidth: tubeWidth, tubeHeight: tubeHeight)
                    
                    crystalSideConsole
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
                
                // Bottom: roll history panel
                crystalRollPanel
                    .frame(minHeight: isCompact ? 110 : 130)
                    .layoutPriority(2)
            }
            .padding(.horizontal, sidePadding)
            .padding(.vertical, isCompact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private func crystallizationTubeView(tubeWidth: CGFloat, tubeHeight: CGFloat) -> some View {
        let ceiling = min(1, max(0, viewModel.mainTubeFill))
        let floor = min(ceiling, max(0, viewModel.crystalFloor))
        let hitCount = viewModel.crystalRolls.prefix(max(0, viewModel.currentCrystalRollIndex + 1)).filter { $0.hit }.count
        
        return VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                // Ceiling liquid (reagent from Phase 1)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.royalBlue.opacity(0.4))
                    .frame(height: max(4, tubeHeight * ceiling))
                    .overlay(BubblingOverlay())
                
                // Crystal growth from bottom - gets more structured with each hit
                CrystalGrowthOverlay(
                    floor: floor,
                    hitCount: hitCount,
                    tubeWidth: tubeWidth,
                    tubeHeight: tubeHeight
                )
                .frame(width: tubeWidth, height: tubeHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Tier lines
                ForEach(Array(viewModel.rewardTiers.enumerated()), id: \.offset) { _, tier in
                    if tier.minPercent > 0 {
                        let yPos = tubeHeight * CGFloat(tier.minPercent) / 100.0
                        Rectangle()
                            .fill(colorForTierId(tier.id))
                            .frame(height: 2)
                            .offset(y: -yPos)
                    }
                }
                
                // Rolling marker - ONLY shows during FINAL roll
                if showFinalRollMarker {
                    HStack(spacing: 0) {
                        // Left arrow
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .shadow(color: .black, radius: 1, x: 1, y: 1)
                        
                        Spacer()
                        
                        // Right arrow
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .shadow(color: .black, radius: 1, x: 1, y: 1)
                    }
                    .frame(width: tubeWidth + 24)
                    .offset(y: -tubeHeight * cookingMarkerPosition + tubeHeight / 2)
                }
                
                // Border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2)
            }
            .frame(width: tubeWidth, height: tubeHeight)
            
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("CEIL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    Text("\(viewModel.ceiling)%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("FLOOR")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.regalPurple)
                    Text("\(Int(viewModel.crystalFloor * 100))%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.regalPurple)
                }
            }
            .frame(width: tubeWidth)
        }
        .padding(10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private var crystalSideConsole: some View {
        let statusText: String = {
            if isAnimatingRoll { return "..." }
            if let roll = viewModel.currentCrystalRoll {
                return roll.hit ? "+\(roll.floorGain)% FLOOR" : "MISS"
            }
            return "TAP ROLL"
        }()
        
        let statusColor: Color = {
            if isAnimatingRoll { return KingdomTheme.Colors.inkMedium }
            if let roll = viewModel.currentCrystalRoll {
                return roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
            }
            return KingdomTheme.Colors.inkMedium
        }()
        
        return VStack(spacing: 6) {
            HStack {
                Image(systemName: "sparkles")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.regalPurple)
                Text("CRYSTALLIZE")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
                // Show Philosophy skill
                HStack(spacing: 3) {
                    Text("PHI")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(viewModel.stats?.philosophy ?? 0)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .foregroundColor(KingdomTheme.Colors.regalPurple)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(KingdomTheme.Colors.regalPurple.opacity(0.15))
                .cornerRadius(6)
            }
            
            Spacer(minLength: 0)
            
            Text("\(displayRollValue)")
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundColor(crystalRollColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text(statusText)
                .font(.system(size: 12, weight: .black, design: .serif))
                .foregroundColor(statusColor)
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Tier")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    Spacer()
                    if let tier = viewModel.tierForFloor(Int(viewModel.crystalFloor * 100)) {
                        Text(tier.label)
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundColor(colorForTierId(tier.id))
                    } else {
                        Text("FAIL")
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.parchmentDark)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.regalPurple)
                            .frame(width: max(4, geo.size.width * viewModel.crystalFloor))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.crystalFloor)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: 2)
                    )
                }
                .frame(height: 12)
            }
        }
        .padding(10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    private var crystalRollPanel: some View {
        let rolls = viewModel.crystalRolls
        let shownCount = max(0, viewModel.currentCrystalRollIndex + 1)
        
        return VStack(spacing: 6) {
            HStack {
                Text("ROLL HISTORY")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            
            if rolls.isEmpty || shownCount <= 0 {
                HStack {
                    Text("Tap ROLL to crystallize")
                        .fontStyle(FontStyles.labelMedium, color: KingdomTheme.Colors.inkMedium)
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(rolls.prefix(shownCount).enumerated()), id: \.offset) { idx, roll in
                            CrystalRollCard(roll: roll, index: idx + 1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(height: 60)
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    private var crystalResultCard: some View {
        let isComplete = viewModel.isExperimentComplete
        let isRevealed = showingFinalReveal
        let floor = Int(viewModel.crystalFloor * 100)
        let tier = (isComplete && isRevealed) ? viewModel.landedTier : viewModel.tierForFloor(floor)
        let outcome = viewModel.experiment?.outcome
        
        return VStack(alignment: .leading, spacing: 8) {
            // Header row (like Phase 1)
            HStack {
                Text(isComplete ? "COMPLETE" : "PHASE 2: CRYSTALLIZATION")
                    .fontStyle(FontStyles.labelBlackSerif, color: isComplete ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.regalPurple)
                Spacer()
                if !isComplete {
                    Text("\(viewModel.remainingCrystalRolls) left")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 6, borderWidth: 2)
                } else if isRevealed, let tier {
                    Text(tier.label)
                        .font(.system(size: 10, weight: .black, design: .serif))
                        .foregroundColor(colorForTierId(tier.id))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, borderWidth: 2)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if isComplete && !isRevealed {
                    // Hide final result until revealed
                    Text("??%")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text("Tap REVEAL")
                        .font(.system(size: 12, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.gold)
                } else {
                    Text("\(floor)%")
                        .font(.system(size: (isComplete && isRevealed) ? 40 : 32, weight: .black, design: .monospaced))
                        .foregroundColor(colorForFloor(floor))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text((isComplete && isRevealed) ? "FINAL FLOOR" : "Current Floor")
                        .font(.system(size: 12, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer(minLength: 0)
            }
            
            if isComplete && isRevealed, let outcome, (outcome.blueprints > 0 || outcome.gp > 0) {
                HStack(spacing: 6) {
                    if outcome.blueprints > 0 {
                        rewardPill(icon: "scroll.fill", iconColor: KingdomTheme.Colors.royalBlue, text: "+\(outcome.blueprints) BP")
                    }
                    if outcome.gp > 0 {
                        rewardPill(icon: "g.circle.fill", iconColor: KingdomTheme.Colors.gold, text: "+\(outcome.gp)g")
                    }
                    Spacer(minLength: 0)
                }
            } else if isComplete && isRevealed {
                Text("No rewards this time.")
                    .fontStyle(FontStyles.bodyMedium, color: KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
        .frame(maxWidth: .infinity, minHeight: 120)
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
                    if viewModel.isPhase1Complete {
                        // Phase 1 done - show CRYSTALLIZE button
                        Button {
                            viewModel.transitionToCrystallization()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("CRYSTALLIZE")
                            }
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.regalPurple)
                            .cornerRadius(8)
                        }
                    } else {
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
                    }
                    
                case .cooking:
                    if viewModel.isExperimentComplete && showingFinalReveal {
                        // All rolls done, revealed - show TRY AGAIN
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
                    } else if viewModel.isExperimentComplete && !showingFinalReveal {
                        // All rolls done, waiting to reveal
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showingFinalReveal = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("REVEAL RESULTS")
                            }
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.gold)
                            .cornerRadius(8)
                        }
                    } else {
                        // Still rolling
                        Button {
                            Task {
                                await doCrystallizationRollWithAnimation()
                            }
                        } label: {
                            Text(isAnimatingRoll ? "..." : "ROLL (\(viewModel.remainingCrystalRolls + 1) left)")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isAnimatingRoll ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.regalPurple)
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
        
        // Build roll sequence: 1 -> 100 -> final value
        var positions: [Int] = []
        positions.append(contentsOf: stride(from: 1, through: 100, by: 3))  // Slower: step by 3 instead of 4
        
        if clampedFinal < 100 {
            positions.append(contentsOf: stride(from: 100, through: max(1, clampedFinal), by: -3))
        }
        if positions.last != clampedFinal {
            positions.append(clampedFinal)
        }
        
        for (i, pos) in positions.enumerated() {
            displayRollValue = pos
            let sleepNs: UInt64 = (i > positions.count - 8) ? 30_000_000 : 18_000_000
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
            // Pour reagent into main tube
            viewModel.doNextFillRoll()
            // Wait for pour animation to complete
            try? await Task.sleep(nanoseconds: 600_000_000)
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
    
    // MARK: - Crystallization Roll Animation
    
    @MainActor
    private func doCrystallizationRollWithAnimation() async {
        guard !isAnimatingRoll else { return }
        guard viewModel.uiState == .cooking else { return }
        
        let nextIdx = viewModel.currentCrystalRollIndex + 1
        guard nextIdx < viewModel.crystalRolls.count else { return }
        
        let roll = viewModel.crystalRolls[nextIdx]
        let isFinalRoll = nextIdx == viewModel.crystalRolls.count - 1
        
        if isFinalRoll {
            // FINAL ROLL - big marker animation on the tube
            let currentFloor = viewModel.crystalFloor
            let ceiling = viewModel.mainTubeFill
            
            isAnimatingRoll = true
            showFinalRollMarker = true
            
            // Animate marker bouncing between FLOOR and CEILING
            let totalBounces = 15
            for _ in 0..<totalBounces {
                let randomPos = CGFloat.random(in: currentFloor...ceiling)
                cookingMarkerPosition = randomPos
                displayRollValue = Int.random(in: Int(currentFloor * 100)...Int(ceiling * 100))
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
            
            // Land on final floor value
            let finalFloor = currentFloor + (roll.hit ? CGFloat(roll.floorGain) / 100.0 : 0)
            cookingMarkerPosition = min(finalFloor, ceiling)
            displayRollValue = Int(finalFloor * 100)
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            isAnimatingRoll = false
            showFinalRollMarker = false
            
            // Update viewModel state
            viewModel.doNextCrystalRoll()
            
            try? await Task.sleep(nanoseconds: 400_000_000)
        } else {
            // Regular roll - just animate number
            await animateRoll(to: roll.roll)
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            
            viewModel.doNextCrystalRoll()
            
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
    
    // MARK: - Helpers
    
    private func colorForFloor(_ floor: Int) -> Color {
        if let tier = viewModel.tierForFloor(floor) {
            return colorForTierId(tier.id)
        }
        return KingdomTheme.Colors.buttonDanger
    }
    
    private var crystalRollColor: Color {
        if isAnimatingRoll {
            return KingdomTheme.Colors.regalPurple
        }
        if let roll = viewModel.currentCrystalRoll {
            return roll.hit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        }
        return KingdomTheme.Colors.inkLight
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

// MARK: - Crystal Grid Overlay

private struct CrystalGrowthOverlay: View {
    let floor: CGFloat
    let hitCount: Int
    let tubeWidth: CGFloat
    let tubeHeight: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Diamond grid overlay - gets more visible with each hit
                if hitCount > 0 {
                    DiamondGridOverlay(hitCount: hitCount)
                        .frame(width: tubeWidth, height: tubeHeight * floor)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: floor)
        .animation(.easeInOut(duration: 0.3), value: hitCount)
    }
}

private struct DiamondGridOverlay: View {
    let hitCount: Int
    
    // Opacity increases with hits - gets DARKER: 0.25 -> 0.45 -> 0.65 -> 0.85...
    private var gridOpacity: Double {
        min(0.95, 0.25 + Double(hitCount) * 0.18)
    }
    
    // Line width increases with hits - thicker = more solid
    private var lineWidth: CGFloat {
        min(3.0, 1.0 + CGFloat(hitCount) * 0.25)
    }
    
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 12
            
            // Draw diamond grid (diagonal lines both ways)
            var path = Path()
            
            // Lines going ↗ (bottom-left to top-right)
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            
            // Lines going ↖ (bottom-right to top-left)
            x = 0
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x - size.height, y: 0))
                x += spacing
            }
            
            // Rich purple crystal color - gets darker/more solid with hits
            context.stroke(
                path,
                with: .color(Color(red: 0.5, green: 0.2, blue: 0.8).opacity(gridOpacity)),
                lineWidth: lineWidth
            )
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
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(textColor)
        }
        .frame(width: 44, height: 44)
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
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.gold)
        }
        .frame(width: 44, height: 44)
    }
}

private struct CrystalRollCard: View {
    let roll: CrystallizationRoll
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
            
            VStack(spacing: 1) {
                Text("\(roll.roll)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(textColor)
                if roll.hit {
                    Text("+\(roll.floorGain)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
        }
        .frame(width: 44, height: 44)
    }
    
    private var cardBackground: Color {
        roll.hit ? KingdomTheme.Colors.parchmentHighlight : KingdomTheme.Colors.parchment
    }
    
    private var cardBorder: Color {
        roll.hit ? KingdomTheme.Colors.regalPurple : Color.black
    }
    
    private var textColor: Color {
        roll.hit ? KingdomTheme.Colors.regalPurple : KingdomTheme.Colors.inkMedium
    }
}

#Preview {
    NavigationStack {
        ResearchView(apiClient: APIClient.shared)
    }
}
