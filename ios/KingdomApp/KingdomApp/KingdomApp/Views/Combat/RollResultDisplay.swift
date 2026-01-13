import SwiftUI

// MARK: - Roll Result Display
/// Shows the outcome of a combat roll with animation

struct RollResultDisplay: View {
    let outcome: CombatOutcome
    let rollValue: Int?
    let message: String?
    let pushAmount: Double?
    
    /// Animate entrance
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Outcome emoji/icon
            Text(outcome.emoji)
                .font(.system(size: 32))
                .scaleEffect(appeared ? 1.0 : 0.5)
            
            VStack(alignment: .leading, spacing: 2) {
                // Outcome label
                Text(outcome.label)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(outcome.color)
                
                // Message or push amount
                if let msg = message {
                    Text(msg)
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                } else if let push = pushAmount, push > 0 {
                    Text("Bar moved \(Int(push))%")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Spacer()
            
            // Roll value
            if let roll = rollValue {
                Text("\(roll)")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(outcome.color)
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(outcome.color, lineWidth: 2)
        )
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: - Combat Outcome

enum CombatOutcome: String, Codable {
    case miss
    case hit
    case critical
    case injure  // Alias for critical in battles
    
    var emoji: String {
        switch self {
        case .miss: return "💨"
        case .hit: return "⚔️"
        case .critical, .injure: return "💥"
        }
    }
    
    var label: String {
        switch self {
        case .miss: return "MISS"
        case .hit: return "HIT"
        case .critical: return "CRITICAL"
        case .injure: return "INJURE"
        }
    }
    
    var color: Color {
        switch self {
        case .miss: return .gray
        case .hit: return KingdomTheme.Colors.buttonSuccess
        case .critical, .injure: return .yellow
        }
    }
    
    /// Create from string (handles backend variations)
    static func from(_ string: String) -> CombatOutcome {
        switch string.lowercased() {
        case "miss": return .miss
        case "hit": return .hit
        case "critical", "crit": return .critical
        case "injure": return .injure
        default: return .miss
        }
    }
}

// MARK: - Compact Roll Result (for history)

struct CompactRollResult: View {
    let outcome: CombatOutcome
    let rollValue: Int
    let isSuccess: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(outcome.emoji)
                .font(.system(size: 20))
            
            Text("\(rollValue)")
                .font(FontStyles.labelTiny)
                .foregroundColor(outcome.color)
        }
        .frame(width: 44, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSuccess ? outcome.color.opacity(0.2) : KingdomTheme.Colors.parchmentLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSuccess ? outcome.color : Color.black.opacity(0.2), lineWidth: 1.5)
        )
    }
}

// MARK: - Roll History Row

struct RollHistoryRow: View {
    let results: [RollHistoryItem]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(results) { result in
                    CompactRollResult(
                        outcome: result.outcome,
                        rollValue: result.rollValue,
                        isSuccess: result.isSuccess
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 52)
    }
}

struct RollHistoryItem: Identifiable {
    let id = UUID()
    let outcome: CombatOutcome
    let rollValue: Int
    let isSuccess: Bool
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RollResultDisplay(
            outcome: .miss,
            rollValue: 23,
            message: nil,
            pushAmount: nil
        )
        
        RollResultDisplay(
            outcome: .hit,
            rollValue: 67,
            message: nil,
            pushAmount: 10
        )
        
        RollResultDisplay(
            outcome: .critical,
            rollValue: 95,
            message: "Critical strike!",
            pushAmount: 15
        )
        
        RollHistoryRow(results: [
            RollHistoryItem(outcome: .miss, rollValue: 12, isSuccess: false),
            RollHistoryItem(outcome: .hit, rollValue: 56, isSuccess: true),
            RollHistoryItem(outcome: .hit, rollValue: 78, isSuccess: true),
            RollHistoryItem(outcome: .critical, rollValue: 94, isSuccess: true),
        ])
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
