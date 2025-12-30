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
                        .font(.system(size: 60))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Failed to load profile")
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await loadProfile()
                        }
                    }
                    .font(KingdomTheme.Typography.body())
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
                // Header with name and level
                ProfileHeaderCard(
                    displayName: profile.display_name,
                    level: profile.level,
                    showsXPBar: false  // Don't show XP for other players
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
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Current Kingdom
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Location")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    if let kingdomName = profile.current_kingdom_name {
                        Text(kingdomName)
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    } else {
                        Text("Unknown")
                            .font(.subheadline)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
            .cornerRadius(8)
            
            // Current Activity
            HStack(spacing: 12) {
                Image(systemName: profile.activity.icon)
                    .font(.title3)
                    .foregroundColor(activityColor(profile.activity.color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Activity")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    Text(profile.activity.displayText)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
            }
            .padding()
            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func achievementsCard(_ profile: PlayerPublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
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
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func achievementRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(KingdomTheme.Colors.gold)
        }
        .padding()
        .background(KingdomTheme.Colors.inkDark.opacity(0.05))
        .cornerRadius(8)
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

