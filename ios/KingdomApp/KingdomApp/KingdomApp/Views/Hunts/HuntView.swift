import SwiftUI

// MARK: - Main Hunt View
// Routes between states based on the UI state machine

struct HuntView: View {
    let kingdomId: String
    let kingdomName: String
    let playerId: Int
    
    @StateObject private var viewModel = HuntViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
        .navigationTitle("Group Hunt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
            ProgressView("Loading...")
                .tint(KingdomTheme.Colors.inkMedium)
            
        case .noHunt:
            HuntStartView(viewModel: viewModel, kingdomId: kingdomId, kingdomName: kingdomName)
            
        case .lobby:
            HuntLobbyView(viewModel: viewModel, kingdomName: kingdomName)
            
        case .phaseIntro(let phase):
            HuntPhaseView(viewModel: viewModel, phase: phase, showingIntro: true)
            
        case .phaseActive(let phase), .rolling(let phase), .rollRevealing(let phase), .resolving(let phase), .masterRollAnimation(let phase):
            HuntPhaseView(viewModel: viewModel, phase: phase, showingIntro: false)
            
        case .phaseComplete(let phase):
            HuntPhaseView(viewModel: viewModel, phase: phase, showingIntro: false)
            
        case .creatureReveal:
            CreatureRevealView(viewModel: viewModel)
            
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
                    
                    Text("Group Hunt")
                        .font(KingdomTheme.Typography.largeTitle())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Hunt together for gold and glory!")
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
                
                // Create Hunt Button
                Button {
                    Task {
                        await viewModel.createHunt(kingdomId: kingdomId)
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Start a Hunt")
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

// MARK: - Creature Reveal View
// Dedicated full-screen view for dramatic creature reveal

struct CreatureRevealView: View {
    @ObservedObject var viewModel: HuntViewModel
    
    @State private var backgroundScale: CGFloat = 0.1
    @State private var creatureScale: CGFloat = 0.3
    @State private var creatureOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var glowPulse: Bool = false
    
    var body: some View {
        ZStack {
            // Dramatic background
            KingdomTheme.Colors.parchmentLight
                .ignoresSafeArea()
            
            // Radial burst effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tierColor.opacity(0.4), tierColor.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .scaleEffect(backgroundScale)
            
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                Spacer()
                
                // "FOUND!" banner
                Text("FOUND!")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .tracking(6)
                    .foregroundColor(tierColor)
                    .opacity(textOpacity)
                
                // DRAMATIC creature display
                ZStack {
                    // Pulsing glow
                    Circle()
                        .fill(tierColor.opacity(glowPulse ? 0.4 : 0.2))
                        .frame(width: 240, height: 240)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowPulse)
                    
                    Circle()
                        .fill(tierColor.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(tierColor, lineWidth: 6)
                        )
                        .shadow(color: tierColor.opacity(0.6), radius: 30)
                    
                    // THE CREATURE - BIG
                    Text(viewModel.hunt?.animal?.icon ?? "🎯")
                        .font(.system(size: 120))
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 3, y: 6)
                }
                .scaleEffect(creatureScale)
                .opacity(creatureOpacity)
                
                // Creature name with tier stars
                VStack(spacing: 12) {
                    Text(viewModel.hunt?.animal?.name ?? "Unknown")
                        .font(.system(size: 40, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let tier = viewModel.hunt?.animal?.tier {
                        HStack(spacing: 8) {
                            ForEach(0..<max(tier + 1, 1), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                    }
                }
                .opacity(textOpacity)
                
                Spacer()
                
                // Continue button
                Button {
                    Task {
                        await viewModel.userTappedContinueAfterCreatureReveal()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("BEGIN THE HUNT")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.gold, foregroundColor: KingdomTheme.Colors.inkDark))
                .opacity(buttonOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.8)) {
            backgroundScale = 3.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                creatureScale = 1.0
                creatureOpacity = 1.0
            }
            glowPulse = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                textOpacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    private var tierColor: Color {
        guard let tier = viewModel.hunt?.animal?.tier else { return KingdomTheme.Colors.inkMedium }
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
