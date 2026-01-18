import SwiftUI

// MARK: - Foraging View
// Scratch-ticket style - tap bushes to find seeds!

struct ForagingView: View {
    @StateObject private var viewModel = ForagingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let apiClient: APIClient
    
    @State private var showResult: Bool = false
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                VStack(spacing: 20) {
                    statusText
                    
                    Spacer()
                    
                    bushGrid
                    
                    Spacer()
                    
                    progressDots
                }
                .padding(.horizontal, KingdomTheme.Spacing.large)
                .padding(.vertical, KingdomTheme.Spacing.medium)
                
                bottomBar
            }
            
            if showResult {
                resultOverlay
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configure(with: apiClient)
            await viewModel.startSession()
        }
        .onChange(of: viewModel.uiState) { _, newState in
            if newState == .won || newState == .lost {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showResult = true
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    
                    Text("FORAGING")
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
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Status
    
    private var statusText: some View {
        VStack(spacing: 10) {
            // Legend - what we're looking for
            if let targetCell = viewModel.grid.first(where: { $0.is_seed }) {
                HStack(spacing: 8) {
                    Text("Looking for:")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 4) {
                        Image(systemName: targetCell.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        Text(targetCell.name)
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(KingdomTheme.Colors.gold, lineWidth: 2)
                            )
                    )
                }
            }
            
            Text("Find \(viewModel.matchesToWin) to win!")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Grid
    
    private var bushGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.grid) { cell in
                let isRevealed = viewModel.isRevealed(cell.position)
                let isTarget = isRevealed && cell.is_seed  // is_seed = is target from backend
                let targetCount = viewModel.revealedTargetCount
                let shouldPulse = isTarget && targetCount >= 1 && targetCount < viewModel.matchesToWin
                
                BushTile(
                    cell: cell,
                    isRevealed: isRevealed,
                    isHighlighted: isTarget,
                    shouldPulse: shouldPulse,
                    hiddenIcon: viewModel.hiddenIcon,
                    hiddenColor: viewModel.hiddenColor
                ) {
                    if viewModel.canReveal && !isRevealed {
                        viewModel.reveal(position: cell.position)
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.small)
    }
    
    // MARK: - Progress
    
    private var progressDots: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<viewModel.maxReveals, id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.revealedCount
                              ? KingdomTheme.Colors.gold
                              : KingdomTheme.Colors.inkMedium.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                }
            }
            
            Text("\(viewModel.revealedCount)/\(viewModel.maxReveals) revealed • \(viewModel.revealedSeedCount) seeds found")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Bottom
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            Text(viewModel.isWarming ? "🔥 Getting warm!" : "Tap a bush to reveal")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(viewModel.isWarming ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, KingdomTheme.Spacing.large)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Result Overlay
    
    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if viewModel.hasWon {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("You Found Seeds!")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    if let config = viewModel.rewardConfig {
                        HStack(spacing: 4) {
                            Image(systemName: config.icon)
                                .foregroundColor(KingdomTheme.Colors.gold)
                            Text("+\(viewModel.rewardAmount) \(config.display_name)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.collect()
                            showResult = false
                            await viewModel.startSession()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Collect & Play Again")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.gold,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("No Match")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Better luck next time!")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Button {
                        showResult = false
                        Task { await viewModel.playAgain() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try Again")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                }
            }
            .padding(24)
            .frame(maxWidth: 280)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 16)
        }
    }
}

// MARK: - Bush Tile
// Completely dumb - just renders what backend says

struct BushTile: View {
    let cell: ForagingBushCell      // Has is_seed, icon, color from backend
    let isRevealed: Bool
    let isHighlighted: Bool         // Backend decides if this should glow
    let shouldPulse: Bool           // Backend decides if this should pulse
    let hiddenIcon: String
    let hiddenColor: String
    let onTap: () -> Void
    
    @State private var pulse = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Shadow
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                
                // Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: isHighlighted ? 3 : 2.5)
                    )
                
                // Icon from backend
                Image(systemName: isRevealed ? cell.icon : hiddenIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isRevealed 
                        ? KingdomTheme.Colors.color(fromThemeName: cell.color)
                        : KingdomTheme.Colors.color(fromThemeName: hiddenColor))
            }
            .frame(height: 65)
            .scaleEffect(pulse ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: shouldPulse) { _, doPulse in
            if doPulse {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation(.default) {
                    pulse = false
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isHighlighted { return KingdomTheme.Colors.parchmentRich }
        return isRevealed ? KingdomTheme.Colors.parchmentDark : KingdomTheme.Colors.parchment
    }
    
    private var borderColor: Color {
        if isHighlighted { return KingdomTheme.Colors.gold }
        return Color.black
    }
}

#Preview {
    Text("Foraging Preview")
}
