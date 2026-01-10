import SwiftUI

// MARK: - Round Result Card
// Compact card showing a single roll result
// Text color shows contribution: grey (miss) → green (hit) → blue (good) → purple (great) → gold (crit)

struct RoundResultCard: View {
    let result: PhaseRoundResult
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: 2, y: 2)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardBorder, lineWidth: 2)
                )
            
            Text("\(result.roll)")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(shiftColor)
        }
        .frame(width: 44, height: 44)
    }
    
    // Original background colors - these looked fine
    private var cardBackground: Color {
        if result.is_critical && result.is_success {
            return Color(red: 0.95, green: 0.88, blue: 0.65)
        } else if result.is_success {
            return Color(red: 0.85, green: 0.92, blue: 0.82)
        } else if result.is_critical {
            return Color(red: 0.95, green: 0.82, blue: 0.80)
        } else {
            return KingdomTheme.Colors.parchment
        }
    }
    
    private var cardBorder: Color {
        if result.is_critical {
            return result.is_success ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonDanger
        }
        return Color.black
    }
    
    // Text color based on contribution/shift amount
    private var shiftColor: Color {
        let shift = result.contribution
        
        if shift <= 0 {
            return KingdomTheme.Colors.inkMedium       // Miss - grey
        } else if shift >= 2.0 {
            return Color(hex: "#9C27B0")!              // Purple - great shift
        } else if shift >= 1.0 {
            return Color(hex: "#2196F3")!              // Blue - good shift
        } else {
            return KingdomTheme.Colors.buttonSuccess   // Green - basic hit
        }
    }
}
