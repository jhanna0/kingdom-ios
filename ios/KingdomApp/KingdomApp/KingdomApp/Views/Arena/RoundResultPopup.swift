import SwiftUI

// MARK: - Round Result Data
struct RoundResultData {
    let pushAmount: Double  // Positive = you pushed, negative = opponent pushed
    let outcome: String     // hit, critical, parried
    let myBestOutcome: String
    let oppBestOutcome: String
    let myStyle: String
    let oppStyle: String
    let roundNumber: Int
    let parried: Bool
}

// MARK: - Round Result Popup
struct RoundResultPopup: View {
    let data: RoundResultData
    let myColor: Color
    let enemyColor: Color
    let myName: String
    let opponentName: String
    let gameConfig: DuelGameConfig?
    let onDismiss: () -> Void
    
    // Animation state
    @State private var showContent = false
    @State private var showResult = false
    @State private var showPush = false
    @State private var animatedPush: Double = 0
    
    private var isParried: Bool { data.parried || abs(data.pushAmount) < 0.1 }
    private var iWon: Bool { data.pushAmount > 0 }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Round number
                Text("ROUND \(data.roundNumber) RESULTS")
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .opacity(showContent ? 1 : 0)
                
                // Head-to-head comparison
                HStack(spacing: 20) {
                    // YOUR SIDE
                    VStack(spacing: 8) {
                        Text("YOU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        
                        outcomeIcon(outcome: data.myBestOutcome, color: myColor, isWinner: iWon && !isParried)
                        
                        Text(data.myBestOutcome.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(outcomeColor(data.myBestOutcome))
                        
                        // Style used
                        styleChip(style: data.myStyle, color: myColor)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : -30)
                    
                    // VS / Result
                    VStack(spacing: 8) {
                        if showResult {
                            if isParried {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(KingdomTheme.Colors.disabled)
                                Text("PARRIED")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(KingdomTheme.Colors.disabled)
                            } else if iWon {
                                Image(systemName: "chevron.right.2")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(myColor)
                                Text("WIN")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(myColor)
                            } else {
                                Image(systemName: "chevron.left.2")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(enemyColor)
                                Text("LOSE")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(enemyColor)
                            }
                        } else {
                            Text("VS")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                        }
                    }
                    .frame(width: 60)
                    
                    // OPPONENT SIDE
                    VStack(spacing: 8) {
                        Text(opponentName.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                            .lineLimit(1)
                        
                        outcomeIcon(outcome: data.oppBestOutcome, color: enemyColor, isWinner: !iWon && !isParried)
                        
                        Text(data.oppBestOutcome.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(outcomeColor(data.oppBestOutcome))
                        
                        // Style used
                        styleChip(style: data.oppStyle, color: enemyColor)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : 30)
                }
                
                // Push amount
                if showPush {
                    VStack(spacing: 8) {
                        Text("BAR PUSH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        
                        Text(pushText)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(pushColor)
                            .contentTransition(.numericText())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Continue button
                Button(action: onDismiss) {
                    Text("CONTINUE")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(KingdomTheme.Colors.parchment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                    .fill(Color.black)
                                    .offset(x: 3, y: 3)
                                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                                    .fill(resultColor)
                                    .overlay(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall).stroke(Color.black, lineWidth: 2))
                            }
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .opacity(showPush ? 1 : 0)
            }
            .padding(24)
            .frame(width: 320)
            .background(
                ZStack {
                    // Brutalist offset shadow
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(Color.black)
                        .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                    // Parchment background
                    RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                                .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                        )
                }
            )
        }
        .onAppear {
            runAnimationSequence()
        }
    }
    
    private var pushText: String {
        if isParried {
            return "0%"
        } else if iWon {
            return "+\(String(format: "%.1f", animatedPush))%"
        } else {
            return "-\(String(format: "%.1f", abs(animatedPush)))%"
        }
    }
    
    private var pushColor: Color {
        if isParried { return KingdomTheme.Colors.disabled }
        return iWon ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private var resultColor: Color {
        if isParried { return KingdomTheme.Colors.buttonSecondary }
        return iWon ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private func runAnimationSequence() {
        // Stage 1: Content slides in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showContent = true
        }
        
        // Stage 2: Result appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showResult = true
            }
        }
        
        // Stage 3: Push amount animates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showPush = true
            }
            // Animate the number
            withAnimation(.easeOut(duration: 0.8)) {
                animatedPush = abs(data.pushAmount)
            }
        }
    }
    
    private func outcomeIcon(outcome: String, color: Color, isWinner: Bool) -> some View {
        let icon: String
        let iconColor: Color
        
        switch outcome.lowercased() {
        case "critical", "crit":
            icon = "star.fill"
            iconColor = KingdomTheme.Colors.imperialGold
        case "hit":
            icon = "checkmark.circle.fill"
            iconColor = KingdomTheme.Colors.buttonSuccess
        default:
            icon = "xmark.circle.fill"
            iconColor = KingdomTheme.Colors.disabled
        }
        
        return ZStack {
            // Brutalist shadow
            Circle()
                .fill(Color.black)
                .frame(width: 52, height: 52)
                .offset(x: 2, y: 2)
            
            Circle()
                .fill(KingdomTheme.Colors.parchmentLight)
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(iconColor, lineWidth: isWinner ? 3 : 2))
            
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(iconColor)
        }
        .scaleEffect(isWinner ? 1.1 : 1.0)
    }
    
    private func outcomeColor(_ outcome: String) -> Color {
        switch outcome.lowercased() {
        case "critical", "crit": return KingdomTheme.Colors.imperialGold
        case "hit": return KingdomTheme.Colors.buttonSuccess
        default: return KingdomTheme.Colors.disabled
        }
    }
    
    private func styleChip(style: String, color: Color) -> some View {
        let icon = gameConfig?.attackStyles?.first(where: { $0.id == style })?.icon ?? "equal.circle.fill"
        let name = gameConfig?.attackStyles?.first(where: { $0.id == style })?.name ?? style.capitalized
        
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(name.uppercased())
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(KingdomTheme.Colors.inkDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .offset(x: 1, y: 1)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
            }
        )
    }
}
