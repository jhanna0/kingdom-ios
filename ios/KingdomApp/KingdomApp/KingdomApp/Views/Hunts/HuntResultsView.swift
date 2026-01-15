import SwiftUI

// MARK: - Hunt Results View
// Clean, focused results screen

struct HuntResultsView: View {
    @ObservedObject var viewModel: HuntViewModel
    @State private var showContent = false
    @State private var meatCountUp: Int = 0
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
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showContent = true
            }
            if let totalMeat = viewModel.hunt?.rewards?.total_meat {
                animateMeatCountUp(to: totalMeat)
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
        VStack(spacing: 12) {
            // Main loot row
            if let rewards = viewModel.hunt?.rewards {
                HStack(spacing: 16) {
                    // Meat
                    lootBadge(
                        icon: "leaf.fill",
                        value: "\(meatCountUp)",
                        label: "Meat",
                        color: KingdomTheme.Colors.buttonSuccess
                    )
                    
                    // Bonus (if any)
                    if rewards.bonus_meat > 0 {
                        lootBadge(
                            icon: "sparkles",
                            value: "+\(rewards.bonus_meat)",
                            label: "Blessed",
                            color: KingdomTheme.Colors.regalPurple
                        )
                    }
                }
                
                // Special items - use item_details from backend if available
                if let itemDetails = rewards.item_details, !itemDetails.isEmpty {
                    VStack(spacing: 8) {
                        Text("RARE LOOT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        HStack(spacing: 10) {
                            ForEach(itemDetails, id: \.id) { item in
                                itemBadge(item: item)
                            }
                        }
                    }
                } else if !rewards.items.isEmpty {
                    // Fallback to legacy string array (backwards compat)
                    VStack(spacing: 8) {
                        Text("RARE LOOT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        HStack(spacing: 10) {
                            ForEach(rewards.items, id: \.self) { item in
                                legacyItemBadge(itemId: item)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                                .offset(x: 3, y: 3)
                            RoundedRectangle(cornerRadius: 12)
                                .fill(KingdomTheme.Colors.parchmentLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(KingdomTheme.Colors.regalPurple.opacity(0.4), lineWidth: 2)
                                )
                        }
                    )
                }
            } else {
                // No loot (failed hunt)
                Text("No loot collected")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .padding()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
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
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        HuntResultsView(viewModel: HuntViewModel())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HuntResultsView(viewModel: HuntViewModel())
    }
}

