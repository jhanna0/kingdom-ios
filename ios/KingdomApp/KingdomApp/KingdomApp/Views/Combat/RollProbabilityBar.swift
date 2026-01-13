import SwiftUI

// MARK: - Roll Probability Bar
/// Shows hit/miss/critical zones for combat rolls
/// Used in battles, hunts, and duels

struct RollProbabilityBar: View {
    /// Miss chance (0-100)
    let missChance: Int
    
    /// Hit chance (0-100)
    let hitChance: Int
    
    /// Critical/Injure chance (0-100)
    var critChance: Int { 100 - missChance - hitChance }
    
    /// Current roll marker position (0-100), nil to hide
    var rollMarkerValue: Double? = nil
    
    /// Whether roll animation is running
    var isAnimating: Bool = false
    
    /// Label for the critical zone
    var critLabel: String = "CRIT"
    
    /// Colors
    static let missColor = Color.gray.opacity(0.4)
    static let hitColor = KingdomTheme.Colors.buttonSuccess
    static let critColor = Color.yellow
    
    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text(isAnimating ? "ROLLING..." : (rollMarkerValue != nil ? "YOUR ROLL" : "ATTACK ODDS"))
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Spacer()
                
                if let roll = rollMarkerValue, !isAnimating {
                    Text("Rolled: \(Int(roll))")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(rollOutcomeColor(roll))
                }
            }
            
            // The bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Zones: MISS | HIT | CRIT
                    HStack(spacing: 0) {
                        // MISS zone (left)
                        Rectangle()
                            .fill(Self.missColor)
                            .frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        
                        // HIT zone (middle)
                        Rectangle()
                            .fill(Self.hitColor)
                            .frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        
                        // CRIT zone (right)
                        Rectangle()
                            .fill(Self.critColor)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Border
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
                    
                    // Zone labels
                    HStack(spacing: 0) {
                        if missChance > 15 {
                            Text("MISS")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(.white)
                                .frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        } else {
                            Spacer()
                                .frame(width: CGFloat(missChance) / 100.0 * geo.size.width)
                        }
                        
                        if hitChance > 15 {
                            Text("HIT")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(.white)
                                .frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        } else {
                            Spacer()
                                .frame(width: CGFloat(hitChance) / 100.0 * geo.size.width)
                        }
                        
                        if critChance > 10 {
                            Text(critLabel)
                                .font(FontStyles.labelTiny)
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                    }
                    
                    // Roll marker
                    if let roll = rollMarkerValue {
                        RollMarker(value: roll, barWidth: geo.size.width)
                    }
                }
            }
            .frame(height: 28)
            
            // Percentage labels
            HStack {
                Text("\(missChance)% miss")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                Spacer()
                
                Text("\(hitChance)% hit")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(Self.hitColor)
                
                Spacer()
                
                Text("\(critChance)% \(critLabel.lowercased())")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(Self.critColor)
            }
        }
    }
    
    private func rollOutcomeColor(_ roll: Double) -> Color {
        if roll < Double(missChance) {
            return .gray
        } else if roll < Double(missChance + hitChance) {
            return Self.hitColor
        } else {
            return Self.critColor
        }
    }
}

// MARK: - Roll Marker

struct RollMarker: View {
    let value: Double
    let barWidth: CGFloat
    
    var body: some View {
        let xPos = (value / 100.0) * barWidth
        
        VStack(spacing: 0) {
            // Triangle pointer
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
            
            // Line
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 28)
        }
        .shadow(color: .black, radius: 1, x: 0, y: 0)
        .offset(x: xPos - 6) // Center the marker
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        RollProbabilityBar(
            missChance: 50,
            hitChance: 40
        )
        
        RollProbabilityBar(
            missChance: 30,
            hitChance: 55,
            rollMarkerValue: 65
        )
        
        RollProbabilityBar(
            missChance: 60,
            hitChance: 30,
            rollMarkerValue: 25,
            critLabel: "INJURE"
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
