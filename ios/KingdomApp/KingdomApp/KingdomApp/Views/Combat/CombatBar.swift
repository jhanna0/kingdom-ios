import SwiftUI

// MARK: - Unified Combat Bar
/// Reusable tug-of-war bar for battles, duels, hunts, etc.
/// Bar ranges 0-100. Each side "pushes" toward their goal.

struct CombatBar: View {
    /// Current bar value (0-100)
    let value: Double
    
    /// Animated value for smooth transitions
    @Binding var animatedValue: Double
    
    /// Left side label (wins when bar reaches 0)
    let leftLabel: String
    
    /// Right side label (wins when bar reaches 100)
    let rightLabel: String
    
    /// Left side color
    var leftColor: Color = KingdomTheme.Colors.royalBlue
    
    /// Right side color
    var rightColor: Color = KingdomTheme.Colors.buttonDanger
    
    /// Whether to show percentage labels
    var showPercentages: Bool = true
    
    /// Optional icon for left side
    var leftIcon: String? = nil
    
    /// Optional icon for right side
    var rightIcon: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // Labels
            HStack {
                HStack(spacing: 4) {
                    if let icon = leftIcon {
                        Image(systemName: icon)
                    }
                    Text(leftLabel)
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(leftColor)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(rightLabel)
                    if let icon = rightIcon {
                        Image(systemName: icon)
                    }
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(rightColor)
            }
            
            // The bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background (right side color)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rightColor.opacity(0.3))
                    
                    // Left side progress (inverted - left wins at 0)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(leftColor)
                        .frame(width: geo.size.width * (1 - animatedValue / 100))
                    
                    // Center marker
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 2)
                        .offset(x: geo.size.width / 2 - 1)
                }
            }
            .frame(height: 24)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
            
            // Percentage labels
            if showPercentages {
                HStack {
                    Text("\(Int(100 - animatedValue))%")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(leftColor)
                    
                    Spacer()
                    
                    Text("\(Int(animatedValue))%")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(rightColor)
                }
            }
        }
    }
}

// MARK: - Simple Combat Bar (no binding needed)
/// For static display or when you manage animation externally

struct SimpleCombatBar: View {
    let value: Double
    let leftLabel: String
    let rightLabel: String
    var leftColor: Color = KingdomTheme.Colors.royalBlue
    var rightColor: Color = KingdomTheme.Colors.buttonDanger
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(leftLabel)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(leftColor)
                Spacer()
                Text(rightLabel)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(rightColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(rightColor.opacity(0.3))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(leftColor)
                        .frame(width: geo.size.width * (1 - value / 100))
                }
            }
            .frame(height: 20)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        SimpleCombatBar(
            value: 50,
            leftLabel: "You",
            rightLabel: "Enemy"
        )
        
        SimpleCombatBar(
            value: 30,
            leftLabel: "ATTACKERS",
            rightLabel: "DEFENDERS",
            leftColor: .red,
            rightColor: .blue
        )
        
        SimpleCombatBar(
            value: 75,
            leftLabel: "Challenger",
            rightLabel: "Opponent"
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
