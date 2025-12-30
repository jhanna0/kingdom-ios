import SwiftUI

/// Reusable profile header showing name, level, and XP progress
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
        VStack(spacing: 12) {
            HStack {
                Text(displayName)
                    .font(.title2.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Level \(level)")
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
            
            // XP Progress Bar (only show if enabled)
            if showsXPBar {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Experience")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                        
                        Spacer()
                        
                        Text("\(experience) / \(maxExperience) XP")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            // Progress
                            Rectangle()
                                .fill(KingdomTheme.Colors.gold)
                                .frame(width: geometry.size.width * xpProgress, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
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

