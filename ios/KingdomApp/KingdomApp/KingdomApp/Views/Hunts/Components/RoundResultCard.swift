import SwiftUI

// MARK: - Round Result Card
// Compact card showing a single roll result

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
            
            VStack(spacing: 0) {
                Text("\(result.roll)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(resultColor)
                
                if result.is_critical {
                    Text("⚡").font(.system(size: 10))
                }
            }
        }
        .frame(width: 44, height: 44)
    }
    
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
