import SwiftUI
import Combine

// MARK: - Duel Style Picker View

struct DuelStylePickerView: View {
    let roundNumber: Int
    let styles: [AttackStyleConfig]
    let expiresAt: String?
    let roundHistory: [DuelRoundHistoryEntry]
    let myName: String
    let opponentName: String
    let myColor: Color
    let enemyColor: Color
    let onSelectStyle: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ROUND \(roundNumber)")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if let expiresAt = expiresAt {
                    StylePhaseTimer(expiresAt: expiresAt)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // 2x3 grid
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(styles) { style in
                    StyleCard(style: style, color: myColor) {
                        onSelectStyle(style.id)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // History at bottom
            if !roundHistory.isEmpty {
                RoundHistoryCard(
                    history: roundHistory,
                    myName: myName,
                    opponentName: opponentName,
                    myColor: myColor,
                    enemyColor: enemyColor,
                    styles: styles
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .parchmentBackground()
    }
}

// MARK: - Style Card

private struct StyleCard: View {
    let style: AttackStyleConfig
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Icon + Name
                HStack(spacing: 10) {
                    Image(systemName: style.icon)
                        .font(FontStyles.iconMedium)
                        .foregroundColor(color)
                    
                    Text(style.name.uppercased())
                        .font(FontStyles.labelBlackSerif)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                }
                
                // Effects
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(style.effectsSummary.prefix(3), id: \.self) { effect in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(effectColor(effect))
                                .frame(width: 6, height: 6)
                            Text(effect)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    
                    if style.effectsSummary.isEmpty {
                        Text("No modifiers")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                }
                
                Spacer(minLength: 6)
                
                // Description
                Text(style.description)
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KingdomTheme.Colors.parchmentLight)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
    
    private func effectColor(_ effect: String) -> Color {
        if effect.contains("+") { return KingdomTheme.Colors.buttonSuccess }
        if effect.contains("-") && !effect.contains("Enemy") { return KingdomTheme.Colors.buttonWarning }
        if effect.contains("Enemy") { return KingdomTheme.Colors.royalBlue }
        if effect.contains("Win") { return KingdomTheme.Colors.gold }
        return KingdomTheme.Colors.inkLight
    }
}

// MARK: - Style Phase Timer

struct StylePhaseTimer: View {
    let expiresAt: String
    
    @State private var secondsRemaining: Int = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(FontStyles.iconTiny)
            Text("\(secondsRemaining)s")
                .font(FontStyles.statMedium)
        }
        .foregroundColor(secondsRemaining <= 3 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(KingdomTheme.Colors.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(secondsRemaining <= 3 ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.border, lineWidth: 2)
        )
        .onAppear { updateTimer() }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
    }
    
    private func updateTimer() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var expiry = formatter.date(from: expiresAt)
        if expiry == nil {
            formatter.formatOptions = [.withInternetDateTime]
            expiry = formatter.date(from: expiresAt)
        }
        
        if let exp = expiry {
            secondsRemaining = max(0, Int(exp.timeIntervalSinceNow))
        }
    }
}

// MARK: - Round History Card

struct RoundHistoryCard: View {
    let history: [DuelRoundHistoryEntry]
    let myName: String
    let opponentName: String
    let myColor: Color
    let enemyColor: Color
    let styles: [AttackStyleConfig]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY")
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            ForEach(history.suffix(3).reversed()) { round in
                roundRow(round)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    private func roundRow(_ round: DuelRoundHistoryEntry) -> some View {
        let myStyle = styles.first { $0.id == round.myStyle }
        let oppStyle = styles.first { $0.id == round.opponentStyle }
        
        return HStack(spacing: 10) {
            Text("R\(round.id)")
                .font(FontStyles.statSmall)
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .frame(width: 26)
            
            // My style
            Image(systemName: myStyle?.icon ?? "questionmark")
                .font(FontStyles.iconTiny)
                .foregroundColor(myColor)
            
            outcomeIcon(round.myBestOutcome)
            
            Text("vs")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            // Opponent style
            Image(systemName: oppStyle?.icon ?? "questionmark")
                .font(FontStyles.iconTiny)
                .foregroundColor(enemyColor)
            
            outcomeIcon(round.opponentBestOutcome)
            
            Spacer()
            
            // Result
            if round.parried {
                Text("TIE")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else if round.iWon {
                Text("+\(String(format: "%.1f", round.pushAmount))%")
                    .font(FontStyles.statMedium)
                    .foregroundColor(myColor)
            } else {
                Text("-\(String(format: "%.1f", round.pushAmount))%")
                    .font(FontStyles.statMedium)
                    .foregroundColor(enemyColor)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func outcomeIcon(_ outcome: String) -> some View {
        let (icon, color): (String, Color) = {
            switch outcome.lowercased() {
            case "critical": return ("star.fill", KingdomTheme.Colors.gold)
            case "hit": return ("checkmark.circle.fill", KingdomTheme.Colors.buttonSuccess)
            default: return ("xmark.circle.fill", KingdomTheme.Colors.inkLight)
            }
        }()
        
        return Image(systemName: icon)
            .font(FontStyles.iconMini)
            .foregroundColor(color)
    }
}

// MARK: - Round History Entry

struct DuelRoundHistoryEntry: Identifiable {
    let id: Int
    let myStyle: String
    let opponentStyle: String
    let myBestOutcome: String
    let opponentBestOutcome: String
    let winnerSide: String?
    let iWon: Bool
    let pushAmount: Double
    let parried: Bool
    let feintWinner: String?
}
