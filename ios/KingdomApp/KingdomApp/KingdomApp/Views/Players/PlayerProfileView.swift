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
                // Header with name, level, ruler status, and subscriber customization
                ProfileHeaderCard(
                    displayName: profile.display_name,
                    level: profile.level,
                    gold: nil,
                    rulerOf: profile.ruled_kingdom_name,
                    customization: profile.subscriber_customization,
                    isSubscriber: profile.isSubscriber
                )
                
                // Current Activity
                currentActivityCard(profile)
                
                // Combat & Skills - DYNAMIC from backend!
                ProfileSkillsCard(skills: profile.skills_data, reputation: profile.reputation)
                
                // Pets (only shown if user has membership - backend controls this)
                if let pets = profile.pets, !pets.isEmpty {
                    ProfilePetsCard(pets: pets, showEmpty: false)
                }
                
                // Earned Achievements (only shown if user has membership - backend controls this)
                if let groups = profile.achievement_groups, !groups.isEmpty {
                    EarnedTitlesCard(groups: groups)
                }
                
                // Achievement Stats
                achievementsCard(profile)
                
                // Actions (Trade button)
                actionsCard(profile)
            }
            .padding()
        }
    }
    
    private func actionsCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Actions")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Trade Button (requires Merchant skill)
            NavigationLink(destination: TradeOfferView(recipientId: userId, recipientName: profile.display_name)) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.buttonPrimary,
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trade")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("Send items or gold (Merchant T1 required)")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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
    
    private func achievementsCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Statistics")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
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

// MARK: - Profile Skills Card (Dynamic from backend, uses shared SkillGridItem)

struct ProfileSkillsCard: View {
    let skills: [PlayerPublicProfile.SkillData]
    let reputation: Int
    
    var body: some View {
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
            
            // Dynamic skills grid - 4 columns like CharacterSheet, uses SAME SkillGridItem!
            let sortedSkills = skills.sorted { $0.display_order < $1.display_order }
            
            VStack(spacing: 10) {
                ForEach(0..<rowCount(for: sortedSkills), id: \.self) { rowIndex in
                    skillRow(at: rowIndex, skills: sortedSkills)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func rowCount(for skills: [PlayerPublicProfile.SkillData]) -> Int {
        (skills.count + 4) / 4  // +4 to account for reputation slot
    }
    
    @ViewBuilder
    private func skillRow(at rowIndex: Int, skills: [PlayerPublicProfile.SkillData]) -> some View {
        let indices = (0..<4).map { rowIndex * 4 + $0 }
        
        HStack(spacing: 10) {
            ForEach(indices, id: \.self) { index in
                if index < skills.count {
                    // Use the SAME SkillGridItem from DynamicSkillGridContent!
                    SkillGridItem(
                        icon: skills[index].icon,
                        name: skills[index].display_name,
                        tier: skills[index].current_tier,
                        color: SkillConfig.get(skills[index].skill_type).color
                    )
                } else if index == skills.count {
                    // Reputation after last skill - uses SAME ReputationGridItem!
                    ReputationGridItem(reputation: reputation)
                } else {
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Profile Equipment Card

struct ProfileEquipmentCard: View {
    let equipment: PlayerEquipmentData
    
    var body: some View {
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
                ProfileEquipmentItem(
                    icon: "bolt.fill",
                    name: "Weapon",
                    tier: equipment.weapon_tier,
                    bonus: equipment.weapon_attack_bonus,
                    color: KingdomTheme.Colors.buttonDanger
                )
                
                ProfileEquipmentItem(
                    icon: "shield.fill",
                    name: "Armor",
                    tier: equipment.armor_tier,
                    bonus: equipment.armor_defense_bonus,
                    color: KingdomTheme.Colors.royalBlue
                )
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Profile Equipment Item

struct ProfileEquipmentItem: View {
    let icon: String
    let name: String
    let tier: Int?
    let bonus: Int?
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 26))
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
                        .font(.system(size: 12, weight: .bold))
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlayerProfileView(userId: 1)
    }
}
