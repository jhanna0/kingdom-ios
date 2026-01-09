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
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error ?? "Unknown error")
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
            
        case .phaseActive(let phase), .rolling(let phase), .rollRevealing(let phase), .resolving(let phase), .masterRollAnimation(let phase):
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
            CreatureRevealOverlay(
                viewModel: viewModel,
                onContinue: {
                    Task {
                        await viewModel.userTappedContinueAfterCreatureReveal()
                    }
                }
            )
            
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 60))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Hunt")
                        .font(KingdomTheme.Typography.largeTitle())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Track prey and bring back meat for your kingdom!")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Probability Preview
                if let preview = viewModel.preview {
                    HuntPreviewCard(preview: preview)
                        .padding(.horizontal)
                }
                
                // Animals Preview
                if let config = viewModel.config {
                    AnimalsPreviewCard(animals: config.animals)
                        .padding(.horizontal)
                }
                
                // Start Hunt Button
                Button {
                    Task {
                        await viewModel.createHunt(kingdomId: kingdomId)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Start Hunt")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Hunt Preview Card

struct HuntPreviewCard: View {
    let preview: HuntPreviewResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Your Chances")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(spacing: KingdomTheme.Spacing.small) {
                // Only 3 phases: Track → Strike → Blessing
                ForEach(["track", "strike", "blessing"], id: \.self) { phaseKey in
                    if let phase = preview.phases[phaseKey] {
                        HStack {
                            Image(systemName: phase.icon)
                                .font(.headline)
                                .foregroundColor(KingdomTheme.Colors.color(fromThemeName: phase.color))
                                .frame(width: 30)
                            
                            Text(phase.phase_name)
                                .font(KingdomTheme.Typography.subheadline())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            // Probability bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.1))
                                    .frame(width: 80, height: 16)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(KingdomTheme.Colors.color(fromThemeName: phase.color))
                                    .frame(width: CGFloat(phase.percentage) * 0.8, height: 16)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.black, lineWidth: 1.5)
                                    .frame(width: 80, height: 16)
                            )
                            
                            Text("\(phase.percentage)%")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
}

// MARK: - Animals Preview Card

struct AnimalsPreviewCard: View {
    let animals: [HuntAnimalConfig]
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Possible Prey")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(animals) { animal in
                    VStack(spacing: 4) {
                        Text(animal.icon)
                            .font(.system(size: 32))
                        
                        Text(animal.name)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .lineLimit(1)
                        
                        Text("🥩 \(animal.meat)")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tierColor(animal.tier).opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(tierColor(animal.tier).opacity(0.5), lineWidth: 1)
                    )
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
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
