import SwiftUI

struct SkillDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    
    let skillType: String
    let trainingContracts: [TrainingContract]
    let onPurchase: () -> Void
    
    @State private var selectedTier: Int = 1
    @State private var showSuccessToast: Bool = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Unified tier selector
                    TierSelectorCard(
                    currentTier: currentTier,
                    selectedTier: $selectedTier,
                    accentColor: skillColor
                ) { tier in
                    VStack(alignment: .leading, spacing: 16) {
                        // Tier name
                        Text("Tier \(tier)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Benefits
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: skillIcon, title: "Benefits")
                            
                            ForEach(getTierBenefits(tier: tier), id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: tier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(tier <= currentTier ? skillColor : KingdomTheme.Colors.inkDark.opacity(0.3))
                                        .frame(width: 20)
                                    
                                    Text(benefit)
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(skillColor.opacity(0.3))
                            .frame(height: 2)
                        
                        // Requirements - ALWAYS SHOW
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "hourglass", title: "Requirements")
                            
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(skillColor.opacity(0.5))
                                        .frame(width: 20)
                                    Text("\(getActionsRequired(tier: tier)) actions")
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Spacer()
                                    Text("2 hr cooldown")
                                        .font(FontStyles.labelSmall)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                        }
                        
                        Rectangle()
                            .fill(skillColor.opacity(0.3))
                            .frame(height: 2)
                        
                        // Cost - ALWAYS SHOW
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "dollarsign.circle.fill", title: "Cost")
                            
                            ResourceRow(
                                icon: "g.circle.fill",
                                iconColor: KingdomTheme.Colors.goldLight,
                                label: "Gold",
                                required: getCost(tier: tier),
                                available: player.gold
                            )
                        }
                        
                        // Action button or status - EXACT MapHUD style
                        if tier <= currentTier {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Unlocked")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black)
                                        .offset(x: 2, y: 2)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(KingdomTheme.Colors.inkMedium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.black, lineWidth: 2)
                                        )
                                }
                            )
                        } else if tier == currentTier + 1 && currentTier < 5 {
                            UnifiedActionButton(
                                title: "Start Training",
                                subtitle: nil,
                                icon: "person.fill.checkmark",
                                isEnabled: isEnabled,
                                statusMessage: statusMessage,
                                action: {
                                    onPurchase()
                                    
                                    // Show success toast
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showSuccessToast = true
                                    }
                                    
                                    // Haptic feedback
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    
                                    // Dismiss toast and view after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showSuccessToast = false
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            dismiss()
                                        }
                                    }
                                }
                            )
                        } else if tier > currentTier + 1 {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Complete Tier \(currentTier + 1) first")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black)
                                        .offset(x: 2, y: 2)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(KingdomTheme.Colors.parchmentLight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.black, lineWidth: 2)
                                        )
                                }
                            )
                        } else if currentTier >= 5 {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Maximum Tier Reached!")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black)
                                        .offset(x: 2, y: 2)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(KingdomTheme.Colors.inkMedium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.black, lineWidth: 2)
                                        )
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
            
            // Success toast - floats at top of screen
            if showSuccessToast {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Training purchased! Level in actions menu.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                                .offset(x: 3, y: 3)
                            RoundedRectangle(cornerRadius: 12)
                                .fill(KingdomTheme.Colors.buttonSuccess)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black, lineWidth: 2.5)
                                )
                        }
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .zIndex(999)
            }
        }
        .navigationTitle(skillDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedTier = min(currentTier + 1, 5)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(skillColor.opacity(0.5))
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Computed Properties
    
    private var skillDisplayName: String {
        // FULLY DYNAMIC
        let config = SkillConfig.get(skillType)
        return config.displayName
    }
    
    private var skillColor: Color {
        return SkillConfig.get(skillType).color
    }
    
    private var skillIcon: String {
        return SkillConfig.get(skillType).icon
    }
    
    private var currentTier: Int {
        // FULLY DYNAMIC
        switch skillType {
        case "attack": return player.attackPower
        case "defense": return player.defensePower
        case "leadership": return player.leadership
        case "building": return player.buildingSkill
        case "intelligence": return player.intelligence
        case "science": return player.science
        case "faith": return player.faith
        default: return 0
        }
    }
    
    private var trainingCost: Int {
        // FULLY DYNAMIC
        switch skillType {
        case "attack": return player.attackTrainingCost
        case "defense": return player.defenseTrainingCost
        case "leadership": return player.leadershipTrainingCost
        case "building": return player.buildingTrainingCost
        case "intelligence": return player.intelligenceTrainingCost
        case "science": return player.scienceTrainingCost
        case "faith": return player.faithTrainingCost
        default: return 100
        }
    }
    
    private func getCost(tier: Int) -> Int {
        // This is a rough estimate since we don't have historical data
        // The actual cost is based on total training purchases
        return trainingCost
    }
    
    private func getActionsRequired(tier: Int) -> Int {
        return max(3, tier + 2)
    }
    
    private var canAffordSelectedTier: Bool {
        return player.gold >= getCost(tier: selectedTier)
    }
    
    private var hasActiveTraining: Bool {
        return trainingContracts.contains { $0.status != "completed" }
    }
    
    private var isEnabled: Bool {
        return canAffordSelectedTier && !hasActiveTraining && selectedTier == currentTier + 1 && currentTier < 5
    }
    
    private var statusMessage: String? {
        if hasActiveTraining {
            return "Complete your current training first"
        } else if !canAffordSelectedTier {
            return "Insufficient gold"
        }
        return nil
    }
    
    private func getTierBenefits(tier: Int) -> [String] {
        // Use TierManager as single source of truth
        return tierManager.skillBenefitsFor(skillType, tier: tier)
    }
}
