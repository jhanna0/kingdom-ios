import SwiftUI

// MARK: - Reusable Skill Grid Item (Display-only)

/// Reusable skill display - used by CharacterSheet AND PlayerProfile
struct SkillGridItem: View {
    let icon: String
    let name: String
    let tier: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(
                        backgroundColor: color,
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
            
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
    }
}

// MARK: - Reusable Reputation Grid Item

struct ReputationGridItem: View {
    let reputation: Int
    
    var body: some View {
        let tier = ReputationTier.from(reputation: reputation)
        
        VStack(spacing: 8) {
            Image(systemName: tier.icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .brutalistBadge(
                    backgroundColor: tier.color,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
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
}

// MARK: - Dynamic Skill Grid Content (for CharacterSheet with NavigationLinks)

/// Dynamic skill grid that renders skills from backend data
/// When backend adds a new skill, it automatically appears here without app update
struct DynamicSkillGridContent: View {
    let skills: [Player.SkillData]
    let trainingContracts: [TrainingContract]
    let player: Player
    let reputationButton: AnyView
    let onPurchase: (String) -> Void
    
    init(skills: [Player.SkillData], trainingContracts: [TrainingContract], player: Player, reputationButton: some View, onPurchase: @escaping (String) -> Void) {
        self.skills = skills
        self.trainingContracts = trainingContracts
        self.player = player
        self.reputationButton = AnyView(reputationButton)
        self.onPurchase = onPurchase
    }
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                skillRow(at: rowIndex)
            }
            
            // If number of skills doesn't fill last row, add reputation button
            if skills.count % 4 == 0 {
                HStack(spacing: 10) {
                    reputationButton
                    Spacer()
                        .frame(maxWidth: .infinity)
                    Spacer()
                        .frame(maxWidth: .infinity)
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private var rowCount: Int {
        (skills.count + 3) / 4
    }
    
    @ViewBuilder
    private func skillRow(at rowIndex: Int) -> some View {
        let indices = (0..<4).map { rowIndex * 4 + $0 }
        
        HStack(spacing: 10) {
            ForEach(indices, id: \.self) { index in
                if index < skills.count {
                    skillButton(for: skills[index])
                } else if index == skills.count {
                    // Add reputation button after last skill
                    reputationButton
                } else {
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func skillButton(for skill: Player.SkillData) -> some View {
        NavigationLink(destination: SkillDetailView(
            player: player,
            skillType: skill.skillType,
            trainingContracts: trainingContracts,
            onPurchase: { onPurchase(skill.skillType) }
        )) {
            SkillGridItem(
                icon: skill.icon,
                name: skill.displayName,
                tier: skill.currentTier,
                color: SkillConfig.get(skill.skillType).color
            )
        }
        .buttonStyle(.plain)
    }
}

