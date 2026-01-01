import SwiftUI

/// Reusable combat stats display card
struct CombatStatsCard: View {
    let attackPower: Int
    let defensePower: Int
    let leadership: Int
    let buildingSkill: Int
    let intelligence: Int?  // Optional for backwards compatibility
    
    let weaponBonus: Int?
    let armorBonus: Int?
    
    let isInteractive: Bool  // Whether skills are tappable (for training)
    let onSkillTap: ((String) -> Void)?
    
    init(
        attackPower: Int,
        defensePower: Int,
        leadership: Int,
        buildingSkill: Int,
        intelligence: Int? = nil,
        weaponBonus: Int? = nil,
        armorBonus: Int? = nil,
        isInteractive: Bool = false,
        onSkillTap: ((String) -> Void)? = nil
    ) {
        self.attackPower = attackPower
        self.defensePower = defensePower
        self.leadership = leadership
        self.buildingSkill = buildingSkill
        self.intelligence = intelligence
        self.weaponBonus = weaponBonus
        self.armorBonus = armorBonus
        self.isInteractive = isInteractive
        self.onSkillTap = onSkillTap
    }
    
    private var totalAttack: Int {
        attackPower + (weaponBonus ?? 0)
    }
    
    private var totalDefense: Int {
        defensePower + (armorBonus ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat & Skills")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(spacing: 8) {
                // Attack Power
                skillRow(
                    iconName: "bolt.fill",
                    displayName: "Attack Power",
                    baseStat: attackPower,
                    bonus: weaponBonus,
                    skillKey: "attack"
                )
                
                // Defense Power
                skillRow(
                    iconName: "shield.fill",
                    displayName: "Defense Power",
                    baseStat: defensePower,
                    bonus: armorBonus,
                    skillKey: "defense"
                )
                
                // Leadership
                skillRow(
                    iconName: "crown.fill",
                    displayName: "Leadership",
                    baseStat: leadership,
                    bonus: nil,
                    skillKey: "leadership"
                )
                
                // Building Skill
                skillRow(
                    iconName: "hammer.fill",
                    displayName: "Building Skill",
                    baseStat: buildingSkill,
                    bonus: nil,
                    skillKey: "building"
                )
                
                // Intelligence (if available)
                if let intelligence = intelligence {
                    skillRow(
                        iconName: "brain.head.profile",
                        displayName: "Intelligence",
                        baseStat: intelligence,
                        bonus: nil,
                        skillKey: "intelligence"
                    )
                }
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func skillRow(
        iconName: String,
        displayName: String,
        baseStat: Int,
        bonus: Int?,
        skillKey: String
    ) -> some View {
        Button(action: {
            if isInteractive {
                onSkillTap?(skillKey)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let bonus = bonus, bonus > 0 {
                        Text("\(baseStat) base + \(bonus) equipment")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let bonus = bonus, bonus > 0 {
                        Text("\(baseStat + bonus)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(KingdomTheme.Colors.gold)
                    } else {
                        Text("T\(baseStat)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                    
                    if isInteractive {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                    }
                }
            }
            .padding()
            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!isInteractive)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Non-interactive (for viewing other players)
        CombatStatsCard(
            attackPower: 5,
            defensePower: 4,
            leadership: 3,
            buildingSkill: 6,
            intelligence: 2,
            weaponBonus: 3,
            armorBonus: 2,
            isInteractive: false
        )
        
        // Interactive (for your own character)
        CombatStatsCard(
            attackPower: 3,
            defensePower: 3,
            leadership: 2,
            buildingSkill: 4,
            isInteractive: true,
            onSkillTap: { skill in
                print("Tapped \(skill)")
            }
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}



