import SwiftUI

// MARK: - Success Chance Display
// Shows player's stat, success chance, and remaining attempts
// Universal component used across all hunt phases

struct SuccessChanceDisplay: View {
    let statName: String
    let statValue: Int
    let rollsRemaining: Int
    let maxRolls: Int
    
    // Calculate success chance based on stat (matches backend formula EXACTLY)
    // Backend: ROLL_BASE_CHANCE = 0.15, ROLL_SCALING_PER_LEVEL = 0.08
    // Formula: 15% + (8% * stat_level), clamped to 10%-95%
    private var successChance: Int {
        let base = 15 + (statValue * 8)
        return min(95, max(10, base))
    }
    
    private var statDisplayName: String {
        switch statName {
        case "intelligence": return "Intelligence"
        case "attack_power": return "Attack"
        case "faith": return "Faith"
        default: return statName.capitalized
        }
    }
    
    private var statIcon: String {
        switch statName {
        case "intelligence": return "brain.head.profile"
        case "attack_power": return "bolt.fill"
        case "faith": return "sparkles"
        default: return "star.fill"
        }
    }
    
    private var rollsUsed: Int {
        maxRolls - rollsRemaining
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Your stat - brutalist card style
            VStack(spacing: 4) {
                Image(systemName: statIcon)
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(statDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("\(statValue)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .frame(width: 80)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            )
            
            // Success chance - THE BIG NUMBER
            VStack(spacing: 4) {
                Text("HIT CHANCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                ZStack {
                    // Background bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 44)
                    
                    // Filled portion
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(chanceColor)
                            .frame(width: geo.size.width * CGFloat(successChance) / 100.0)
                    }
                    .frame(height: 44)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 3)
                        .frame(height: 44)
                    
                    // Percentage text
                    Text("\(successChance)%")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                }
                .frame(width: 140)
            }
            
            // Rolls remaining - compact display
            VStack(spacing: 4) {
                Text("ATTEMPTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Visual pip display (like Pokemon PP)
                HStack(spacing: 3) {
                    ForEach(0..<maxRolls, id: \.self) { i in
                        Circle()
                            .fill(i < rollsRemaining ? KingdomTheme.Colors.buttonSuccess : Color.black.opacity(0.2))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 1.5)
                            )
                    }
                }
                
                Text(rollsRemaining == 1 ? "1 left" : "\(rollsRemaining) left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(rollsRemaining <= 1 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium)
            }
            .frame(width: 80)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
    
    private var chanceColor: Color {
        if successChance >= 65 { return KingdomTheme.Colors.buttonSuccess }
        if successChance >= 45 { return KingdomTheme.Colors.buttonWarning }
        return KingdomTheme.Colors.buttonDanger
    }
}
