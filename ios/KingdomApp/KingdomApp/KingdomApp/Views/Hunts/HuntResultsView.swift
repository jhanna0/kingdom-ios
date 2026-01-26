import SwiftUI

// MARK: - Hunt Results View
// Clean, focused results screen

struct HuntResultsView: View {
    @ObservedObject var viewModel: HuntViewModel
    @State private var showContent = false
    @State private var meatCountUp: Int = 0
    @State private var showStreakPopup: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        resultHeader
                        
                        lootSection
                        partySection
                    }
                    .padding(.horizontal, KingdomTheme.Spacing.large)
                    .padding(.top, KingdomTheme.Spacing.large)
                    .padding(.bottom, 100) // Space for button
                }
                .opacity(showContent ? 1 : 0)
            }
            
            // Fixed bottom button
            VStack {
                Spacer()
                bottomButton
            }
            .opacity(showContent ? 1 : 0)
            
            // Streak bonus popup
            if showStreakPopup, let streakInfo = viewModel.hunt?.streak_info {
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showContent = true
            }
            if let totalMeat = viewModel.hunt?.rewards?.total_meat {
                animateMeatCountUp(to: totalMeat)
            }
            // Check streak popup on appear (if already true)
            checkAndShowStreakPopup()
        }
        // Also listen for changes (handles timing issues where data loads after view appears)
        .onChange(of: viewModel.shouldShowStreakPopup) { _, shouldShow in
            if shouldShow {
                checkAndShowStreakPopup()
            }
        }
    }
    
    // MARK: - Result Header
    
    private var resultHeader: some View {
        VStack(spacing: 12) {
            // Animal or result icon
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 104, height: 104)
                    .offset(x: 4, y: 4)
                
                Circle()
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(resultColor, lineWidth: 4)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 3)
                    )
                
                if viewModel.hunt?.status == .completed, let animal = viewModel.hunt?.animal {
                    Text(animal.icon ?? "🎯")
                        .font(.system(size: 50))
                } else {
                    Image(systemName: resultIcon)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(resultColor)
                }
            }
            
            Text(resultTitle)
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(resultSubtitle)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Loot Section
    
    private var lootSection: some View {
        VStack(spacing: 14) {
            if let rewards = viewModel.hunt?.rewards {
                // THIS HUNT
                VStack(spacing: 8) {
                    Text("THIS HUNT")
                        .font(FontStyles.captionSmall)
                        .tracking(2)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 12) {
                        lootBadge(icon: "flame.fill", value: "\(meatCountUp)", label: "Meat", color: KingdomTheme.Colors.buttonDanger)
                        lootBadge(icon: "g.circle.fill", value: "\(rewards.meat_market_value)", label: "Gold", color: KingdomTheme.Colors.gold)
                    }
                    
                    // Rare items
                    if let itemDetails = rewards.item_details, !itemDetails.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(itemDetails, id: \.id) { item in
                                itemBadge(item: item)
                            }
                        }
                    } else if !rewards.items.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(rewards.items, id: \.self) { item in
                                legacyItemBadge(itemId: item)
                            }
                        }
                    }
                }
                
                // LAST HOUR
                if let stats = viewModel.hunt?.hunting_stats, stats.hunt_count > 0 {
                    Divider()
                    
                    VStack(spacing: 8) {
                        Text("LAST HOUR")
                            .font(FontStyles.captionSmall)
                            .tracking(2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        HStack(spacing: 12) {
                            lootBadge(icon: "flame.fill", value: "\(stats.meat)", label: "Meat", color: KingdomTheme.Colors.buttonDanger)
                            lootBadge(icon: "g.circle.fill", value: "\(stats.gold)", label: "Gold", color: KingdomTheme.Colors.gold)
                        }
                        
                        // Rare items from last hour
                        if !stats.item_details.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(stats.item_details, id: \.id) { item in
                                    lastHourItemBadge(item: item)
                                }
                            }
                        }
                        
                        Text("\(stats.hunt_count) hunt\(stats.hunt_count == 1 ? "" : "s")")
                            .font(FontStyles.captionLarge)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
            } else {
                Text("No loot collected")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    private func lastHourItemBadge(item: LastHourItemDetail) -> some View {
        HStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(FontStyles.iconMini)
            Text("\(item.count)x")
                .font(FontStyles.labelBold)
            Text(item.display_name)
                .font(FontStyles.labelSmall)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(KingdomTheme.Colors.regalPurple)
                .overlay(Capsule().stroke(Color.black, lineWidth: 2))
        )
    }
    
    private func lootBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
    
    /// Dynamic item badge using full item details from backend
    /// Always uses purple background for that sweet rare drop effect
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
                Capsule()
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                Capsule()
                    .fill(KingdomTheme.Colors.regalPurple)
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    /// Convert color string from backend to SwiftUI Color
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "orange": return .orange
        case "brown": return .brown
        case "purple", "regalpurple": return KingdomTheme.Colors.regalPurple
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "gray", "grey": return .gray
        default: return KingdomTheme.Colors.regalPurple
        }
    }
    
    /// Legacy fallback for backwards compatibility (item IDs only)
    private func legacyItemBadge(itemId: String) -> some View {
        let displayName = itemId.replacingOccurrences(of: "_", with: " ").capitalized
        
        return HStack(spacing: 6) {
            Image(systemName: "cube.fill")
                .font(.system(size: 14, weight: .bold))
            Text(displayName)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                Capsule()
                    .fill(KingdomTheme.Colors.regalPurple)
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
    
    // MARK: - Party Section
    
    private var partySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PARTY")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if let hunt = viewModel.hunt {
                ForEach(hunt.participantList.sorted { $0.total_contribution > $1.total_contribution }) { participant in
                    CompactPlayerRow(participant: participant)
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
    
    // MARK: - Bottom Button
    
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
            
            VStack(spacing: 10) {
                Button {
                    viewModel.resetForNewHunt()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Hunt Again")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                
                Button {
                    dismiss()
                } label: {
                    Text("Return to Kingdom")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .background(KingdomTheme.Colors.parchmentLight.ignoresSafeArea(edges: .bottom))
    }
    
    // MARK: - Helpers
    
    private var resultColor: Color {
        switch viewModel.hunt?.status {
        case .completed: return KingdomTheme.Colors.buttonSuccess
        case .failed: return KingdomTheme.Colors.buttonDanger
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var resultIcon: String {
        switch viewModel.hunt?.status {
        case .completed: return "checkmark"
        case .failed: return "xmark"
        default: return "questionmark"
        }
    }
    
    private var resultTitle: String {
        switch viewModel.hunt?.status {
        case .completed:
            if let animal = viewModel.hunt?.animal {
                return animal.name ?? "Hunt Complete"
            }
            return "Hunt Complete"
        case .failed:
            if viewModel.hunt?.animal == nil {
                return "Lost Trail"
            }
            // Use the outcome from the last phase result (scare vs miss)
            if let lastResult = viewModel.hunt?.phase_results.last,
               let effects = lastResult.effects,
               let outcome = effects["outcome"]?.stringValue {
                return outcome == "scare" ? "Spooked!" : "Missed!"
            }
            return "Hunt Failed"
        default: return "Hunt Complete"
        }
    }
    
    private var resultSubtitle: String {
        switch viewModel.hunt?.status {
        case .completed:
            return "Successful hunt!"
        case .failed:
            // Use the backend's outcome_message
            if let lastResult = viewModel.hunt?.phase_results.last {
                return lastResult.outcome_message
            }
            return "Better luck next time"
        default: return ""
        }
    }
    
    private func checkAndShowStreakPopup() {
        guard viewModel.shouldShowStreakPopup, !showStreakPopup else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showStreakPopup = true
        }
    }
    
    private func animateMeatCountUp(to target: Int) {
        guard target > 0 else {
            meatCountUp = 0
            return
        }
        
        let duration: Double = 1.0
        let steps = min(20, target)
        let stepDuration = duration / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + stepDuration * Double(i)) {
                meatCountUp = (target * i) / steps
            }
        }
    }
}

// MARK: - Compact Player Row

private struct CompactPlayerRow: View {
    let participant: HuntParticipant
    
    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 34, height: 34)
                    .offset(x: 1, y: 1)
                
                Circle()
                    .fill(KingdomTheme.Colors.parchment)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                Text(String(participant.player_name.prefix(1)).uppercased())
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            // Name (truncated properly)
            Text(participant.player_name)
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 8)
            
            // Stats inline
            HStack(spacing: 8) {
                // Hits
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    Text("\(participant.successful_rolls)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                // Crits (if any)
                if participant.critical_rolls > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Text("\(participant.critical_rolls)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
                
                // Meat earned
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("\(participant.meat_earned)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KingdomTheme.Colors.parchment)
        )
    }
}

// MARK: - Flow Layout (wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
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
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HuntResultsView(viewModel: HuntViewModel())
    }
}

