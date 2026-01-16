import SwiftUI

// MARK: - Fishing View
// Single-screen, chill fishing minigame
// Layout: Catch box at top, bobber + vertical bar in center, action button at bottom

struct FishingView: View {
    @StateObject private var viewModel = FishingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Injected API client
    let apiClient: APIClient
    
    // Local master roll animation state (like hunting)
    @State private var masterRollDisplayValue: Int = 0
    @State private var showMasterRollMarker: Bool = false
    @State private var masterRollAnimationStarted: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with catch box and done button
                topBar
                
                // Main fishing area
                fishingArea
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                
                Spacer()
                
                // Bottom action button
                bottomButton
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.startSession()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                // Title
                HStack(spacing: 8) {
                    Image(systemName: "figure.fishing")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    
                    Text("FISHING")
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                // Done button
                Button {
                    Task {
                        await viewModel.endSession()
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            
            // Catch box
            CatchBox(
                meatCount: viewModel.totalMeat,
                fishCaught: viewModel.fishCaught,
                petFishDropped: viewModel.petFishDropped
            )
            
            // Divider
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Fishing Area
    
    private var fishingArea: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: KingdomTheme.Spacing.large) {
                // Left side: Bobber display
                bobberDisplay
                
                // Right side: Vertical probability bar
                probabilityBar
            }
            
            // Roll history (like hunting)
            rollHistoryCard
        }
        .padding(.top, KingdomTheme.Spacing.large)
    }
    
    // MARK: - Roll History Card
    
    private var rollHistoryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ROLLS")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal, 10)
            
            ZStack {
                if viewModel.currentRolls.isEmpty {
                    Text("No rolls yet")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.currentRolls.enumerated()), id: \.offset) { index, roll in
                                // Only show rolls that have been revealed
                                if index <= viewModel.currentRollIndex {
                                    FishingRollCard(roll: roll, index: index + 1)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentRollIndex)
                    }
                }
            }
            .frame(height: 60)
        }
        .frame(height: 90)  // FIXED HEIGHT including title
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
    }
    
    // MARK: - Bobber Display
    
    private var bobberDisplay: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Status message - FIXED HEIGHT
            Text(viewModel.statusMessage)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
            
            // Bobber / Roll value
            ZStack {
                // Bobber circle background
                Circle()
                    .fill(viewModel.phaseColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .stroke(viewModel.phaseColor, lineWidth: 4)
                    .frame(width: 140, height: 140)
                
                // Content based on state
                if viewModel.isAnimatingRolls {
                    if let roll = viewModel.currentRoll {
                        // Show roll value
                        VStack(spacing: 4) {
                            Text("\(roll.roll)")
                                .font(.system(size: 48, weight: .black, design: .monospaced))
                                .foregroundColor(roll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
                            
                            // Success/fail indicator
                            HStack(spacing: 4) {
                                Image(systemName: roll.is_success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(roll.is_critical ? "CRIT!" : (roll.is_success ? "HIT" : "MISS"))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(roll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Waiting for first roll
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(viewModel.phaseColor)
                            Text("Rolling...")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                } else if viewModel.uiState == .masterRollAnimation || masterRollAnimationStarted {
                    // Master roll value - use local animated display value
                    Text("\(masterRollDisplayValue)")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(viewModel.phaseColor)
                } else if viewModel.uiState == .fishFound, let fish = viewModel.currentFishData {
                    // Fish icon
                    VStack(spacing: 4) {
                        Text(fish.icon ?? "🐟")
                            .font(.system(size: 48))
                        Text(fish.name ?? "Fish")
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                } else if viewModel.uiState == .caught {
                    // Celebration
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        Text("CAUGHT!")
                            .font(.system(size: 14, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                } else if viewModel.uiState == .escaped {
                    // Escaped
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        Text("ESCAPED")
                            .font(.system(size: 14, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                } else {
                    // Idle - show bobber icon
                    VStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(viewModel.phaseColor)
                        
                        Text("\(viewModel.hitChance)%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            
            // Roll count indicator - always show placeholder to maintain height
            rollCountIndicator
                .opacity(viewModel.session != nil ? 1 : 0)
        }
        .frame(width: 160, height: 280)  // FIXED SIZE
    }
    
    // MARK: - Roll Count Indicator
    
    private var rollCountIndicator: some View {
        let maxRolls = viewModel.uiState == .reeling || viewModel.uiState == .fishFound 
            ? viewModel.reelRolls 
            : viewModel.castRolls
        // Handle index -1 (no roll shown yet) = 0 completed
        let completed = max(0, viewModel.currentRollIndex + 1)
        let isAnimating = viewModel.isAnimatingRolls
        
        return VStack(spacing: 4) {
            Text(viewModel.uiState == .reeling || viewModel.uiState == .fishFound ? "DEFENSE" : "BUILDING")
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 4) {
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
            
            Text("\(maxRolls) rolls")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .brutalistBadge(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: 8,
            borderWidth: 2
        )
    }
    
    // MARK: - Probability Bar
    
    private var probabilityBar: some View {
        VStack(spacing: 8) {
            // Title - shows ROLLING during animation
            Text(masterRollAnimationStarted ? "ROLLING" : (viewModel.uiState == .reeling || viewModel.uiState == .fishFound ? "CATCH ODDS" : "FISH ODDS"))
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Vertical bar - always visible, stable, FIXED SIZE
            VerticalRollBar(
                items: viewModel.currentDropTableDisplay,
                slots: viewModel.currentSlots,
                markerValue: masterRollDisplayValue,
                showMarker: showMasterRollMarker,
                markerIcon: viewModel.uiState == .reeling || viewModel.uiState == .fishFound ? "arrow.up" : "water.waves"
            )
            .frame(width: 60, height: 280)
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
        }
        .frame(width: 80, height: 320)  // FIXED SIZE
    }
    
    @MainActor
    private func runMasterRollAnimation() async {
        let finalValue = viewModel.masterRollValue
        guard finalValue > 0 else { return }
        
        // Build sweep path: up to 100, then back down to final
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
            try? await Task.sleep(nanoseconds: 30_000_000)  // 30ms per step
        }
        
        masterRollDisplayValue = finalValue
        viewModel.onMasterRollAnimationComplete()
    }
    
    // MARK: - Bottom Button
    
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            // FIXED HEIGHT container - no jumping
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
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    
                case .casting, .reeling, .masterRollAnimation:
                    HStack {
                        ProgressView()
                            .tint(viewModel.phaseColor)
                        Text(viewModel.uiState == .casting ? "Waiting..." : "Pulling...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                case .caught, .escaped:
                    Text(viewModel.uiState == .caught ? "Nice catch!" : "Better luck next time...")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(viewModel.uiState == .caught ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
                    
                case .error(let message):
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            .frame(height: 50)  // FIXED HEIGHT
            .frame(maxWidth: .infinity)
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
}

// MARK: - Fishing Roll Card

struct FishingRollCard: View {
    let roll: FishingRollResult
    let index: Int
    
    var body: some View {
        VStack(spacing: 4) {
            // Roll number badge
            Text("#\(index)")
                .font(.system(size: 8, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Roll value
            Text("\(roll.roll)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(roll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
            
            // Hit/miss indicator
            Image(systemName: roll.is_success ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(roll.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
        }
        .frame(width: 44, height: 44)
        .brutalistBadge(
            backgroundColor: roll.is_success ? KingdomTheme.Colors.buttonSuccess.opacity(0.15) : KingdomTheme.Colors.parchment,
            cornerRadius: 8,
            borderWidth: roll.is_success ? 2 : 1
        )
    }
}

// MARK: - Preview

#Preview {
    // Mock preview - won't work without real API client
    NavigationStack {
        Text("Fishing View Preview")
            .font(.title)
    }
}
