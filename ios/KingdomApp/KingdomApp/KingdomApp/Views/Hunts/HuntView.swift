import SwiftUI

// MARK: - Main Hunt View
// Routes between states based on the UI state machine

struct HuntView: View {
    let kingdomId: String
    let kingdomName: String
    let playerId: Int
    
    @StateObject private var viewModel = HuntViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showAbandonConfirmation = false
    
    var body: some View {
        ZStack {
            // Parchment background
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            // Subtle forest pattern overlay
            ForestPatternBackground()
                .opacity(0.03)
                .ignoresSafeArea()
            
            // Content based on UI state machine
            contentForState
        }
        .navigationTitle("Hunt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            // Show exit button when there's an active hunt
            if viewModel.hunt != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAbandonConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                }
            }
        }
        .confirmationDialog("Abandon Hunt?", isPresented: $showAbandonConfirmation, titleVisibility: .visible) {
            Button("Abandon", role: .destructive) {
                Task {
                    await viewModel.leaveHunt()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will lose all progress in this hunt.")
        }
        .task {
            viewModel.currentUserId = playerId
            await viewModel.loadConfig()
            await viewModel.loadPreview()
            await viewModel.checkForActiveHunt(kingdomId: kingdomId)
        }
    }
    
    @ViewBuilder
    private var contentForState: some View {
        switch viewModel.uiState {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(KingdomTheme.Colors.inkMedium)
                Text("Loading...")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
        case .noHunt:
            HuntStartView(viewModel: viewModel, kingdomId: kingdomId, kingdomName: kingdomName)
            
        case .lobby:
            HuntLobbyView(viewModel: viewModel, kingdomName: kingdomName)
            
        case .phaseIntro(let phase):
            HuntPhaseView(viewModel: viewModel, phase: phase, showingIntro: true)
            
        case .phaseActive(let phase), .rolling(let phase), .rollRevealing(let phase), .resolving(let phase), .masterRollAnimation(let phase), .masterRollComplete(let phase):
            HuntPhaseView(viewModel: viewModel, phase: phase, showingIntro: false)
            
        case .phaseComplete:
            // Show PhaseCompleteOverlay DIRECTLY here - not nested in HuntPhaseView
            // This prevents it from flashing during transitions
            PhaseCompleteOverlay(
                phaseResult: viewModel.currentPhaseResult,
                hunt: viewModel.hunt,
                onContinue: {
                    Task {
                        await viewModel.userTappedContinue()
                    }
                }
            )
            
        case .creatureReveal:
            // No longer used - animal info shows in arena card
            EmptyView()
            
        case .results:
            HuntResultsView(viewModel: viewModel)
        }
    }
}

// MARK: - Forest Pattern Background

struct ForestPatternBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    Image(systemName: "tree.fill")
                        .font(.system(size: CGFloat.random(in: 30...80)))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .opacity(Double.random(in: 0.3...0.6))
                }
            }
        }
    }
}

// MARK: - Hunt Start View (No Active Hunt)

struct HuntStartView: View {
    @ObservedObject var viewModel: HuntViewModel
    let kingdomId: String
    let kingdomName: String
    
    private var needsPermit: Bool {
        viewModel.permitStatus?.needs_permit ?? false
    }
    
    private var hasValidPermit: Bool {
        viewModel.permitStatus?.has_valid_permit ?? false
    }
    
    private var canHunt: Bool {
        viewModel.permitStatus?.can_hunt ?? true
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Header
                        VStack(spacing: 12) {
                            // Icon with brutalist style
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 84, height: 84)
                                    .offset(x: 3, y: 3)
                                
                                Circle()
                                    .fill(KingdomTheme.Colors.parchmentLight)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 3)
                                    )
                                
                                Image(systemName: "hare.fill")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            }
                            
                            Text("HUNT")
                                .font(.system(size: 28, weight: .black, design: .serif))
                                .tracking(4)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Track prey and bring back meat")
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.top, 24)
                        
                        // Hunting Permit Card (for visitors)
                        if needsPermit {
                            HuntingPermitCard(
                                viewModel: viewModel,
                                kingdomId: kingdomId,
                                kingdomName: kingdomName
                            )
                        }
                        
                        // Probability Preview
                        if let preview = viewModel.preview {
                            HuntPreviewCard(preview: preview)
                        }
                        
                        // Animals Preview
                        if let config = viewModel.config {
                            AnimalsPreviewCard(animals: config.animals)
                        }
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                    .padding(.bottom, 100)
                }
                
                // Fixed bottom button
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 3)
                    
                    if needsPermit && !hasValidPermit {
                        // Show "Buy Permit" button
                        Button {
                            Task {
                                await viewModel.buyPermit(kingdomId: kingdomId)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isBuyingPermit {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "scroll.fill")
                                    Text("Buy Hunting Permit (\(viewModel.permitStatus?.permit_cost ?? 10)g)")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.gold, fullWidth: true))
                        .disabled(viewModel.isBuyingPermit)
                        .padding(.horizontal, KingdomTheme.Spacing.large)
                        .padding(.vertical, KingdomTheme.Spacing.medium)
                    } else {
                        // Show "Start Hunt" button
                        Button {
                            Task {
                                await viewModel.createHunt(kingdomId: kingdomId)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Start Hunt")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                        .padding(.horizontal, KingdomTheme.Spacing.large)
                        .padding(.vertical, KingdomTheme.Spacing.medium)
                    }
                }
                .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
            }
        }
    }
}

// MARK: - Hunting Permit Card

struct HuntingPermitCard: View {
    @ObservedObject var viewModel: HuntViewModel
    let kingdomId: String
    let kingdomName: String
    
    private var hasValidPermit: Bool {
        viewModel.permitStatus?.has_valid_permit ?? false
    }
    
    private var minutesRemaining: Int {
        viewModel.permitStatus?.minutes_remaining ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: hasValidPermit ? "checkmark.seal.fill" : "scroll.fill")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(hasValidPermit ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.gold)
                
                Text("HUNTING PERMIT")
                    .font(FontStyles.labelBlackNano)
                    .tracking(2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                if hasValidPermit {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(FontStyles.iconMini)
                        Text("\(minutesRemaining)m left")
                            .font(FontStyles.statMedium)
                    }
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
            
            if hasValidPermit {
                Text("You have permission to hunt in \(kingdomName)!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You're visiting \(kingdomName)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Hunting permit 10g for 10 minutes.")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
}

// MARK: - Hunt Preview Card

struct HuntPreviewCard: View {
    let preview: HuntPreviewResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR ODDS")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            VStack(spacing: 8) {
                ForEach(["track", "strike", "blessing"], id: \.self) { phaseKey in
                    if let phase = preview.phases[phaseKey] {
                        phaseRow(phase: phase)
                    }
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private func phaseRow(phase: HuntPhasePreview) -> some View {
        let color = KingdomTheme.Colors.color(fromThemeName: phase.color)
        
        return HStack(spacing: 10) {
            Image(systemName: phase.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(phase.phase_name)
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            // Compact probability bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 60, height: 10)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: CGFloat(phase.percentage) * 0.6, height: 10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: 60, height: 10)
            )
            
            Text("\(phase.percentage)%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Animals Preview Card

struct AnimalsPreviewCard: View {
    let animals: [HuntAnimalConfig]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POSSIBLE PREY")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Horizontal scroll for animals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(animals.sorted { $0.tier < $1.tier }) { animal in
                        animalCell(animal: animal)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private func animalCell(animal: HuntAnimalConfig) -> some View {
        let color = tierColor(animal.tier)
        
        return VStack(spacing: 4) {
            Text(animal.icon)
                .font(.system(size: 26))
            
            Text(animal.name)
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
            
            // Meat yield
            HStack(spacing: 2) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 8))
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                Text("\(animal.meat)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            // Tier dots
            HStack(spacing: 2) {
                ForEach(0..<max(1, animal.tier + 1), id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return KingdomTheme.Colors.inkMedium
        case 1: return KingdomTheme.Colors.buttonSuccess
        case 2: return KingdomTheme.Colors.buttonWarning
        case 3: return KingdomTheme.Colors.buttonDanger
        case 4: return KingdomTheme.Colors.regalPurple
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HuntView(kingdomId: "test_kingdom", kingdomName: "Test Kingdom", playerId: 1)
    }
}
