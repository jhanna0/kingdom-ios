import SwiftUI

/// Card displaying active bonuses and perks
struct ActivePerksCard: View {
    @ObservedObject var player: Player
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "star.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Active Bonuses")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if let perks = player.activePerks {
                VStack(spacing: 10) {
                    let allPerks = perks.combatPerks + perks.trainingPerks + perks.buildingPerks + 
                                   perks.espionagePerks + perks.politicalPerks + perks.travelPerks
                    
                    if allPerks.isEmpty {
                        emptyPerksView
                    } else {
                        ForEach(allPerks, id: \.id) { perk in
                            perkBadge(perk)
                        }
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var emptyPerksView: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.slash")
                .font(.system(size: 32))
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text("No Active Bonuses")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("Upgrade skills, equip items, and join kingdoms to gain bonuses")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private func perkBadge(_ perk: Player.PerkItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: perkIcon(for: perk))
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(
                    backgroundColor: perkColor(for: perk),
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                if let bonus = perk.bonus, let stat = perk.stat {
                    Text("\(bonus > 0 ? "+" : "")\(bonus) \(stat.capitalized)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                } else if let description = perk.description {
                    Text(description)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Text(perk.source)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                if let expiresAt = perk.expiresAt {
                    let remaining = expiresAt.timeIntervalSince(Date())
                    if remaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text(formatDuration(remaining))
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    private func perkIcon(for perk: Player.PerkItem) -> String {
        if perk.sourceType == "player_skill" {
            for (skillType, config) in SkillConfig.all {
                if perk.source.lowercased().contains(skillType) {
                    return config.icon
                }
            }
        }
        
        switch perk.sourceType {
        case "equipment":
            if perk.stat == "attack" {
                return SkillConfig.get("attack").icon
            } else {
                return SkillConfig.get("defense").icon
            }
        case "kingdom_building":
            if perk.source.contains("Education") {
                return "book.fill"
            } else if perk.source.contains("Farm") {
                return "leaf.fill"
            } else {
                return "building.2.fill"
            }
        case "property": return "house.fill"
        case "debuff": return "exclamationmark.triangle.fill"
        default: return "star.fill"
        }
    }
    
    private func perkColor(for perk: Player.PerkItem) -> Color {
        if let bonus = perk.bonus, bonus < 0 {
            return KingdomTheme.Colors.buttonDanger
        }
        
        if perk.sourceType == "player_skill" {
            for (skillType, config) in SkillConfig.all {
                if perk.source.lowercased().contains(skillType) {
                    return config.color
                }
            }
        }
        
        switch perk.sourceType {
        case "equipment":
            if perk.stat == "attack" {
                return SkillConfig.get("attack").color
            } else {
                return SkillConfig.get("defense").color
            }
        case "kingdom_building": return KingdomTheme.Colors.royalPurple
        case "property": return KingdomTheme.Colors.royalEmerald
        case "debuff": return KingdomTheme.Colors.buttonDanger
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

