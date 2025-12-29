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
                // Tier selector
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Select Tier")
                            .font(.system(.title3, design: .default).bold())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        // Current tier badge
                        Text("Current: T\(currentTier)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(KingdomTheme.Colors.gold.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Picker("Tier", selection: $selectedTier) {
                        ForEach(1...5, id: \.self) { tier in
                            Text("T\(tier)").tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(KingdomTheme.Colors.parchmentLight)
                .cornerRadius(12)
                
                // Tier details
                VStack(alignment: .leading, spacing: 16) {
                    // Benefits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Benefits")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        ForEach(getTierBenefits(tier: selectedTier), id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: selectedTier <= currentTier ? "checkmark.circle.fill" : "lock.circle.fill")
                                    .font(.body)
                                    .foregroundColor(selectedTier <= currentTier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                                
                                Text(benefit)
                                    .font(.body)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Requirements
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Requirements")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack {
                            Text("\(getActionsRequired(tier: selectedTier)) actions")
                                .font(.body)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Spacer()
                            Text("(2 hour cooldown)")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    
                    Divider()
                    
                    // Cost
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cost")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(KingdomTheme.Colors.gold)
                            Text("\(getCost(tier: selectedTier)) Gold")
                                .font(.body)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Spacer()
                            Text("Have: \(player.gold)")
                                .font(.body)
                                .foregroundColor(canAffordSelectedTier ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                        }
                    }
                    
                    // Purchase button - only show if this is the next tier
                    if selectedTier == currentTier + 1 && currentTier < 5 {
                        Button(action: {
                            onPurchase()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "person.fill.checkmark")
                                Text("Start Training")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isEnabled ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled)
                            .foregroundColor(KingdomTheme.Colors.parchmentLight)
                            .cornerRadius(12)
                        }
                        .disabled(!isEnabled)
                        
                        if hasActiveTraining {
                            Text("Complete your current training first")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if !canAffordSelectedTier {
                            Text("Insufficient gold")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else if selectedTier <= currentTier {
                        Text("Already unlocked")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else if selectedTier > currentTier + 1 {
                        Text("Complete Tier \(currentTier + 1) first")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else if currentTier >= 5 {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(KingdomTheme.Colors.gold)
                            Text("Maximum tier reached!")
                                .font(.body.bold())
                                .foregroundColor(KingdomTheme.Colors.gold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KingdomTheme.Colors.gold.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(KingdomTheme.Colors.parchmentLight)
                .cornerRadius(12)
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
