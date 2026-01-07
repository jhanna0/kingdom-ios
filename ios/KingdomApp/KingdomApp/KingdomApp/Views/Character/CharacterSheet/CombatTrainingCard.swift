import SwiftUI

/// Card displaying combat skills and training options
struct CombatTrainingCard: View {
    @ObservedObject var player: Player
    let trainingContracts: [TrainingContract]
    let isLoadingContracts: Bool
    let onPurchaseTraining: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "figure.fencing")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Combat & Skills")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Text("Tap a skill to view all tiers and purchase training")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // DYNAMIC skills grid - renders skills from backend!
            dynamicSkillsGrid
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Dynamic Skills Grid
    
    @ViewBuilder
    private var dynamicSkillsGrid: some View {
        if player.skillsData.isEmpty {
            // Fallback to hardcoded skills if backend hasn't sent skills_data yet
            fallbackSkillsGrid
        } else {
            // DYNAMIC: Render skills from backend data in 2-column grid
            DynamicSkillGridContent(
                skills: player.skillsData,
                trainingContracts: trainingContracts,
                player: player,
                reputationButton: reputationGridButton,
                onPurchase: onPurchaseTraining
            )
        }
    }
    
    private var fallbackSkillsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                skillGridButton(
                    iconName: SkillConfig.get("attack").icon,
                    displayName: SkillConfig.get("attack").displayName,
                    tier: player.attackPower,
                    skillType: "attack"
                )
                
                skillGridButton(
                    iconName: SkillConfig.get("defense").icon,
                    displayName: SkillConfig.get("defense").displayName,
                    tier: player.defensePower,
                    skillType: "defense"
                )
                
                skillGridButton(
                    iconName: SkillConfig.get("leadership").icon,
                    displayName: SkillConfig.get("leadership").displayName,
                    tier: player.leadership,
                    skillType: "leadership"
                )
                
                skillGridButton(
                    iconName: SkillConfig.get("building").icon,
                    displayName: SkillConfig.get("building").displayName,
                    tier: player.buildingSkill,
                    skillType: "building"
                )
            }
            
            HStack(spacing: 10) {
                skillGridButton(
                    iconName: SkillConfig.get("intelligence").icon,
                    displayName: SkillConfig.get("intelligence").displayName,
                    tier: player.intelligence,
                    skillType: "intelligence"
                )
                
                skillGridButton(
                    iconName: SkillConfig.get("science").icon,
                    displayName: SkillConfig.get("science").displayName,
                    tier: player.science,
                    skillType: "science"
                )
                
                skillGridButton(
                    iconName: SkillConfig.get("faith").icon,
                    displayName: SkillConfig.get("faith").displayName,
                    tier: player.faith,
                    skillType: "faith"
                )
                
                reputationGridButton
            }
        }
    }
    
    private var reputationGridButton: some View {
        let reputationTier = ReputationTier.from(reputation: player.reputation)
        
        return NavigationLink(destination: ReputationDetailView(player: player)) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: reputationTier.icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: reputationTier.color,
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                }
                
                Text("Reputation")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
        }
        .buttonStyle(.plain)
    }
    
    private func skillGridButton(
        iconName: String,
        displayName: String,
        tier: Int,
        skillType: String
    ) -> some View {
        NavigationLink(destination: SkillDetailView(
            player: player,
            skillType: skillType,
            trainingContracts: trainingContracts,
            onPurchase: {
                onPurchaseTraining(skillType)
            }
        )) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: SkillConfig.get(skillType).color,
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    Text("\(tier)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .brutalistBadge(
                            backgroundColor: .black,
                            cornerRadius: 10,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                        .offset(x: 5, y: -5)
                }
                
                Text(displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
        }
        .buttonStyle(.plain)
    }
}

