import SwiftUI

// MARK: - Hunt Results View

struct HuntResultsView: View {
    @ObservedObject var viewModel: HuntViewModel
    @State private var showContent = false
    @State private var meatCountUp: Int = 0
    @State private var showStreakPopup: Bool = false
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        resultHeader
                        lootCard
                        
                        if let stats = viewModel.hunt?.hunting_stats, stats.hunt_count > 1 {
                            lastHourCard(stats: stats)
                        }
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
                .opacity(showContent ? 1 : 0)
                
                bottomButton
                    .opacity(showContent ? 1 : 0)
            }
            
            if showStreakPopup, let streakInfo = viewModel.hunt?.streak_info {
                StreakBonusPopup(
                    title: streakInfo.title,
                    subtitle: streakInfo.subtitle,
                    description: streakInfo.description,
                    multiplier: streakInfo.multiplier,
                    icon: streakInfo.icon,
                    color: streakInfo.color,
                    dismissButton: streakInfo.dismiss_button
                ) { showStreakPopup = false }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { showContent = true }
            if let total = viewModel.hunt?.rewards?.total_meat { animateMeatCountUp(to: total) }
            checkAndShowStreakPopup()
        }
        .onChange(of: viewModel.shouldShowStreakPopup) { _, show in
            if show { checkAndShowStreakPopup() }
        }
    }
    
    // MARK: - Result Header
    
    private var resultHeader: some View {
        VStack(spacing: 14) {
            // Animal icon
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 94, height: 94)
                    .offset(x: 4, y: 4)
                
                Circle()
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .frame(width: 90, height: 90)
                    .overlay(Circle().stroke(resultColor, lineWidth: 4))
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                
                if viewModel.hunt?.status == .completed, let animal = viewModel.hunt?.animal {
                    Text(animal.icon ?? "🎯")
                        .font(.system(size: 46))
                } else {
                    Image(systemName: resultIcon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(resultColor)
                }
            }
            
            Text(resultTitle)
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(resultSubtitle)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Loot Card
    
    private var lootCard: some View {
        VStack(spacing: 14) {
            if let rewards = viewModel.hunt?.rewards {
                // Meat + Gold
                HStack(spacing: 14) {
                    lootBadge(icon: "flame.fill", value: "\(meatCountUp)", label: "Meat", color: KingdomTheme.Colors.buttonDanger)
                    lootBadge(icon: "g.circle.fill", value: "\(rewards.meat_market_value)", label: "Gold", color: KingdomTheme.Colors.gold)
                }
                
                // Rare items
                if let items = rewards.item_details, !items.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            itemBadge(item: item)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    private func lootBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.12))
        )
    }
    
    private func itemBadge(item: ItemDetail) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .bold))
            Text(item.display_name)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule().fill(Color.black).offset(x: 2, y: 2)
                Capsule().fill(KingdomTheme.Colors.regalPurple)
                    .overlay(Capsule().stroke(Color.black, lineWidth: 2))
            }
        )
    }
    
    // MARK: - Last Hour Card
    
    private func lastHourCard(stats: HuntingStats) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("LAST HOUR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("\(stats.hunt_count) hunts")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("\(stats.meat)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                HStack(spacing: 5) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Text("\(stats.gold)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                if !stats.item_details.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(stats.item_details.prefix(3), id: \.id) { item in
                            Image(systemName: item.icon)
                                .font(.system(size: 12))
                                .foregroundColor(KingdomTheme.Colors.regalPurple)
                        }
                        if stats.item_details.count > 3 {
                            Text("+\(stats.item_details.count - 3)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.regalPurple)
                        }
                    }
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    // MARK: - Bottom Button
    
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            Button {
                Task { await viewModel.autoRestartHunt() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Hunt Again")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Helpers
    
    private var resultColor: Color {
        viewModel.hunt?.status == .completed ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private var resultIcon: String {
        viewModel.hunt?.status == .completed ? "checkmark" : "xmark"
    }
    
    private var resultTitle: String {
        if viewModel.hunt?.status == .completed, let name = viewModel.hunt?.animal?.name {
            return name
        }
        return viewModel.hunt?.status == .completed ? "Hunt Complete" : "Hunt Failed"
    }
    
    private var resultSubtitle: String {
        viewModel.hunt?.status == .completed ? "Successful hunt!" : "Better luck next time"
    }
    
    private func checkAndShowStreakPopup() {
        guard viewModel.shouldShowStreakPopup, !showStreakPopup else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showStreakPopup = true }
    }
    
    private func animateMeatCountUp(to target: Int) {
        guard target > 0 else { meatCountUp = 0; return }
        let steps = min(20, target)
        let stepDuration = 1.0 / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + stepDuration * Double(i)) {
                meatCountUp = (target * i) / steps
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#Preview {
    HuntResultsView(viewModel: HuntViewModel())
}
