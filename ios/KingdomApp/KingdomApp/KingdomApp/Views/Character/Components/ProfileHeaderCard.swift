import SwiftUI

/// Reusable profile header showing name, level, and XP progress - brutalist style
struct ProfileHeaderCard: View {
    let displayName: String
    let level: Int
    let experience: Int
    let maxExperience: Int
    let showsXPBar: Bool
    
    init(
        displayName: String,
        level: Int,
        experience: Int = 0,
        maxExperience: Int = 100,
        showsXPBar: Bool = true
    ) {
        self.displayName = displayName
        self.level = level
        self.experience = experience
        self.maxExperience = maxExperience
        self.showsXPBar = showsXPBar
    }
    
    private var xpProgress: Double {
        guard maxExperience > 0 else { return 0 }
        return Double(experience) / Double(maxExperience)
    }
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Avatar with level badge
            ZStack(alignment: .bottomTrailing) {
                Text(String(displayName.prefix(1)).uppercased())
                    .font(FontStyles.displaySmall)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.gold,
                        cornerRadius: 16,
                        shadowOffset: 3,
                        borderWidth: 2.5
                    )
                
                // Level badge
                Text("\(level)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonPrimary,
                        cornerRadius: 13,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                    .offset(x: 6, y: 6)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Text("Level \(level)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                
                // XP Progress Bar (only show if enabled)
                if showsXPBar {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(experience) / \(maxExperience) XP")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Spacer()
                            
                            Text("\(Int(xpProgress * 100))%")
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.gold)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                    .frame(height: 10)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.black, lineWidth: 1.5)
                                    )
                                
                                // Progress
                                Rectangle()
                                    .fill(KingdomTheme.Colors.gold)
                                    .frame(width: geometry.size.width * xpProgress, height: 10)
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // With XP bar
        ProfileHeaderCard(
            displayName: "Alice",
            level: 5,
            experience: 150,
            maxExperience: 300,
            showsXPBar: true
        )
        
        // Without XP bar (for viewing other players)
        ProfileHeaderCard(
            displayName: "Bob",
            level: 12,
            showsXPBar: false
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
