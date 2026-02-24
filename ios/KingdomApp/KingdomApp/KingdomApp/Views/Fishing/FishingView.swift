import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Fishing View
// Single-screen, chill fishing minigame

struct FishingView: View {
    @StateObject private var viewModel = FishingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    // Master roll animation state
    @State private var masterRollDisplayValue: Int = 0
    @State private var showMasterRollMarker: Bool = false
    @State private var masterRollAnimationStarted: Bool = false
    
    // Pet fish celebration
    @State private var showPetFishCelebration: Bool = false
    @State private var lastPetFishState: Bool = false
    
    // Shift glow effect
    @State private var showBarShiftGlow: Bool = false
    
    // Flavor + juice
    @State private var bobberJiggle: Bool = false
    @State private var statusPulse: Bool = false
    @State private var lastState: FishingViewModel.UIState? = nil
    @State private var lastRolledIndex: Int = -999
    
    // Streak bonus popup - controlled by backend, not local state
    @State private var showStreakPopup: Bool = false
    
    var body: some View {
        ZStack {
            fishingBackdrop
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topSection
                    .padding(.bottom, KingdomTheme.Spacing.medium)
                Spacer()
                
                statusCard
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                    .padding(.bottom, KingdomTheme.Spacing.medium)
                
                fishingArea
                Spacer()
                bottomSection
            }
            
            if showPetFishCelebration {
                petFishCelebrationOverlay
            }
            
            if showStreakPopup, let streakInfo = viewModel.currentStreakInfo {
                StreakBonusPopup(
                    title: streakInfo.title,
                    subtitle: streakInfo.subtitle,
                    description: streakInfo.description,
                    multiplier: streakInfo.multiplier,
                    icon: streakInfo.icon,
                    color: streakInfo.color,
                    dismissButton: streakInfo.dismiss_button
                ) {
                    showStreakPopup = false
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.startSession()
            lastState = viewModel.uiState
        }
        .onChange(of: viewModel.petFishDropped) { _, newValue in
            if newValue && !lastPetFishState {
                triggerPetFishCelebration()
            }
            lastPetFishState = newValue
        }
        .onChange(of: viewModel.uiState) { _, newState in
            handleStateChange(newState)
        }
        .onChange(of: viewModel.currentRollIndex) { _, newIndex in
            guard newIndex != lastRolledIndex else { return }
            lastRolledIndex = newIndex
            handleRollBeat(index: newIndex)
        }
        .onChange(of: viewModel.shouldShowStreakPopup) { _, shouldShow in
            // Backend tells us exactly when to show the popup
            if shouldShow {
                showStreakPopup = true
            }
        }
    }
    
    // MARK: - Backdrop
    
    private var fishingBackdrop: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
            
            // Subtle “water” wash so the whole screen feels alive.
            LinearGradient(
                colors: [
                    KingdomTheme.Colors.territoryNeutral7.opacity(0.22),
                    KingdomTheme.Colors.parchmentDark.opacity(0.0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            
            // Gentle rings (very low opacity) — keeps it from feeling flat.
            ZStack {
                Circle()
                    .stroke(KingdomTheme.Colors.territoryNeutral7.opacity(0.10), lineWidth: 2)
                    .frame(width: 260, height: 260)
                    .offset(x: 120, y: -220)
                
                Circle()
                    .stroke(KingdomTheme.Colors.royalBlue.opacity(0.08), lineWidth: 2)
                    .frame(width: 340, height: 340)
                    .offset(x: -140, y: 260)
            }
        }
    }
    
    // MARK: - Top Section
    
    private var topSection: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "figure.fishing")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    
                    Text("FISHING")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.endSession()
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            
            CatchBox(
                meatCount: viewModel.totalMeat,
                fishCaught: viewModel.fishCaught,
                petFishDropped: viewModel.petFishDropped
            )
            
            Rectangle()
                .fill(headerAccentColor)
                .frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    private var headerAccentColor: Color {
        switch viewModel.uiState {
        case .fishFound, .caught, .looting, .lootResult:
            return KingdomTheme.Colors.gold
        case .escaped:
            return KingdomTheme.Colors.inkMedium
        case .error:
            return KingdomTheme.Colors.buttonDanger
        default:
            return Color.black
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                Image(systemName: statusIcon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(statusTint)
                    .scaleEffect(statusPulse ? 1.06 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.55), value: statusPulse)
            }
            .frame(width: 46, height: 46)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(statusTitle)
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(statusLine)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(statusRightStat)
                    .font(FontStyles.statMedium)
                    .foregroundColor(statusTint)
                
                Text(statusRightLabel)
                    .font(FontStyles.captionLarge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(width: 96, alignment: .trailing)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 16)
    }
    
    private var statusIcon: String {
        switch viewModel.uiState {
        case .loading: return "hourglass"
        case .idle: return "water.waves"
        case .casting: return "water.waves"
        case .fishFound: return "fish.fill"
        case .reeling: return "arrow.up.circle.fill"
        case .caught: return "checkmark.circle.fill"
        case .looting, .lootResult: return "sparkles"
        case .escaped: return "arrow.uturn.backward.circle.fill"
        case .masterRollAnimation: return "scope"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusTint: Color {
        switch viewModel.uiState {
        case .fishFound, .caught, .looting, .lootResult:
            return KingdomTheme.Colors.gold
        case .escaped, .error:
            return KingdomTheme.Colors.buttonDanger
        default:
            return KingdomTheme.Colors.royalBlue
        }
    }
    
    private var statusTitle: String {
        switch viewModel.uiState {
        case .loading: return "SHORE UP"
        case .idle: return "CAST"
        case .casting: return "CASTING"
        case .fishFound: return "A BITE!"
        case .reeling: return "REEL"
        case .caught: return "LANDED"
        case .looting: return "SPOILS"
        case .lootResult: return "CLAIMED"
        case .escaped: return "SLIPPED"
        case .masterRollAnimation: return "DRUMROLL"
        case .error: return "TROUBLE"
        }
    }
    
    private var statusLine: String {
        switch viewModel.uiState {
        case .loading:
            return "Wading in..."
        case .idle:
            return "Cast. Then wait."
        case .casting:
            return "Watching the line..."
        case .fishFound:
            if let fish = viewModel.currentFishData {
                return "\(fish.icon ?? "🐟") \(fish.name ?? "Something") — set the hook!"
            }
            return "A bite — set the hook!"
        case .reeling:
            return "Keep tension. Reel!"
        case .caught:
            if let fish = viewModel.currentFishData {
                return "\(fish.icon ?? "🐟") \(fish.name ?? "Catch") landed."
            }
            return "Landed."
        case .looting:
            return "Taking your cut..."
        case .lootResult:
            if viewModel.currentLootResult?.rare_loot_dropped == true {
                return "Rare find!"
            }
            return "Collected."
        case .escaped:
            return "It slipped."
        case .masterRollAnimation:
            return "..."
        case .error(let msg):
            return msg
        }
    }
    
    private var statusRightLabel: String {
        if viewModel.currentBarType == .loot { return "loot" }
        switch viewModel.currentBarType {
        case .cast: return "bite"
        case .reel: return "land"
        case .loot: return "loot"
        }
    }
    
    private var statusRightStat: String {
        if viewModel.currentBarType == .loot {
            if let loot = viewModel.currentLootResult {
                return loot.rare_loot_dropped ? "✨" : "+\(loot.meat_earned)"
            }
            return "—"
        }
        return "\(viewModel.mainOutcomePercentage)%"
    }
    
    // Intentionally no long “flavor text” paragraphs here — keep it punchy like the rest of the app.
    
    // MARK: - Fishing Area
    
    private var fishingArea: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let bobberSize = min(availableHeight * 0.45, 200)
            let barHeight = min(availableHeight * 0.65, 280)
            let barWidth = barHeight * 0.28
            
            HStack(alignment: .center, spacing: 28) {
                bobberDisplay(size: bobberSize)
                probabilityBar(width: barWidth, height: barHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, KingdomTheme.Spacing.large)
    }
    
    // MARK: - Bobber Display
    
    private func bobberDisplay(size: CGFloat) -> some View {
        VStack(spacing: 12) {
            let face = ZStack {
                Circle()
                    .fill(viewModel.phaseColor.opacity(0.12))
                
                Circle()
                    .stroke(viewModel.phaseColor, lineWidth: 3)
                
                bobberContent(size: size)
            }
            .frame(width: size, height: size)
            
            if bobberJiggle {
                // NOTE: Avoid `repeatForever` here — it can “stick” and jitter forever.
                TimelineView(.animation) { context in
                    face
                        .rotationEffect(.degrees(biteJiggleAngle(at: context.date)))
                }
            } else {
                face
            }
            
            // Keep space but hide content for loot phases - not skill based
            VStack(spacing: 4) {
                Text(viewModel.currentStatName)
                    .font(FontStyles.captionMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                rollCountIndicator
            }
            .opacity(viewModel.session != nil && viewModel.uiState != .caught && viewModel.uiState != .looting && viewModel.uiState != .lootResult ? 1 : 0)
        }
        .frame(width: size)
    }
    
    @ViewBuilder
    private func bobberContent(size: CGFloat) -> some View {
        let mainFont = size * 0.32
        let subFont = size * 0.09
        let iconFont = size * 0.35
        
        let hitColor = KingdomTheme.Colors.royalBlue
        let critColor = KingdomTheme.Colors.gold
        let missColor = KingdomTheme.Colors.inkMedium
        
        if viewModel.isAnimatingRolls {
            if let roll = viewModel.currentRoll {
                let rollColor = roll.is_critical ? critColor : (roll.is_success ? hitColor : missColor)
                VStack(spacing: 4) {
                    Text("\(roll.roll)")
                        .font(.system(size: mainFont, weight: .black, design: .monospaced))
                        .foregroundColor(rollColor)
                    
                    Text(roll.is_critical ? "HOOK SET!" : (roll.is_success ? "A BITE!" : "DRIFT..."))
                        .font(.system(size: subFont, weight: .black))
                        .foregroundColor(rollColor)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(viewModel.phaseColor)
            }
        } else if viewModel.shouldAnimateMasterRoll || viewModel.uiState == .masterRollAnimation {
            Text("\(masterRollDisplayValue)")
                .font(.system(size: mainFont, weight: .black, design: .monospaced))
                .foregroundColor(viewModel.phaseColor)
        } else if viewModel.uiState == .fishFound, let fish = viewModel.currentFishData {
            VStack(spacing: 4) {
                Text(fish.icon ?? "🐟")
                    .font(.system(size: iconFont))
                Text(fish.name ?? "Fish")
                    .font(.system(size: subFont, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        } else if viewModel.uiState == .caught {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: mainFont, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text("CAUGHT!")
                    .font(.system(size: subFont * 1.2, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
        } else if viewModel.uiState == .looting {
            VStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(KingdomTheme.Colors.gold)
                Text("Rummaging...")
                    .font(.system(size: subFont * 1.2, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        } else if viewModel.uiState == .lootResult {
            VStack(spacing: 4) {
                if let loot = viewModel.currentLootResult {
                    if loot.rare_loot_dropped {
                        Image(systemName: "sparkles")
                            .font(.system(size: mainFont, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text(loot.rare_loot_name ?? "RARE!")
                            .font(.system(size: subFont * 1.2, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.gold)
                    } else {
                        Image(systemName: "flame.fill")
                            .font(.system(size: mainFont, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text("+\(loot.meat_earned)")
                            .font(.system(size: subFont * 1.5, weight: .black, design: .monospaced))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
            }
        } else if viewModel.uiState == .escaped {
            VStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: mainFont, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("SLIPPED")
                    .font(.system(size: subFont * 1.2, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "water.waves")
                    .font(.system(size: iconFont * 0.8, weight: .bold))
                    .foregroundColor(viewModel.phaseColor)
                
                Text("\(viewModel.hitChance)%")
                    .font(.system(size: subFont * 1.3, weight: .bold, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
    }
    
    private func biteJiggleAngle(at date: Date) -> Double {
        // Snappy wobble for “A BITE!” — subtle enough to not smear text.
        let t = date.timeIntervalSinceReferenceDate
        let period = 0.22
        let phase = (t / period) * (2.0 * Double.pi)
        let normalized = sin(phase) // -1...1
        return 2.2 * normalized
    }
    
    // MARK: - Roll Count Indicator
    
    private var rollCountIndicator: some View {
        let maxRolls = viewModel.currentRollCount
        let completed = max(0, viewModel.currentRollIndex + 1)
        let isAnimating = viewModel.isAnimatingRolls
        
        return HStack(spacing: 5) {
            ForEach(0..<maxRolls, id: \.self) { i in
                Circle()
                    .fill(
                        i < completed
                            ? viewModel.phaseColor
                            : (isAnimating ? Color.black.opacity(0.2) : viewModel.phaseColor.opacity(0.3))
                    )
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: completed)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 6,
            borderWidth: 2
        )
    }
    
    // MARK: - Probability Bar
    
    private func probabilityBar(width: CGFloat, height: CGFloat) -> some View {
        let barTitle = viewModel.currentBarTitle
        let markerIcon = viewModel.currentMarkerIcon
        
        return VStack(spacing: 8) {
            Text(showBarShiftGlow ? "NICE!" : barTitle)
                .font(FontStyles.captionMedium)
                .foregroundColor(showBarShiftGlow ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium)
                .frame(height: 16)
            
            // Same bar for all phases - just different data
            VerticalRollBar(
                items: viewModel.currentDropTableDisplay,
                slots: viewModel.currentSlots,
                markerValue: masterRollDisplayValue,
                showMarker: showMasterRollMarker,
                markerIcon: markerIcon
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KingdomTheme.Colors.gold, lineWidth: 3)
                    .opacity(showBarShiftGlow ? 0.8 : 0)
                    .blur(radius: showBarShiftGlow ? 3 : 0)
            )
            .onChange(of: viewModel.shouldAnimateMasterRoll) { _, shouldAnimate in
                if shouldAnimate && !masterRollAnimationStarted {
                    masterRollAnimationStarted = true
                    Task { await runMasterRollAnimation() }
                } else if !shouldAnimate {
                    // Only reset the "started" flag - marker stays visible until masterRollValue is cleared
                    masterRollAnimationStarted = false
                }
            }
            .onChange(of: viewModel.masterRollValue) { _, newValue in
                if newValue == 0 {
                    // Reset display state when master roll value is cleared (phase transition)
                    showMasterRollMarker = false
                    masterRollDisplayValue = 0
                    masterRollAnimationStarted = false
                }
            }
            .onChange(of: viewModel.currentRollIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < viewModel.currentRolls.count {
                    let roll = viewModel.currentRolls[newIndex]
                    if roll.is_success {
                        triggerBarShiftGlow()
                    }
                }
            }
            
            // Show percentage for cast/reel, loot result for loot
            if viewModel.currentBarType == .loot {
                if let loot = viewModel.currentLootResult {
                    Text(loot.rare_loot_dropped ? "✨" : "+\(loot.meat_earned)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            } else {
                Text("\(viewModel.mainOutcomePercentage)%")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
        .frame(width: max(width, 60))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentBarType)
    }
    
    private func triggerBarShiftGlow() {
        showBarShiftGlow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showBarShiftGlow = false
        }
    }
    
    @MainActor
    private func runMasterRollAnimation() async {
        let finalValue = viewModel.masterRollValue
        guard finalValue > 0 else {
            // Early exit - still need to clean up animation state
            masterRollAnimationStarted = false
            return
        }
        
        let clampedFinal = min(max(finalValue, 1), 100)
        
        var positions = Array(stride(from: 1, through: 100, by: 3))
        if clampedFinal < 100 {
            positions.append(contentsOf: stride(from: 97, through: max(1, clampedFinal), by: -3))
        }
        if positions.last != finalValue {
            positions.append(clampedFinal)
        }
        
        showMasterRollMarker = true
        
        for pos in positions {
            // Check if animation was cancelled (shouldAnimateMasterRoll turned off)
            guard viewModel.shouldAnimateMasterRoll else {
                masterRollAnimationStarted = false
                return
            }
            masterRollDisplayValue = pos
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        
        masterRollDisplayValue = clampedFinal
        viewModel.onMasterRollAnimationComplete()
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 0) {
            rollHistoryCard
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.bottom, KingdomTheme.Spacing.medium)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            actionButton
        }
    }
    
    // MARK: - Roll History Card
    
    private var rollHistoryCard: some View {
        ZStack {
            if viewModel.currentRolls.isEmpty {
                Text("Cast, then wait for the bite.")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.currentRolls.enumerated()), id: \.offset) { index, roll in
                            if index <= viewModel.currentRollIndex {
                                FishingRollCard(roll: roll, index: index + 1)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        VStack(spacing: 0) {
            ZStack {
                switch viewModel.uiState {
                case .loading:
                    ProgressView()
                        .tint(KingdomTheme.Colors.royalBlue)
                    
                case .idle:
                    Button {
                        hapticImpact(.medium)
                        Task { await viewModel.cast() }
                    } label: {
                        HStack {
                            Image(systemName: "water.waves")
                            Text("Cast the Line")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.royalBlue,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    
                case .fishFound:
                    Button {
                        hapticImpact(.heavy)
                        Task { await viewModel.reel() }
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Set the Hook!")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.gold,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    
                case .casting, .reeling, .masterRollAnimation:
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.1)
                            .tint(viewModel.phaseColor)
                        Text(actionProgressLine)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                case .caught:
                    Button {
                        viewModel.loot()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Dress the Catch")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.gold,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    
                case .looting:
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.1)
                            .tint(KingdomTheme.Colors.gold)
                        Text("Carving up the spoils...")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                case .lootResult:
                    Button {
                        viewModel.collect()
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Stow the Spoils")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.gold,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    
                case .escaped:
                    Text("It slipped the hook...")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                case .error(let message):
                    Text(message)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Pet Fish Celebration
    
    private var petFishCelebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showPetFishCelebration = false
                    }
                }
            
            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .offset(
                                x: CGFloat.random(in: -60...60),
                                y: CGFloat.random(in: -60...60)
                            )
                            .opacity(0.8)
                    }
                    
                    Image(systemName: "fish.circle.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.9, blue: 0.9),
                                    Color(red: 0.0, green: 0.6, blue: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: KingdomTheme.Colors.gold.opacity(0.6), radius: 12)
                }
                
                Text("PET FISH!")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("A rare companion has joined you!")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showPetFishCelebration = false
                    }
                } label: {
                    Text("Amazing!")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: KingdomTheme.Colors.gold,
                    foregroundColor: .white,
                    fullWidth: true
                ))
            }
            .padding(28)
            .frame(maxWidth: 300)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 20)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
    
    private func triggerPetFishCelebration() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showPetFishCelebration = true
        }
    }
    
    private var actionProgressLine: String {
        switch viewModel.uiState {
        case .casting:
            return "Casting... eyes on the water."
        case .reeling:
            return "Reeling... don’t let it run."
        case .masterRollAnimation:
            return "Holding..."
        default:
            return "..."
        }
    }
    
    // MARK: - Haptics + Beats
    
    private func handleStateChange(_ newState: FishingViewModel.UIState) {
        // Bite jiggle loop
        switch newState {
        case .fishFound:
            bobberJiggle = true
        default:
            bobberJiggle = false
        }
        
        // One-shot beats
        if lastState != newState {
            switch newState {
            case .fishFound:
                // Big fish (tier 3+) = shake the phone off the table
                // Small fish = just a tap
                let tier = viewModel.currentFishData?.tier ?? 0
                if tier >= 3 {
                    biteHapticBurst()
                } else if tier >= 2 {
                    haptic(.success)
                    hapticImpact(.heavy)
                } else {
                    hapticImpact(.medium)
                }
                pulseStatusIcon()
                
            case .caught:
                haptic(.success)
                hapticImpact(.medium)
                pulseStatusIcon()
                
            case .escaped:
                haptic(.warning)
                hapticImpact(.light)
                pulseStatusIcon()
                
            case .lootResult:
                if viewModel.currentLootResult?.rare_loot_dropped == true {
                    // RARE DROP - go crazy
                    biteHapticBurst()
                } else {
                    hapticImpact(.light)
                }
                pulseStatusIcon()
                
            case .idle:
                // Coming back to idle after a miss/escape: keep it subtle.
                hapticImpact(.light)
                
            default:
                break
            }
        }
        
        lastState = newState
    }
    
    private func handleRollBeat(index: Int) {
        guard index >= 0, index < viewModel.currentRolls.count else { return }
        let roll = viewModel.currentRolls[index]
        
        // Light “clicks” per roll, heavier on criticals.
        if roll.is_critical && roll.is_success {
            hapticImpact(.heavy)
            pulseStatusIcon()
        } else if roll.is_success {
            hapticImpact(.light)
        } else if roll.is_critical {
            hapticImpact(.medium)
        }
    }
    
    private func pulseStatusIcon() {
        statusPulse.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            statusPulse.toggle()
        }
    }
    
    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        HapticService.shared.notification(type)
    }
    
    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        HapticService.shared.impact(style)
    }
    
    /// Rapid-fire burst of heavy haptics for the BITE moment
    private func biteHapticBurst() {
        guard HapticService.shared.isHapticsEnabled else { return }
        #if canImport(UIKit)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        heavy.prepare()
        rigid.prepare()
        
        // Initial slam
        haptic(.success)
        heavy.impactOccurred(intensity: 1.0)
        
        // Rapid follow-up hits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            rigid.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            heavy.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            rigid.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            heavy.impactOccurred(intensity: 0.9)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            rigid.impactOccurred(intensity: 0.7)
        }
        #endif
    }
}

// MARK: - Fishing Roll Card

struct FishingRollCard: View {
    let roll: FishingRollResult
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
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(textColor)
        }
        .frame(width: 48, height: 48)
    }
    
    private var cardBackground: Color {
        if roll.is_critical && roll.is_success {
            return Color(red: 0.95, green: 0.88, blue: 0.65)
        } else if roll.is_success {
            return Color(red: 0.85, green: 0.90, blue: 0.95)
        } else if roll.is_critical {
            return Color(red: 0.95, green: 0.88, blue: 0.65)
        } else {
            return KingdomTheme.Colors.parchment
        }
    }
    
    private var cardBorder: Color {
        if roll.is_critical {
            return KingdomTheme.Colors.gold
        } else if roll.is_success {
            return KingdomTheme.Colors.royalBlue
        }
        return Color.black
    }
    
    private var textColor: Color {
        if roll.is_critical {
            return KingdomTheme.Colors.gold
        } else if roll.is_success {
            return KingdomTheme.Colors.royalBlue
        } else {
            return KingdomTheme.Colors.inkMedium
        }
    }
}

#Preview {
    NavigationStack {
        Text("Fishing View Preview")
            .font(.title)
    }
}
