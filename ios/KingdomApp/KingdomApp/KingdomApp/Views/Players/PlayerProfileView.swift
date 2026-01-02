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
                VStack {
                    ProgressView()
                    Text("Loading profile...")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .padding(.top, 8)
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
                // Header with name and level (no gold shown for other players)
                ProfileHeaderCard(
                    displayName: profile.display_name,
                    level: profile.level,
                    gold: nil  // Don't show other players' gold
                )
                
                // Location & Activity
                locationAndActivityCard(profile)
                
                // Reputation
                ReputationStatsCard(
                    reputation: profile.reputation,
                    honor: profile.honor,
                    showAbilities: false  // Don't show detailed abilities for others
                )
                
                // Combat Stats
                CombatStatsCard(
                    attackPower: profile.attack_power,
                    defensePower: profile.defense_power,
                    leadership: profile.leadership,
                    buildingSkill: profile.building_skill,
                    intelligence: profile.intelligence,
                    weaponBonus: profile.equipment.weapon_attack_bonus,
                    armorBonus: profile.equipment.armor_defense_bonus,
                    isInteractive: false  // Not interactive for other players
                )
                
                // Equipment
                EquipmentStatsCard(
                    weaponTier: profile.equipment.weapon_tier,
                    weaponBonus: profile.equipment.weapon_attack_bonus,
                    armorTier: profile.equipment.armor_tier,
                    armorBonus: profile.equipment.armor_defense_bonus,
                    isInteractive: false  // Not interactive for other players
                )
                
                // Achievements
                achievementsCard(profile)
            }
            .padding()
        }
    }
    
    private func locationAndActivityCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location & Activity")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Current Kingdom
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Location")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    if let kingdomName = profile.current_kingdom_name {
                        Text(kingdomName)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    } else {
                        Text("Unknown")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
            }
            .padding()
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
            
            // Current Activity
            HStack(spacing: 12) {
                Image(systemName: profile.activity.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .brutalistBadge(backgroundColor: activityColor(profile.activity.color), cornerRadius: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Activity")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text(profile.activity.displayText)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
            }
            .padding()
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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



