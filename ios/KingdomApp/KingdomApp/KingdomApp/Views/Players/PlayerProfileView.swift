import SwiftUI

/// View for displaying another player's public profile
struct PlayerProfileView: View {
    let userId: Int
    @Environment(\.dismiss) var dismiss
    @State private var profile: PlayerPublicProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    KingdomTheme.Colors.parchment.ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(KingdomTheme.Colors.inkMedium)
                        
                        Text("Loading profile...")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20)
                    
                    Text("Failed to load profile")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(error)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await loadProfile()
                        }
                    }
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
                .padding()
            } else if let profile = profile {
                profileContent(profile)
            }
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Player Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadProfile()
        }
    }
    
    private func profileContent(_ profile: PlayerPublicProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with name, level, and ruler status
                ProfileHeaderCard(
                    displayName: profile.display_name,
                    level: profile.level,
                    gold: nil,  // Don't show other players' gold
                    rulerOf: profile.kingdoms_ruled > 0 ? profile.current_kingdom_name : nil
                )
                
                // Current Activity
                currentActivityCard(profile)
                
                // Combat & Skills
                combatSkillsCard(profile)
                
                // Equipment
                equipmentCard(profile)
                
                // Achievements
                achievementsCard(profile)
            }
            .padding()
        }
    }
    
    private func currentActivityCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: profile.activity.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Current Activity")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            HStack(spacing: 12) {
                Image(systemName: profile.activity.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: profile.activity.actualColor, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.activity.displayText)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let kingdomName = profile.current_kingdom_name {
                        Text("in \(kingdomName)")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func combatSkillsCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.fencing")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Combat & Skills")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Skills grid - 3 rows for all skills + reputation - FULLY DYNAMIC
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    skillDisplay(
                        icon: SkillConfig.get("attack").icon,
                        name: SkillConfig.get("attack").displayName,
                        value: profile.attack_power,
                        color: SkillConfig.get("attack").color
                    )
                    
                    skillDisplay(
                        icon: SkillConfig.get("defense").icon,
                        name: SkillConfig.get("defense").displayName,
                        value: profile.defense_power,
                        color: SkillConfig.get("defense").color
                    )
                }
                
                HStack(spacing: 10) {
                    skillDisplay(
                        icon: SkillConfig.get("leadership").icon,
                        name: SkillConfig.get("leadership").displayName,
                        value: profile.leadership,
                        color: SkillConfig.get("leadership").color
                    )
                    
                    skillDisplay(
                        icon: SkillConfig.get("building").icon,
                        name: SkillConfig.get("building").displayName,
                        value: profile.building_skill,
                        color: SkillConfig.get("building").color
                    )
                }
                
                HStack(spacing: 10) {
                    skillDisplay(
                        icon: SkillConfig.get("intelligence").icon,
                        name: SkillConfig.get("intelligence").displayName,
                        value: profile.intelligence,
                        color: SkillConfig.get("intelligence").color
                    )
                    
                    skillDisplay(
                        icon: SkillConfig.get("science").icon,
                        name: SkillConfig.get("science").displayName,
                        value: profile.science,
                        color: SkillConfig.get("science").color
                    )
                }
                
                HStack(spacing: 10) {
                    skillDisplay(
                        icon: SkillConfig.get("faith").icon,
                        name: SkillConfig.get("faith").displayName,
                        value: profile.faith,
                        color: SkillConfig.get("faith").color
                    )
                    
                    // Reputation display
                    let reputationTier = ReputationTier.from(reputation: profile.reputation)
                    VStack(spacing: 12) {
                        Image(systemName: reputationTier.icon)
                            .font(FontStyles.iconLarge)
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .brutalistBadge(
                                backgroundColor: reputationTier.color,
                                cornerRadius: 12,
                                shadowOffset: 3,
                                borderWidth: 2
                            )
                        
                        VStack(spacing: 2) {
                            Text("Reputation")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("\(profile.reputation) rep")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func skillDisplay(icon: String, name: String, value: Int, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .brutalistBadge(
                        backgroundColor: color,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                // Tier badge
                Text("\(value)")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .brutalistBadge(
                        backgroundColor: .black,
                        cornerRadius: 11,
                        shadowOffset: 1,
                        borderWidth: 1.5
                    )
                    .offset(x: 6, y: -6)
            }
            
            VStack(spacing: 2) {
                Text(name)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Tier \(value)/5")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
    }
    
    private func equipmentCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Equipment")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            HStack(spacing: 10) {
                equipmentDisplay(
                    icon: "bolt.fill",
                    name: "Weapon",
                    tier: profile.equipment.weapon_tier,
                    bonus: profile.equipment.weapon_attack_bonus,
                    color: KingdomTheme.Colors.buttonDanger
                )
                
                equipmentDisplay(
                    icon: "shield.fill",
                    name: "Armor",
                    tier: profile.equipment.armor_tier,
                    bonus: profile.equipment.armor_defense_bonus,
                    color: KingdomTheme.Colors.royalBlue
                )
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func equipmentDisplay(icon: String, name: String, tier: Int?, bonus: Int?, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .brutalistBadge(
                        backgroundColor: color,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                // Tier badge
                if let tier = tier {
                    Text("\(tier)")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .brutalistBadge(
                            backgroundColor: .black,
                            cornerRadius: 11,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                        .offset(x: 6, y: -6)
                }
            }
            
            VStack(spacing: 2) {
                Text(name)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let bonus = bonus {
                    Text("+\(bonus)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                } else {
                    Text("Not equipped")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
    }
    
    private func achievementsCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(spacing: 8) {
                achievementRow(
                    icon: "flag.fill",
                    title: "Kingdoms Ruled",
                    value: "\(profile.kingdoms_ruled)"
                )
                
                achievementRow(
                    icon: "crown.fill",
                    title: "Coups Won",
                    value: "\(profile.coups_won)"
                )
                
                achievementRow(
                    icon: "mappin.circle.fill",
                    title: "Total Check-ins",
                    value: "\(profile.total_checkins)"
                )
                
                achievementRow(
                    icon: "hammer.fill",
                    title: "Contracts Completed",
                    value: "\(profile.contracts_completed)"
                )
                
                achievementRow(
                    icon: "star.fill",
                    title: "Total Conquests",
                    value: "\(profile.total_conquests)"
                )
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func achievementRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            
            Text(title)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            Text(value)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding()
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
    
    private func loadProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let loadedProfile = try await KingdomAPIService.shared.player.getPlayerProfile(userId: userId)
            
            await MainActor.run {
                self.profile = loadedProfile
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlayerProfileView(userId: 1)
    }
}



