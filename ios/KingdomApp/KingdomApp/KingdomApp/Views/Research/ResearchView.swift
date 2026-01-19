import SwiftUI

struct ResearchView: View {
    @StateObject private var viewModel: ResearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    // Infusion animation state
    @State private var displayValue: Int = 0
    @State private var isAnimating: Bool = false
    
    // Reagent selection bar marker animation
    @State private var barMarkerValue: Int = 0
    @State private var showBarMarker: Bool = false
    
    // Synthesis phase marker animation - for FINAL infusion
    @State private var synthesisMarkerPosition: CGFloat = 0
    @State private var showFinalMarker: Bool = false
    
    // Result reveal state
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
            if newState == .idle {
                // Reset everything for new experiment
                displayValue = 0
                isAnimating = false
                showBarMarker = false
                barMarkerValue = 0
                synthesisMarkerPosition = 0
                showFinalMarker = false
                showingFinalReveal = false
            } else if newState == .preparation {
                displayValue = 0
                isAnimating = false
                showBarMarker = false
                barMarkerValue = 0
            } else if newState == .synthesis {
                displayValue = 0
                synthesisMarkerPosition = 0
                isAnimating = false
                showingFinalReveal = false
                showFinalMarker = false
            } else if newState == .finalInfusion {
                // Don't auto-show marker - wait for button tap
            }
        }
        .onChange(of: viewModel.currentReagentIndex) { _, _ in
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
                    
                case .preparation:
                    preparationPhaseView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .synthesis, .finalInfusion:
                    synthesisPhaseView
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
            
            // Show result tiers from config
            if let tiers = viewModel.config?.phase2Synthesis.resultTiers, !tiers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RESULT TIERS")
                        .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                    
                    ForEach(Array(tiers.enumerated()), id: \.offset) { _, tier in
                        HStack {
                            Text("\(tier.minPurity)-\(tier.maxPurity)%")
                                .fontStyle(FontStyles.statSmall, color: KingdomTheme.Colors.inkMedium)
                                .frame(width: 60, alignment: .leading)
                            Image(systemName: tier.icon)
                                .font(.system(size: 12))
                                .foregroundColor(colorForTierId(tier.id))
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
    
    // MARK: - Preparation Phase View (Phase 1)
    
    private var preparationPhaseView: some View {
        GeometryReader { geo in
            ViewThatFits(in: .vertical) {
                preparationLayout(size: geo.size, isCompact: false)
                preparationLayout(size: geo.size, isCompact: true)
                ScrollView(.vertical, showsIndicators: false) {
                    preparationLayout(size: geo.size, isCompact: true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func preparationLayout(size: CGSize, isCompact: Bool) -> some View {
        let w = size.width
        let h = size.height
        let sidePadding: CGFloat = 20
        let verticalPadding: CGFloat = isCompact ? 12 : 16
        let sectionSpacing: CGFloat = isCompact ? 10 : KingdomTheme.Spacing.medium
        let tubeWidth = max(84, min(w * 0.26, 140))
        let tubeHeight = max(isCompact ? 170 : 210, min(h * (isCompact ? 0.38 : 0.42), 420))
        
        return VStack(spacing: sectionSpacing) {
            reagentBarsCard(isCompact: isCompact)
                .layoutPriority(1)
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                mainTubeView(tubeWidth: tubeWidth, tubeHeight: tubeHeight)
                
                preparationConsole(isCompact: isCompact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            infusionHistoryPanel
                .frame(minHeight: isCompact ? 110 : 130)
                .layoutPriority(2)
        }
        .padding(.horizontal, sidePadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Preparation UI Sections
    
    private func reagentBarsCard(isCompact: Bool) -> some View {
        return VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack {
                Text("PHASE 1: PREPARATION")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            .frame(height: isCompact ? 16 : 18)
            
            VStack(spacing: isCompact ? 5 : 6) {
                ForEach(0..<viewModel.reagentNames.count, id: \.self) { idx in
                    reagentBarRow(index: idx, isCompact: isCompact)
                }
            }
        }
        .padding(isCompact ? 8 : 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
        .frame(maxWidth: .infinity)
    }
    
    private func reagentBarRow(index: Int, isCompact: Bool) -> some View {
        let isActive = viewModel.currentReagentIndex == index
        let barNames = viewModel.reagentNames
        let barName = index < barNames.count ? barNames[index] : "REAGENT \(index + 1)"
        let fill = index < viewModel.reagentFills.count ? min(1, max(0, viewModel.reagentFills[index])) : 0
        
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
                    Text(isActive && viewModel.showAmountSelect ? "MEASURING" : (isActive ? "MIXING" : "READY"))
                        .fontStyle(FontStyles.captionLarge, color: isActive && viewModel.showAmountSelect ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium.opacity(isActive ? 1 : 0.7))
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
    
    private func preparationConsole(isCompact: Bool) -> some View {
        let statusText: String = {
            if isAnimating { return "..." }
            if viewModel.showAmountSelect { return "+\(viewModel.currentReagent?.amountSelected ?? 0)%" }
            if let inf = viewModel.currentInfusion { return inf.stable ? "Stable" : "Volatile" }
            return "TAP INFUSE"
        }()
        
        let statusColor: Color = {
            if isAnimating { return KingdomTheme.Colors.inkMedium }
            if viewModel.showAmountSelect { return KingdomTheme.Colors.gold }
            if let inf = viewModel.currentInfusion { return inf.stable ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger }
            return KingdomTheme.Colors.inkMedium
        }()
        
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: viewModel.showAmountSelect ? "scope" : "dial.medium.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(viewModel.showAmountSelect ? KingdomTheme.Colors.gold : KingdomTheme.Colors.royalBlue)
                Text(viewModel.showAmountSelect ? "MEASURE" : "INSTRUMENTS")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            
            Spacer(minLength: 0)
            
            Text("\(displayValue)")
                .font(.system(size: isCompact ? 48 : 64, weight: .black, design: .monospaced))
                .foregroundColor(infusionColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text(statusText)
                .font(.system(size: isCompact ? 12 : 14, weight: .black, design: .serif))
                .foregroundColor(statusColor)
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Potential")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    Spacer()
                    Text("\(Int(viewModel.potential * 100))%")
                        .fontStyle(FontStyles.statMedium, color: KingdomTheme.Colors.royalBlue)
                }
                
                GeometryReader { geo in
                    let clamped = min(1, max(0, viewModel.potential))
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
    
    private var infusionHistoryPanel: some View {
        let infusions = viewModel.currentReagent?.infusions ?? []
        let shownCount = max(0, viewModel.currentInfusionIndex + 1)
        
        return VStack(spacing: 8) {
            HStack {
                Text("INFUSION HISTORY")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            if infusions.isEmpty || shownCount <= 0 {
                HStack {
                    Text("Tap INFUSE to begin")
                        .fontStyle(FontStyles.labelMedium, color: KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(infusions.prefix(shownCount).enumerated()), id: \.offset) { idx, inf in
                            InfusionCard(infusion: inf, index: idx + 1)
                        }
                        
                        if viewModel.showAmountSelect, let reagent = viewModel.currentReagent {
                            AmountSelectCard(value: reagent.amountSelected)
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
    
    private var infusionColor: Color {
        if isAnimating {
            return KingdomTheme.Colors.royalBlue
        }
        if viewModel.showAmountSelect {
            return KingdomTheme.Colors.gold
        }
        if let inf = viewModel.currentInfusion {
            return inf.stable ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        }
        return KingdomTheme.Colors.inkLight
    }
    
    // MARK: - Synthesis Phase View (Phase 2)
    
    private var synthesisPhaseView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let isCompact = h < 700
            let sidePadding: CGFloat = 20
            let sectionSpacing: CGFloat = isCompact ? 10 : KingdomTheme.Spacing.medium
            let tubeWidth = max(84, min(w * 0.26, 140))
            let tubeHeight = max(isCompact ? 170 : 210, min(h * (isCompact ? 0.38 : 0.42), 420))
            
            VStack(spacing: sectionSpacing) {
                synthesisStatusCard
                    .layoutPriority(1)
                
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    synthesisTubeView(tubeWidth: tubeWidth, tubeHeight: tubeHeight)
                    
                    synthesisConsole
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
                
                synthesisHistoryPanel
                    .frame(minHeight: isCompact ? 110 : 130)
                    .layoutPriority(2)
            }
            .padding(.horizontal, sidePadding)
            .padding(.vertical, isCompact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private func synthesisTubeView(tubeWidth: CGFloat, tubeHeight: CGFloat) -> some View {
        // ALWAYS clamp to 0-1 range
        let potentialFrac = min(1.0, max(0, viewModel.potential))
        let purityFrac = min(1.0, max(0, min(potentialFrac, viewModel.purity)))
        let hitCount = viewModel.synthesisInfusions.prefix(max(0, viewModel.currentSynthesisIndex + 1)).filter { $0.stable }.count
        
        return VStack(spacing: 6) {
            // The tube container - use GeometryReader for precise marker positioning
            GeometryReader { tubeGeo in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KingdomTheme.Colors.parchmentDark)
                    
                    // Potential liquid (from Phase 1) - fills from bottom
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KingdomTheme.Colors.royalBlue.opacity(0.4))
                            .frame(height: max(4, tubeGeo.size.height * potentialFrac))
                            .overlay(BubblingOverlay())
                    }
                    
                    // Crystal growth from bottom - purity level
                    VStack {
                        Spacer()
                        CrystalGrowthOverlay(
                            purity: purityFrac,
                            hitCount: hitCount,
                            tubeWidth: tubeGeo.size.width,
                            tubeHeight: tubeGeo.size.height
                        )
                        .frame(width: tubeGeo.size.width, height: tubeGeo.size.height * purityFrac)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Tier threshold lines - positioned from bottom
                    ForEach(Array(viewModel.resultTiers.enumerated()), id: \.offset) { _, tier in
                        if tier.minPurity > 0 {
                            let yFromBottom = tubeGeo.size.height * CGFloat(tier.minPurity) / 100.0
                            Rectangle()
                                .fill(colorForTierId(tier.id))
                                .frame(height: 2)
                                .position(x: tubeGeo.size.width / 2, y: tubeGeo.size.height - yFromBottom)
                        }
                    }
                    
                    // Final infusion marker - bounces between purity and potential
                    if showFinalMarker {
                        let clampedPos = min(1.0, max(0, synthesisMarkerPosition))
                        let markerY = tubeGeo.size.height * (1 - clampedPos)
                        
                        HStack(spacing: 0) {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(KingdomTheme.Colors.gold)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                            
                            Rectangle()
                                .fill(KingdomTheme.Colors.gold)
                                .frame(height: 3)
                            
                            Image(systemName: "arrowtriangle.left.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(KingdomTheme.Colors.gold)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                        }
                        .frame(width: tubeGeo.size.width + 30)
                        .position(x: tubeGeo.size.width / 2, y: markerY)
                    }
                    
                    // Border
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2)
                }
            }
            .frame(width: tubeWidth, height: tubeHeight)
            
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("POTENTIAL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    Text("\(viewModel.potentialPercent)%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("PURITY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.regalPurple)
                    Text("\(Int(viewModel.purity * 100))%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.regalPurple)
                }
            }
            .frame(width: tubeWidth)
        }
        .padding(10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private var synthesisConsole: some View {
        let isFinalPhase = viewModel.uiState == .finalInfusion
        
        let statusText: String = {
            if isAnimating { return "..." }
            if isFinalPhase { return "Final Synthesis!" }
            if let inf = viewModel.currentSynthesisInfusion {
                return inf.stable ? "+\(inf.purityGained) Purity" : "Volatile"
            }
            return "TAP INFUSE"
        }()
        
        let statusColor: Color = {
            if isAnimating { return KingdomTheme.Colors.inkMedium }
            if isFinalPhase { return KingdomTheme.Colors.gold }
            if let inf = viewModel.currentSynthesisInfusion {
                return inf.stable ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
            }
            return KingdomTheme.Colors.inkMedium
        }()
        
        return VStack(spacing: 6) {
            HStack {
                Image(systemName: isFinalPhase ? "sparkles" : "sparkles")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(isFinalPhase ? KingdomTheme.Colors.gold : KingdomTheme.Colors.regalPurple)
                Text(isFinalPhase ? "FINAL SYNTHESIS" : "SYNTHESIS")
                    .fontStyle(FontStyles.labelBlackSerif, color: isFinalPhase ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark)
                Spacer()
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
            
            Text("\(displayValue)")
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundColor(synthesisValueColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text(statusText)
                .font(.system(size: 12, weight: .black, design: .serif))
                .foregroundColor(statusColor)
            
            // Progress message
            if !viewModel.progressMessage.isEmpty && !isFinalPhase {
                Text(viewModel.progressMessage)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .italic()
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current Tier")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                    Spacer()
                    if let tier = viewModel.tierForPurity(Int(viewModel.purity * 100)) {
                        Text(tier.label)
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundColor(colorForTierId(tier.id))
                    } else {
                        Text("UNSTABLE")
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.parchmentDark)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.regalPurple)
                            .frame(width: max(4, geo.size.width * viewModel.purity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.purity)
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
    
    private var synthesisHistoryPanel: some View {
        let infusions = viewModel.synthesisInfusions
        let shownCount = max(0, viewModel.currentSynthesisIndex + 1)
        
        return VStack(spacing: 6) {
            HStack {
                Text("INFUSION HISTORY")
                    .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkDark)
                Spacer()
            }
            
            if infusions.isEmpty || shownCount <= 0 {
                HStack {
                    Text("Tap INFUSE to begin synthesis")
                        .fontStyle(FontStyles.labelMedium, color: KingdomTheme.Colors.inkMedium)
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(infusions.prefix(shownCount).enumerated()), id: \.offset) { idx, inf in
                            SynthesisInfusionCard(infusion: inf, index: idx + 1)
                        }
                        
                        // Show final infusion card if we're in that phase and revealed
                        if viewModel.uiState == .result, let final = viewModel.finalInfusionResult {
                            FinalInfusionCard(infusion: final)
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
    
    private var synthesisStatusCard: some View {
        let isFinalPhase = viewModel.uiState == .finalInfusion
        let isRevealed = showingFinalReveal
        let purityPct = Int(viewModel.purity * 100)
        let tier = isRevealed ? viewModel.landedTier : viewModel.tierForPurity(purityPct)
        let outcome = viewModel.experiment?.outcome
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isRevealed {
                    // Show result header
                    if let tier = tier {
                        HStack(spacing: 6) {
                            Image(systemName: tier.icon)
                                .font(.system(size: 14))
                            Text(tier.label)
                        }
                        .fontStyle(FontStyles.labelBlackSerif, color: colorForTierId(tier.id))
                    } else {
                        Text("UNSTABLE")
                            .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.inkMedium)
                    }
                } else if isFinalPhase {
                    Text("FINAL SYNTHESIS")
                        .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.gold)
                } else {
                    Text("PHASE 2: SYNTHESIS")
                        .fontStyle(FontStyles.labelBlackSerif, color: KingdomTheme.Colors.regalPurple)
                }
                Spacer()
                if isRevealed {
                    // Show final purity badge
                    Text("\(purityPct)% PURITY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(colorForPurity(purityPct))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, borderWidth: 2)
                } else if isFinalPhase && !isAnimating {
                    Text("One last infusion...")
                        .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.gold)
                        .italic()
                } else if !isFinalPhase {
                    Text("\(viewModel.remainingSynthesisInfusions) left")
                        .fontStyle(FontStyles.labelSmall, color: KingdomTheme.Colors.inkMedium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 6, borderWidth: 2)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if isRevealed {
                // Show result details
                if let outcome = outcome {
                    Text(outcome.title)
                        .font(.system(size: 18, weight: .black, design: .serif))
                        .foregroundColor(colorForPurity(purityPct))
                    
                    Text(outcome.message)
                        .fontStyle(FontStyles.bodySmall, color: KingdomTheme.Colors.inkMedium)
                    
                    if outcome.blueprints > 0 || outcome.gp > 0 {
                        HStack(spacing: 6) {
                            if outcome.blueprints > 0 {
                                rewardPill(icon: "scroll.fill", iconColor: KingdomTheme.Colors.royalBlue, text: "+\(outcome.blueprints) BP")
                            }
                            if outcome.gp > 0 {
                                rewardPill(icon: "g.circle.fill", iconColor: KingdomTheme.Colors.gold, text: "+\(outcome.gp)g")
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            } else {
                // Show current purity
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(purityPct)%")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(colorForPurity(purityPct))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text("Current Purity")
                        .font(.system(size: 12, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
        .frame(maxWidth: .infinity, minHeight: 120)
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
                        Text(outcome?.title ?? "Unknown")
                            .fontStyle(FontStyles.captionLarge, color: KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    if let tier = viewModel.landedTier {
                        HStack(spacing: 4) {
                            Image(systemName: tier.icon)
                            Text(tier.label)
                        }
                        .fontStyle(FontStyles.labelSmall, color: colorForTierId(tier.id))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.parchmentLight,
                            cornerRadius: 10,
                            borderWidth: 2
                        )
                    }
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
        if outcome.success { return outcome.isEureka ? "sparkles" : "checkmark.seal.fill" }
        return "wind"
    }
    
    private func outcomeColor(_ outcome: OutcomeResult?) -> Color {
        guard let outcome else { return KingdomTheme.Colors.inkMedium }
        if outcome.success { return outcome.isEureka ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonSuccess }
        return KingdomTheme.Colors.inkMedium
    }
    
    // MARK: - Main Tube View (Phase 1)
    
    private func mainTubeView(tubeWidth: CGFloat, tubeHeight: CGFloat) -> some View {
        let clampedFill = min(1, max(0, viewModel.potential))
        
        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(KingdomTheme.Colors.parchmentDark)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(KingdomTheme.Colors.royalBlue)
                    .frame(height: max(4, tubeHeight * clampedFill))
                    .overlay(
                        LinearGradient(
                            colors: [KingdomTheme.Colors.parchmentHighlight.opacity(0.25), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .animation(.easeOut(duration: 0.6), value: clampedFill)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 3)
            }
            .frame(width: tubeWidth, height: tubeHeight)

            Text("potential")
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
                    
                case .preparation:
                    if viewModel.isPhase1Complete {
                        Button {
                            viewModel.transitionToSynthesis()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("BEGIN SYNTHESIS")
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
                                await doPreparationInfusionWithAnimation()
                            }
                        } label: {
                            Text(isAnimating ? "..." : "INFUSE")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isAnimating ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.royalBlue)
                                .cornerRadius(8)
                        }
                        .disabled(isAnimating)
                    }
                    
                case .synthesis:
                    if viewModel.isSynthesisComplete {
                        // Ready for final infusion
                        Button {
                            viewModel.transitionToFinalInfusion()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("FINAL SYNTHESIS")
                            }
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KingdomTheme.Colors.gold)
                            .cornerRadius(8)
                        }
                    } else {
                        Button {
                            Task {
                                await doSynthesisInfusionWithAnimation()
                            }
                        } label: {
                            Text(isAnimating ? "..." : "INFUSE (\(viewModel.remainingSynthesisInfusions + 1) left)")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isAnimating ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.regalPurple)
                                .cornerRadius(8)
                        }
                        .disabled(isAnimating)
                    }
                    
                case .finalInfusion:
                    if showingFinalReveal {
                        // Done - show try again
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
                                await doFinalInfusionWithAnimation()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text(isAnimating ? "..." : "COMPLETE SYNTHESIS")
                            }
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isAnimating ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.gold)
                            .cornerRadius(8)
                        }
                        .disabled(isAnimating)
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
    
    private func animateValue(to finalValue: Int) async {
        isAnimating = true
        
        let clampedFinal = min(100, max(1, finalValue))
        
        var positions: [Int] = []
        positions.append(contentsOf: stride(from: 1, through: 100, by: 3))
        
        if clampedFinal < 100 {
            positions.append(contentsOf: stride(from: 100, through: max(1, clampedFinal), by: -3))
        }
        if positions.last != clampedFinal {
            positions.append(clampedFinal)
        }
        
        for (i, pos) in positions.enumerated() {
            displayValue = pos
            let sleepNs: UInt64 = (i > positions.count - 8) ? 30_000_000 : 18_000_000
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        
        displayValue = clampedFinal
        isAnimating = false
    }
    
    @MainActor
    private func doPreparationInfusionWithAnimation() async {
        guard !isAnimating else { return }
        guard viewModel.uiState == .preparation, let reagent = viewModel.currentReagent else { return }

        if viewModel.showAmountSelect {
            viewModel.doNextPreparationInfusion()
            try? await Task.sleep(nanoseconds: 600_000_000)
            return
        }

        let nextIdx = viewModel.currentInfusionIndex + 1
        if nextIdx < reagent.infusions.count {
            await animateValue(to: reagent.infusions[nextIdx].value)
            await Task.yield()
            viewModel.doNextPreparationInfusion()
        } else {
            let fillPct = max(1, Int(reagent.finalFill * 100))
            await animateAmountSelection(maxValue: fillPct, finalValue: reagent.amountSelected)
            await Task.yield()
            viewModel.doNextPreparationInfusion()
        }
    }
    
    @MainActor
    private func animateAmountSelection(maxValue: Int, finalValue: Int) async {
        isAnimating = true
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
            displayValue = pos
            let sleepNs: UInt64 = (i > positions.count - 8) ? 50_000_000 : 25_000_000
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        
        barMarkerValue = clampedFinal
        displayValue = clampedFinal
        isAnimating = false
    }
    
    // MARK: - Synthesis Infusion Animation
    
    @MainActor
    private func doSynthesisInfusionWithAnimation() async {
        guard !isAnimating else { return }
        guard viewModel.uiState == .synthesis else { return }
        
        let nextIdx = viewModel.currentSynthesisIndex + 1
        guard nextIdx < viewModel.synthesisInfusions.count else { return }
        
        let infusion = viewModel.synthesisInfusions[nextIdx]
        
        // Regular infusion - just animate number
        await animateValue(to: infusion.value)
        
        try? await Task.sleep(nanoseconds: 150_000_000)
        
        viewModel.doNextSynthesisInfusion()
        
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    // MARK: - Final Infusion Animation
    
    @MainActor
    private func doFinalInfusionWithAnimation() async {
        guard !isAnimating else { return }
        guard viewModel.uiState == .finalInfusion else { return }
        guard let final = viewModel.finalInfusionResult else { return }
        
        // Clamp all values to 0-1 range
        let currentPurity = min(1.0, max(0, viewModel.purity))
        let potential = min(1.0, max(0, viewModel.potential))
        
        // Ensure we have a valid range (purity should be <= potential)
        let minPos = min(currentPurity, potential)
        let maxPos = max(currentPurity, potential)
        
        isAnimating = true
        showFinalMarker = true
        
        // Slow dramatic bounce between PURITY and POTENTIAL
        let totalBounces = 12
        for i in 0..<totalBounces {
            let randomPos = CGFloat.random(in: minPos...maxPos)
            withAnimation(.easeInOut(duration: 0.15)) {
                synthesisMarkerPosition = min(1.0, max(0, randomPos))
            }
            displayValue = Int.random(in: Int(minPos * 100)...Int(maxPos * 100))
            // Slow down as we approach the end
            let delay: UInt64 = i < totalBounces - 3 ? 150_000_000 : 250_000_000
            try? await Task.sleep(nanoseconds: delay)
        }
        
        // Land on final purity value with dramatic pause (clamped to 0-1)
        let finalPurityFrac = min(1.0, max(0, CGFloat(final.purityAfter) / 100.0))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            synthesisMarkerPosition = finalPurityFrac
        }
        displayValue = min(100, max(0, final.purityAfter))
        
        // Hold so user can see where it landed
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        isAnimating = false
        showFinalMarker = false
        
        // Apply the final infusion result - stay on this screen, don't switch!
        viewModel.applyFinalInfusion()
        
        // Show the reveal after a moment
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showingFinalReveal = true
        }
        
        // DON'T transition to result - stay here so user can see what happened
    }
    
    // MARK: - Helpers
    
    private func colorForPurity(_ purity: Int) -> Color {
        if let tier = viewModel.tierForPurity(purity) {
            return colorForTierId(tier.id)
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private var synthesisValueColor: Color {
        if isAnimating {
            return KingdomTheme.Colors.regalPurple
        }
        if viewModel.uiState == .finalInfusion {
            return KingdomTheme.Colors.gold
        }
        if let inf = viewModel.currentSynthesisInfusion {
            return inf.stable ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
        }
        return KingdomTheme.Colors.inkLight
    }
    
    private func colorForTierId(_ tierId: String) -> Color {
        switch tierId {
        case "eureka": return KingdomTheme.Colors.gold
        case "stable": return KingdomTheme.Colors.buttonSuccess
        case "unstable": return KingdomTheme.Colors.inkMedium
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

// MARK: - Crystal Growth Overlay

private struct CrystalGrowthOverlay: View {
    let purity: CGFloat
    let hitCount: Int
    let tubeWidth: CGFloat
    let tubeHeight: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if hitCount > 0 {
                    DiamondGridOverlay(hitCount: hitCount)
                        .frame(width: tubeWidth, height: tubeHeight * purity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: purity)
        .animation(.easeInOut(duration: 0.3), value: hitCount)
    }
}

private struct DiamondGridOverlay: View {
    let hitCount: Int
    
    private var gridOpacity: Double {
        min(0.95, 0.25 + Double(hitCount) * 0.18)
    }
    
    private var lineWidth: CGFloat {
        min(3.0, 1.0 + CGFloat(hitCount) * 0.25)
    }
    
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 12
            
            var path = Path()
            
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            
            x = 0
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x - size.height, y: 0))
                x += spacing
            }
            
            context.stroke(
                path,
                with: .color(Color(red: 0.5, green: 0.2, blue: 0.8).opacity(gridOpacity)),
                lineWidth: lineWidth
            )
        }
    }
}

// MARK: - Card Components

private struct InfusionCard: View {
    let infusion: Infusion
    let index: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: 2, y: 2)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(infusion.stable ? KingdomTheme.Colors.parchmentHighlight : KingdomTheme.Colors.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(infusion.stable ? KingdomTheme.Colors.buttonSuccess : Color.black, lineWidth: 2)
                )
            
            Text("\(infusion.value)")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(infusion.stable ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
        }
        .frame(width: 44, height: 44)
    }
}

private struct AmountSelectCard: View {
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

private struct SynthesisInfusionCard: View {
    let infusion: SynthesisInfusion
    let index: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: 2, y: 2)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(infusion.stable ? KingdomTheme.Colors.parchmentHighlight : KingdomTheme.Colors.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(infusion.stable ? KingdomTheme.Colors.regalPurple : Color.black, lineWidth: 2)
                )
            
            VStack(spacing: 1) {
                Text("\(infusion.value)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(infusion.stable ? KingdomTheme.Colors.regalPurple : KingdomTheme.Colors.inkMedium)
                if infusion.stable {
                    Text("+\(infusion.purityGained)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
        }
        .frame(width: 44, height: 44)
    }
}

private struct FinalInfusionCard: View {
    let infusion: SynthesisInfusion
    
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
            
            VStack(spacing: 1) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text("+\(infusion.purityGained)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
        }
        .frame(width: 44, height: 44)
    }
}

#Preview {
    NavigationStack {
        ResearchView(apiClient: APIClient.shared)
    }
}
