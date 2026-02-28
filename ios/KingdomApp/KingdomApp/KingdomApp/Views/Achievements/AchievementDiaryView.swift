import SwiftUI
import Combine

// MARK: - Achievement Diary View Model

@MainActor
class AchievementDiaryViewModel: ObservableObject {
    @Published var categories: [APIAchievementCategory] = []
    @Published var totalAchievements: Int = 0
    @Published var totalTiers: Int = 0
    @Published var totalCompleted: Int = 0
    @Published var totalClaimed: Int = 0
    @Published var totalClaimable: Int = 0
    @Published var overallProgressPercent: Double = 0
    @Published var isLoading = false
    @Published var error: String?
    
    // Claim state
    @Published var claimingTierId: Int?
    @Published var claimedReward: APIClaimRewardResponse?
    @Published var showRewardPopup = false
    
    private let api = AchievementsAPI()
    
    func loadAchievements() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await api.getAchievements()
            categories = response.categories
            totalAchievements = response.total_achievements
            totalTiers = response.total_tiers
            totalCompleted = response.total_completed
            totalClaimed = response.total_claimed
            totalClaimable = response.total_claimable
            overallProgressPercent = response.overall_progress_percent
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func claimReward(tierId: Int) async {
        claimingTierId = tierId
        
        do {
            let response = try await api.claimReward(tierId: tierId)
            claimedReward = response
            showRewardPopup = true
            
            // Refresh achievements to update UI
            await loadAchievements()
        } catch {
            self.error = error.localizedDescription
        }
        
        claimingTierId = nil
    }
}

// MARK: - Achievement Diary View

struct AchievementDiaryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AchievementDiaryViewModel()
    @State private var selectedCategory: String?
    
    private let accentColor = KingdomTheme.Colors.buttonSuccess
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        // Compact header
                        achievementHeader
                        
                        // Category pills
                        categoryTabs
                        
                        // Achievements list
                        achievementsList
                    }
                    .padding(.vertical, KingdomTheme.Spacing.small)
                }
                
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    MedievalLoadingView(status: "Loading achievements...")
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(FontStyles.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
            .task {
                await viewModel.loadAchievements()
            }
            .refreshable {
                await viewModel.loadAchievements()
            }
            .overlay {
                if viewModel.showRewardPopup, let reward = viewModel.claimedReward {
                    AchievementRewardPopup(
                        reward: reward,
                        isShowing: $viewModel.showRewardPopup
                    )
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var achievementHeader: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Progress ring - uses backend-provided overall_progress_percent
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 4)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.overallProgressPercent / 100.0))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                
                Text("\(viewModel.totalClaimed)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.totalClaimed) of \(viewModel.totalTiers)")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Achievements Completed")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
            
            // Claimable badge
            if viewModel.totalClaimable > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(viewModel.totalClaimable)")
                        .font(FontStyles.labelBold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(accentColor)
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Category Tabs
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All tab
                categoryPill(id: nil, name: "All", icon: "square.grid.2x2")
                
                // Category tabs
                ForEach(viewModel.categories) { category in
                    categoryPill(id: category.category, name: category.display_name, icon: category.icon)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }
    
    private func categoryPill(id: String?, name: String, icon: String) -> some View {
        let isSelected = selectedCategory == id
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = id
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                
                Text(name)
                    .font(FontStyles.labelSmall)
            }
            .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkMedium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? accentColor : KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Achievements List
    
    private var achievementsList: some View {
        LazyVStack(spacing: KingdomTheme.Spacing.small) {
            let filteredCategories = selectedCategory == nil
                ? viewModel.categories
                : viewModel.categories.filter { $0.category == selectedCategory }
            
            ForEach(filteredCategories) { category in
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    // Category header (only show if viewing all)
                    if selectedCategory == nil {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            
                            Text(category.display_name)
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    
                    // Achievement cards
                    ForEach(category.achievements) { achievement in
                        AchievementCard(
                            achievement: achievement,
                            accentColor: accentColor,
                            claimingTierId: viewModel.claimingTierId,
                            onClaim: { tierId in
                                Task {
                                    await viewModel.claimReward(tierId: tierId)
                                }
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            
            if filteredCategories.isEmpty && !viewModel.isLoading {
                emptyState
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "trophy")
                .font(.system(size: 36))
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text("No achievements found")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.top, 40)
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: APIAchievement
    let accentColor: Color
    let claimingTierId: Int?
    let onClaim: (Int) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(achievement.has_claimable ? accentColor : KingdomTheme.Colors.parchmentDark)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        
                        Image(systemName: achievement.icon ?? "trophy.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(achievement.has_claimable ? .white : KingdomTheme.Colors.inkMedium)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(achievement.display_name)
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .lineLimit(1)
                            
                            if achievement.has_claimable {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(accentColor)
                            }
                        }
                        
                        // Compact progress
                        HStack(spacing: 6) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.black.opacity(0.08))
                                    
                                    Capsule()
                                        .fill(achievement.has_claimable ? accentColor : accentColor.opacity(0.7))
                                        .frame(width: geo.size.width * (achievement.progress_percent / 100))
                                }
                            }
                            .frame(height: 5)
                            
                            // Progress text
                            Text(progressText)
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .padding(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded tiers
            if isExpanded {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 10)
                
                VStack(spacing: 0) {
                    // Optional description at top of expanded section
                    if let typeDescription = achievement.type_display_name {
                        Text(typeDescription)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        
                        Rectangle()
                            .fill(Color.black.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 10)
                    }
                    
                    ForEach(achievement.tiers) { tier in
                        AchievementTierRow(
                            tier: tier,
                            currentValue: achievement.current_value,
                            accentColor: accentColor,
                            isClaiming: claimingTierId == tier.id,
                            onClaim: { onClaim(tier.id) }
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(KingdomTheme.Colors.parchmentLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private var progressText: String {
        if let target = achievement.next_tier_target {
            return "\(achievement.current_value)/\(target)"
        } else {
            return "MAX"
        }
    }
}

// MARK: - Achievement Tier Row

struct AchievementTierRow: View {
    let tier: APIAchievementTier
    let currentValue: Int
    let accentColor: Color
    let isClaiming: Bool
    let onClaim: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Tier indicator
            ZStack {
                Circle()
                    .fill(tierColor)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1))
                
                if tier.is_claimed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(tier.tier)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tier.is_completed ? .white : KingdomTheme.Colors.inkMedium)
                }
            }
            
            // Tier info
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.display_name)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(tier.is_claimed ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.inkDark)
                    .strikethrough(tier.is_claimed, color: KingdomTheme.Colors.inkLight)
                    .lineLimit(1)
                
                // Rewards inline
                HStack(spacing: 8) {
                    if tier.rewards.gold > 0 {
                        rewardLabel(icon: "g.circle.fill", value: tier.rewards.gold, color: KingdomTheme.Colors.goldLight)
                    }
                    if tier.rewards.experience > 0 {
                        rewardLabel(icon: "star.fill", value: tier.rewards.experience, color: accentColor)
                    }
                    if tier.rewards.book > 0 {
                        rewardLabel(icon: "book.fill", value: tier.rewards.book, color: .brown)
                    }
                }
            }
            
            Spacer()
            
            // Status / Claim
            if tier.is_claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
            } else if tier.is_completed {
                Button(action: onClaim) {
                    if isClaiming {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Text("Claim")
                            .font(FontStyles.labelTiny)
                    }
                }
                .foregroundColor(.white)
                .frame(width: 52, height: 26)
                .background(
                    Capsule()
                        .fill(accentColor)
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                )
                .disabled(isClaiming)
            } else {
                Text("\(currentValue)/\(tier.target_value)")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
    
    private var tierColor: Color {
        if tier.is_claimed {
            return accentColor
        } else if tier.is_completed {
            return accentColor.opacity(0.8)
        } else {
            return KingdomTheme.Colors.parchmentDark
        }
    }
    
    private func rewardLabel(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text("+\(value)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
    }
}

// MARK: - Achievement Reward Popup

struct AchievementRewardPopup: View {
    let reward: APIClaimRewardResponse
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    private let accentColor = KingdomTheme.Colors.buttonSuccess
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, options: .speed(0.5))
                }
                .padding(.top, 4)
                
                // Title
                VStack(spacing: 4) {
                    Text("Achievement Unlocked!")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(reward.display_name)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                // Rewards
                VStack(spacing: 8) {
                    if reward.rewards_granted.gold > 0 {
                        rewardRow(icon: "g.circle.fill", label: "Gold", value: "+\(reward.rewards_granted.gold)", color: KingdomTheme.Colors.goldLight)
                    }
                    if reward.rewards_granted.experience > 0 {
                        rewardRow(icon: "star.fill", label: "Experience", value: "+\(reward.rewards_granted.experience)", color: accentColor)
                    }
                    if reward.rewards_granted.book > 0 {
                        rewardRow(icon: "book.fill", label: "Book", value: "+\(reward.rewards_granted.book)", color: .brown)
                    }
                    if let newLevel = reward.new_level {
                        rewardRow(icon: "arrow.up.circle.fill", label: "Level Up!", value: "Level \(newLevel)", color: KingdomTheme.Colors.imperialGold)
                    }
                }
                .padding(.horizontal, 16)
                
                // Continue button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }) {
                    Text("Continue")
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(accentColor)
                                .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            .opacity(opacity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacity)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func rewardRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(label)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Spacer()
            
            Text(value)
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KingdomTheme.Colors.parchment)
        )
    }
}

// MARK: - Preview

#Preview {
    AchievementDiaryView()
}
