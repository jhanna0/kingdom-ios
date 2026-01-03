import SwiftUI

struct SkillDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    
    let skillType: String
    let trainingContracts: [TrainingContract]
    let onPurchase: () -> Void
    
    @State private var selectedTier: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Unified tier selector
                TierSelectorCard(
                    currentTier: currentTier,
                    selectedTier: $selectedTier
                ) { tier in
                    VStack(alignment: .leading, spacing: 16) {
                        // Tier name
                        Text("Tier \(tier)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Benefits
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "star.fill", title: "Benefits")
                            
                            ForEach(getTierBenefits(tier: tier), id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: tier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkDark.opacity(0.3))
                                        .frame(width: 20)
                                    
                                    Text(benefit)
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 2)
                        
                        // Requirements - ALWAYS SHOW
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "hourglass", title: "Requirements")
                            
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
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
                            .fill(Color.black)
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
                                    dismiss()
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
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Computed Properties
    
    private var skillDisplayName: String {
        switch skillType {
        case "attack": return "Attack Power"
        case "defense": return "Defense Power"
        case "leadership": return "Leadership"
        case "building": return "Building Skill"
        default: return skillType.capitalized
        }
    }
    
    private var currentTier: Int {
        switch skillType {
        case "attack": return player.attackPower
        case "defense": return player.defensePower
        case "leadership": return player.leadership
        case "building": return player.buildingSkill
        default: return 1
        }
    }
    
    private var trainingCost: Int {
        switch skillType {
        case "attack": return player.attackTrainingCost
        case "defense": return player.defenseTrainingCost
        case "leadership": return player.leadershipTrainingCost
        case "building": return player.buildingTrainingCost
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
