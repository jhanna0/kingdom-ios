import SwiftUI

// MARK: - Round Result Card
// Displays the result of a single roll attempt during a hunt phase

struct RoundResultCard: View {
    let result: PhaseRoundResult
    
    var body: some View {
        VStack(spacing: 6) {
            Text("R\(result.round)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            ZStack {
                // Card background with brutalist styling
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(cardBorder, lineWidth: 2)
                    )
                
                VStack(spacing: 2) {
                    Text("\(result.roll)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(resultColor)
                    
                    if result.is_critical {
                        Text("⚡")
                            .font(.caption)
                    }
                }
            }
            .frame(width: 60, height: 60)
            
            Text(result.is_success ? "+\(String(format: "%.1f", result.contribution))" : "—")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(result.is_success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
        }
    }
    
    private var cardBackground: Color {
        // SOLID colors - no opacity showing black through!
        if result.is_critical && result.is_success {
            // Gold-tinted parchment
            return Color(red: 0.95, green: 0.88, blue: 0.65)
        } else if result.is_success {
            // Green-tinted parchment
            return Color(red: 0.85, green: 0.92, blue: 0.82)
        } else if result.is_critical {
            // Red-tinted parchment
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
    
    private var resultColor: Color {
        if result.is_critical && result.is_success {
            return KingdomTheme.Colors.gold
        } else if result.is_success {
            return KingdomTheme.Colors.buttonSuccess
        } else if result.is_critical {
            return KingdomTheme.Colors.buttonDanger
        } else {
            return KingdomTheme.Colors.inkMedium
        }
    }
}
