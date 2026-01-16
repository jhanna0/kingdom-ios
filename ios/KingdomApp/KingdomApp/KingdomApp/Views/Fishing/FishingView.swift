import SwiftUI

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
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topSection
                Spacer()
                fishingArea
                Spacer()
                bottomSection
            }
            
            if showPetFishCelebration {
                petFishCelebrationOverlay
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.startSession()
        }
        .onChange(of: viewModel.petFishDropped) { _, newValue in
            if newValue && !lastPetFishState {
                triggerPetFishCelebration()
            }
            lastPetFishState = newValue
        }
    }
    
    // MARK: - Top Section
    
    private var topSection: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "figure.fishing")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    
                    Text("FISHING")
                        .font(.system(size: 18, weight: .black, design: .serif))
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
                        .font(.system(size: 16, weight: .bold))
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
                .fill(Color.black)
                .frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
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
            ZStack {
                Circle()
                    .fill(viewModel.phaseColor.opacity(0.12))
                
                Circle()
                    .stroke(viewModel.phaseColor, lineWidth: 3)
                
                bobberContent(size: size)
            }
            .frame(width: size, height: size)
            
            // Keep space but hide content for loot phases - not skill based
            VStack(spacing: 4) {
                Text(viewModel.currentStatName)
                    .font(.system(size: 11, weight: .bold, design: .serif))
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
                    
                    Text(roll.is_critical ? "CRIT!" : (roll.is_success ? "HIT" : "MISS"))
                        .font(.system(size: subFont, weight: .black))
                        .foregroundColor(rollColor)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(viewModel.phaseColor)
            }
        } else if viewModel.uiState == .masterRollAnimation || masterRollAnimationStarted {
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
                Text("...")
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
                Text("ESCAPED")
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
                .font(.system(size: 11, weight: .bold, design: .serif))
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
                    masterRollAnimationStarted = false
                }
            }
            .onChange(of: viewModel.masterRollValue) { _, newValue in
                if newValue == 0 {
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
        guard finalValue > 0 else { return }
        
        var positions = Array(stride(from: 1, through: 100, by: 3))
        if finalValue < 100 {
            positions.append(contentsOf: stride(from: 97, through: max(1, finalValue), by: -3))
        }
        if positions.last != finalValue {
            positions.append(finalValue)
        }
        
        showMasterRollMarker = true
        
        for pos in positions {
            masterRollDisplayValue = pos
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        
        masterRollDisplayValue = finalValue
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
                Text("No rolls yet")
                    .font(.system(size: 13, weight: .medium, design: .serif))
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
                        Task { await viewModel.cast() }
                    } label: {
                        HStack {
                            Image(systemName: "water.waves")
                            Text("Cast")
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
                        Task { await viewModel.reel() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Reel In!")
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
                        Text(viewModel.uiState == .casting ? "Casting..." : "Reeling in...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                case .caught:
                    Button {
                        viewModel.loot()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Loot!")
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
                        Text("Rolling...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                case .lootResult:
                    Button {
                        viewModel.collect()
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Collect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.gold,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    
                case .escaped:
                    Text("It got away...")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                case .error(let message):
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
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
