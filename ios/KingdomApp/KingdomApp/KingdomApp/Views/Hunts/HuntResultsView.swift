import SwiftUI

// MARK: - Hunt Results View
// Final screen showing hunt outcome and rewards

struct HuntResultsView: View {
    @ObservedObject var viewModel: HuntViewModel
    @State private var showHeader = false
    @State private var showAnimal = false
    @State private var showRewards = false
    @State private var showPlayers = false
    @State private var showButtons = false
    @State private var meatCountUp: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header with outcome
                resultHeader
                    .opacity(showHeader ? 1 : 0)
                    .scaleEffect(showHeader ? 1 : 0.8)
                
                // Animal caught (if successful)
                if viewModel.hunt?.status == .completed {
                    animalCaughtSection
                        .opacity(showAnimal ? 1 : 0)
                        .offset(y: showAnimal ? 0 : 20)
                }
                
                // Rewards section
                if showRewards {
                    rewardsSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
                
                // Player contributions
                playerContributionsSection
                    .opacity(showPlayers ? 1 : 0)
                    .offset(y: showPlayers ? 0 : 20)
                
                // Action buttons
                actionButtons
                    .opacity(showButtons ? 1 : 0)
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    private func animateEntrance() {
        // Staggered entrance animation for smooth results reveal
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showHeader = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showAnimal = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showRewards = true
            }
            
            // Count up meat animation
            if let totalMeat = viewModel.hunt?.rewards?.total_meat {
                animateMeatCountUp(to: totalMeat)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showPlayers = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showButtons = true
            }
        }
    }
    
    // MARK: - Result Header
    
    private var resultHeader: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Success/Failure icon
            ZStack {
                Circle()
                    .fill(resultColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: resultIcon)
                    .font(.system(size: 60))
                    .foregroundColor(resultColor)
            }
            
            Text(resultTitle)
                .font(KingdomTheme.Typography.largeTitle())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(resultSubtitle)
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var resultColor: Color {
        switch viewModel.hunt?.status {
        case .completed: return KingdomTheme.Colors.buttonSuccess
        case .failed: return KingdomTheme.Colors.buttonDanger
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var resultIcon: String {
        switch viewModel.hunt?.status {
        case .completed: return "trophy.fill"
        case .failed: return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private var resultTitle: String {
        switch viewModel.hunt?.status {
        case .completed: return "Hunt Successful!"
        case .failed:
            if viewModel.hunt?.animal_escaped == true {
                return "It Got Away!"
            } else if viewModel.hunt?.track_score ?? 0 <= 0 {
                return "No Trail Found"
            }
            return "Hunt Failed"
        default: return "Hunt Complete"
        }
    }
    
    private var resultSubtitle: String {
        switch viewModel.hunt?.status {
        case .completed:
            if let animal = viewModel.hunt?.animal {
                return "You caught a \(animal.name ?? "creature")!"
            }
            return "Great teamwork!"
        case .failed:
            if viewModel.hunt?.animal_escaped == true {
                return "The prey escaped into the forest..."
            } else if viewModel.hunt?.track_score ?? 0 <= 0 {
                return "The forest was quiet today."
            }
            return "Better luck next time."
        default: return ""
        }
    }
    
    // MARK: - Animal Caught Section
    
    private var animalCaughtSection: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            if let animal = viewModel.hunt?.animal {
                Text(animal.icon ?? "🎯")
                    .font(.system(size: 80))
                
                Text(animal.name ?? "Unknown")
                    .font(KingdomTheme.Typography.title())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let tier = animal.tier {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < tier ? "star.fill" : "star")
                                .foregroundColor(i < tier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium.opacity(0.3))
                        }
                    }
                    .font(.title3)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    // MARK: - Rewards Section
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Rewards")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if let rewards = viewModel.hunt?.rewards {
                // Meat (Primary Reward)
                HStack {
                    Text("🥩")
                        .font(.title)
                    
                    VStack(alignment: .leading) {
                        Text("Meat Collected")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("\(meatCountUp) meat")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if rewards.bonus_meat > 0 {
                            Text("(+\(rewards.bonus_meat) from blessing)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        Text("Market Value: \(rewards.meat_market_value)g")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KingdomTheme.Colors.parchment)
                )
                
                // Items
                if !rewards.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items Found")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(rewards.items, id: \.self) { item in
                                Text(formatItemName(item))
                                    .font(FontStyles.labelMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(KingdomTheme.Colors.parchmentLight)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(KingdomTheme.Colors.border, lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KingdomTheme.Colors.parchment)
                    )
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    // MARK: - Player Contributions
    
    private var playerContributionsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Party Performance")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if let hunt = viewModel.hunt {
                ForEach(hunt.participantList.sorted { $0.total_contribution > $1.total_contribution }) { participant in
                    PlayerContributionRow(participant: participant)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Button {
                viewModel.resetForNewHunt()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Hunt Again")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            .disabled(viewModel.uiState == .loading)
            
            Button {
                dismiss()
            } label: {
                Text("Return to Kingdom")
            }
            .font(KingdomTheme.Typography.subheadline())
            .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Helpers
    
    private func animateMeatCountUp(to target: Int) {
        let duration: Double = 1.5
        let steps = 30
        let stepDuration = duration / Double(steps)
        let increment = target / steps
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                if i == steps {
                    meatCountUp = target
                } else {
                    meatCountUp = increment * i
                }
            }
        }
    }
    
    private func formatItemName(_ item: String) -> String {
        item.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Player Contribution Row

struct PlayerContributionRow: View {
    let participant: HuntParticipant
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Avatar
            Circle()
                .fill(KingdomTheme.Colors.inkMedium)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(participant.player_name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            // Name and stats
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.player_name)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 12) {
                    Label("\(participant.successful_rolls)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    
                    if participant.critical_rolls > 0 {
                        Label("\(participant.critical_rolls)", systemImage: "star.fill")
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                    
                    if participant.is_injured {
                        Label("Injured", systemImage: "bandage.fill")
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    }
                }
                .font(FontStyles.labelSmall)
            }
            
            Spacer()
            
            // Meat earned
            VStack(alignment: .trailing) {
                Text("🥩 \(participant.meat_earned)")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Contribution: \(String(format: "%.1f", participant.total_contribution))")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(KingdomTheme.Colors.parchment)
        )
    }
}

// MARK: - Flow Layout (for items)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: width, height: y + maxHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HuntResultsView(viewModel: HuntViewModel())
    }
}

