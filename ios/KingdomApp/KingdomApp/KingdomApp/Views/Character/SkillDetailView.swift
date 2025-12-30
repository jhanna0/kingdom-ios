import SwiftUI

struct SkillDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
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
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Benefits
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "star.fill", title: "Benefits")
                            
                            ForEach(getTierBenefits(tier: tier), id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: tier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                                        .frame(width: 20)
                                    
                                    Text(benefit)
                                        .font(.subheadline)
                                        .foregroundColor(tier <= currentTier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Requirements - ALWAYS SHOW
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "hourglass", title: "Requirements")
                            
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                                        .frame(width: 20)
                                    Text("\(getActionsRequired(tier: tier)) actions")
                                        .font(.subheadline)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Spacer()
                                    Text("2 hr cooldown")
                                        .font(.caption)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                        }
                        
                        Divider()
                        
                        // Cost - ALWAYS SHOW
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "dollarsign.circle.fill", title: "Cost")
                            
                            ResourceRow(
                                icon: "circle.fill",
                                iconColor: KingdomTheme.Colors.gold,
                                label: "Gold",
                                required: getCost(tier: tier),
                                available: player.gold
                            )
                        }
                        
                        // Action button or status - always visible, no collapsing
                        if tier <= currentTier {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.subheadline)
                                Text("Unlocked")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(KingdomTheme.Colors.gold.opacity(0.1))
                            .cornerRadius(10)
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
                                    .font(.subheadline)
                                Text("Complete Tier \(currentTier + 1) first")
                                    .font(.subheadline)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                            .cornerRadius(10)
                        } else if currentTier >= 5 {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.subheadline)
                                Text("Maximum Tier Reached!")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(KingdomTheme.Colors.gold.opacity(0.1))
                            .cornerRadius(10)
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
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.gold)
            Text(title)
                .font(.subheadline.bold())
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
        switch skillType {
        case "attack":
            return [
                "Tier \(tier) combat damage",
                "Increases coup attack power"
            ]
        case "defense":
            return [
                "Tier \(tier) combat resistance",
                "Increases coup defense power"
            ]
        case "leadership":
            return getLeadershipBenefits(tier: tier)
        case "building":
            return getBuildingBenefits(tier: tier)
        default:
            return []
        }
    }
    
    private func getLeadershipBenefits(tier: Int) -> [String] {
        var benefits: [String] = []
        
        let voteWeight = 1.0 + (Double(tier - 1) * 0.2)
        benefits.append("Vote weight: \(String(format: "%.1f", voteWeight))")
        
        switch tier {
        case 1:
            benefits.append("Can vote on coups")
        case 2:
            benefits.append("Can vote on coups")
            benefits.append("+50% rewards from ruler distributions")
        case 3:
            benefits.append("Can propose coups")
            benefits.append("+50% rewards from ruler")
        case 4:
            benefits.append("Can propose coups")
            benefits.append("+100% rewards from ruler")
        case 5:
            benefits.append("Can propose coups")
            benefits.append("+100% rewards from ruler")
            benefits.append("-50% coup cost (500g instead of 1000g)")
        default:
            break
        }
        
        return benefits
    }
    
    private func getBuildingBenefits(tier: Int) -> [String] {
        var benefits: [String] = []
        
        let discount = tier * 5
        benefits.append("\(discount)% property cost reduction")
        
        switch tier {
        case 1:
            benefits.append("Normal build action (2h cooldown)")
        case 2:
            benefits.append("+10% coin reward for building")
        case 3:
            benefits.append("+20% coin reward for building")
            benefits.append("+1 daily Assist (instant +3 progress)")
        case 4:
            benefits.append("+30% coin reward for building")
            benefits.append("10% chance to refund cooldown")
        case 5:
            benefits.append("+40% coin reward for building")
            benefits.append("25% chance to double progress")
        default:
            break
        }
        
        return benefits
    }
}
