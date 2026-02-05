import SwiftUI

// MARK: - Earned Titles Card

struct EarnedTitlesCard: View {
    let groups: [AchievementGroup]
    var isLoading: Bool = false
    
    @State private var selectedCategory: String?
    
    private var totalCount: Int {
        groups.reduce(0) { $0 + $1.achievements.count }
    }
    
    private var filteredGroups: [AchievementGroup] {
        if let selected = selectedCategory {
            return groups.filter { $0.category == selected }
        }
        return groups
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.goldWarm)
                
                Text("Achieved Titles")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if totalCount > 0 {
                    Text("\(totalCount)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(KingdomTheme.Colors.inkMedium)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy.circle")
                        .font(.system(size: 36))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("No titles yet")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Claim achievements to earn titles!")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                
                // Achievements - horizontal scroll per category, no headers
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredGroups) { category in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(category.achievements) { achievement in
                                    HStack(spacing: 8) {
                                        Image(systemName: achievement.icon ?? "star.fill")
                                            .font(FontStyles.iconTiny)
                                            .foregroundColor(KingdomTheme.Colors.color(fromThemeName: achievement.color))
                                        
                                        Text(achievement.display_name)
                                            .font(FontStyles.bodyMedium)
                                            .foregroundColor(KingdomTheme.Colors.inkDark)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func categoryPill(id: String?, name: String, icon: String) -> some View {
        let isSelected = selectedCategory == id
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = id
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(FontStyles.labelBadge)
                
                Text(name)
                    .font(FontStyles.labelSmall)
            }
            .foregroundColor(isSelected ? .white : KingdomTheme.Colors.inkMedium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.parchment)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            EarnedTitlesCard(
                groups: [
                    AchievementGroup(
                        category: "hunting",
                        display_name: "Hunting",
                        icon: "scope",
                        achievements: [
                            PlayerAchievement(id: 1, achievement_type: "hunt_bear", tier: 3, display_name: "Bear Slayer III", icon: "flame.fill", category: "hunting", color: "red", claimed_at: nil),
                            PlayerAchievement(id: 2, achievement_type: "hunt_deer", tier: 5, display_name: "Deer Stalker V", icon: "leaf.fill", category: "hunting", color: "red", claimed_at: nil)
                        ]
                    ),
                    AchievementGroup(
                        category: "fishing",
                        display_name: "Fishing",
                        icon: "fish.fill",
                        achievements: [
                            PlayerAchievement(id: 3, achievement_type: "fish_caught", tier: 5, display_name: "Veteran Angler", icon: "fish.fill", category: "fishing", color: "royalBlue", claimed_at: nil)
                        ]
                    )
                ]
            )
        }
        .padding()
    }
    .background(KingdomTheme.Colors.parchment)
}
