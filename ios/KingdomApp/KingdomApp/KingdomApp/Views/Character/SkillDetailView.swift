import SwiftUI

struct SkillDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    private let tierManager = TierManager.shared
    
    let skillType: String
    let trainingContracts: [TrainingContract]
    let onPurchase: () -> Void
    
    // Optional: Tax rate from kingdom (0 if not provided - backwards compatible)
    var currentTaxRate: Int = 0
    
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
                        
                        // Training Cost Table
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(icon: "dollarsign.circle.fill", title: "Training Cost")
                            let actionsRequired = tierManager.trainingActionsFor(currentLevel: tier - 1)
                            let goldPerActionForTier = tierManager.trainingGoldFor(targetTier: tier)
                            let goldPerActionWithTaxForTier = goldPerActionForTier + (goldPerActionForTier * Double(currentTaxRate) / 100.0)
                            let totalGoldForTier = Int(Double(actionsRequired) * goldPerActionWithTaxForTier)
                            
                            VStack(spacing: 0) {
                                // Table header
                                HStack(spacing: 12) {
                                    Text("Tier")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .layoutPriority(2)
                                    
                                    Text("Skill Pts")
                                        .frame(width: 72, alignment: .center)
                                    
                                    Text("Actions")
                                        .frame(width: 72, alignment: .center)
                                    
                                    Text("Gold/Act")
                                        .frame(width: 88, alignment: .trailing)
                                }
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                
                                Divider()
                                    .overlay(Color.black.opacity(0.1))
                                
                                // Table row
                                HStack(spacing: 12) {
                                    Text("\(tier - 1) → \(tier)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .layoutPriority(2)
                                    
                                    Text("\(totalSkillPoints)")
                                        .frame(width: 72, alignment: .center)
                                    
                                    Text("\(actionsRequired)")
                                        .frame(width: 72, alignment: .center)
                                    
                                    Text("\(Int(goldPerActionForTier))g")
                                        .frame(width: 88, alignment: .trailing)
                                }
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .padding(.vertical, 2)
                            .padding(.top, 4)
                            
                            Text("Total cost is \(totalGoldForTier)g.\nSkills cost dramatically more over time. Choose your build wisely!")
                                .font(FontStyles.bodySmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                                .padding(.horizontal, 2)
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
                                    HapticService.shared.success()
                                    
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
                        Text("Training started! Complete actions to level up.")
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
    
    /// Total skill points across all skills (from server-driven skillsData)
    private var totalSkillPoints: Int {
        return player.skillsData.reduce(0) { $0 + $1.currentTier }
    }
    
    /// Gold cost per action based on this skill's target tier
    private var goldPerAction: Double {
        return tierManager.trainingGoldFor(targetTier: currentTier + 1)
    }
    
    /// Tax amount per action
    private var taxAmount: Double {
        return goldPerAction * Double(currentTaxRate) / 100.0
    }
    
    /// Gold cost per action with tax
    private var goldPerActionWithTax: Double {
        return goldPerAction + taxAmount
    }
    
    /// Build gold cost item with tax
    private func buildGoldCost() -> CostItemWithTax {
        return CostItemWithTax(
            icon: "g.circle.fill",
            baseAmount: goldPerAction,
            taxRate: currentTaxRate,
            color: KingdomTheme.Colors.goldLight,
            canAfford: player.gold >= Int(goldPerActionWithTax)
        )
    }
    
    private var canAffordSelectedTier: Bool {
        // Check if player can afford at least one action
        return player.gold >= Int(goldPerActionWithTax)
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
