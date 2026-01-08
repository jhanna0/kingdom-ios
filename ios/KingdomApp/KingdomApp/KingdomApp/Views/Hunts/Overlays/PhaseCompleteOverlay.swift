import SwiftUI

// MARK: - Phase Complete Overlay
// Shows phase result with DRAMATIC styling matching CreatureRevealOverlay
// Big emoji, big text, animated entrance

struct PhaseCompleteOverlay: View {
    let phaseResult: PhaseResultData?
    let hunt: HuntSession?
    let onContinue: () -> Void
    
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var badgesOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    private var isHuntComplete: Bool {
        hunt?.isComplete == true || phaseResult?.huntPhase == .blessing
    }
    
    private var isSuccess: Bool {
        if let effects = phaseResult?.effects {
            if effects["killed"]?.boolValue == true { return true }
            if effects["escaped"]?.boolValue == true { return false }
            if effects["no_trail"]?.boolValue == true { return false }
            if effects["loot_success"]?.boolValue == true { return true }
            if let items = effects["items_dropped"]?.arrayValue, !items.isEmpty { return true }
        }
        return phaseResult?.group_roll.success_rate ?? 0 >= 0.5
    }
    
    private var currentPhase: HuntPhase {
        phaseResult?.huntPhase ?? .track
    }
    
    var body: some View {
        ZStack {
            // Solid parchment background
            KingdomTheme.Colors.parchmentLight
                .ignoresSafeArea()
            
            // Decorative corners
            decorativeCorners
            
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                Spacer()
                
                // BIG BANNER - "SLAIN!" / "ESCAPED!" / "BLESSED!" etc
                Text(bannerText)
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .tracking(6)
                    .foregroundColor(resultColor)
                    .opacity(textOpacity)
                
                // DRAMATIC icon display - matching CreatureRevealOverlay
                ZStack {
                    // Offset shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 204, height: 204)
                        .offset(x: 6, y: 6)
                    
                    // Main circle - SOLID parchment
                    Circle()
                        .fill(KingdomTheme.Colors.parchment)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(resultColor, lineWidth: 6)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 4)
                        )
                    
                    // THE BIG ICON/EMOJI
                    if currentPhase == .strike, let animal = hunt?.animal {
                        // Show the animal for strike results
                        Text(animal.icon ?? "🎯")
                            .font(.system(size: 100))
                    } else if currentPhase == .blessing {
                        // Blessing result icon
                        Text(blessingEmoji)
                            .font(.system(size: 100))
                    } else {
                        // Fallback icon
                        Image(systemName: resultIcon)
                            .font(.system(size: 80))
                            .foregroundColor(resultColor)
                    }
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                
                // Result text and details
                VStack(spacing: 16) {
                    // Animal name (for strike) or outcome message
                    if currentPhase == .strike, let animal = hunt?.animal {
                        Text(animal.name ?? "The Prey")
                            .font(.system(size: 36, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    } else {
                        Text(outcomeTitle)
                            .font(.system(size: 32, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    
                    // Subtitle/description
                    Text(outcomeSubtitle)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(textOpacity)
                
                // Stats/rewards badges
                if let effects = phaseResult?.effects {
                    resultBadges(effects)
                        .opacity(badgesOpacity)
                }
                
                Spacer()
                
                // Continue button
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 12) {
                        Text(buttonText)
                            .font(.system(size: 18, weight: .black))
                        Image(systemName: buttonIcon)
                            .font(.title3)
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: resultColor, foregroundColor: .white))
                .opacity(buttonOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    // MARK: - Computed Properties
    
    private var bannerText: String {
        if let effects = phaseResult?.effects {
            if effects["killed"]?.boolValue == true { return "SLAIN!" }
            if effects["escaped"]?.boolValue == true { return "ESCAPED!" }
            if effects["no_trail"]?.boolValue == true { return "LOST TRAIL" }
        }
        
        switch currentPhase {
        case .track: return isSuccess ? "FOUND!" : "NO TRACKS"
        case .strike: return isSuccess ? "SLAIN!" : "MISSED!"
        case .blessing: return isSuccess ? "BLESSED!" : "NO BLESSING"
        default: return isSuccess ? "SUCCESS!" : "FAILED"
        }
    }
    
    private var outcomeTitle: String {
        switch currentPhase {
        case .blessing:
            if let bonus = phaseResult?.effects?["loot_bonus"]?.doubleValue, bonus > 0 {
                return "+\(Int(bonus * 100))% Loot!"
            }
            return isSuccess ? "Loot Blessed" : "Prayers Unanswered"
        default:
            return phaseResult?.outcome_message ?? "Phase Complete"
        }
    }
    
    private var outcomeSubtitle: String {
        if let effects = phaseResult?.effects {
            if effects["killed"]?.boolValue == true {
                return "The hunt was successful!"
            }
            if effects["escaped"]?.boolValue == true {
                return "The prey got away..."
            }
        }
        
        switch currentPhase {
        case .blessing:
            return isSuccess ? "Your faith has been rewarded" : "The spirits did not answer"
        case .strike:
            return isSuccess ? "A clean kill!" : "Better luck next time"
        default:
            return ""
        }
    }
    
    private var blessingEmoji: String {
        if let bonus = phaseResult?.effects?["loot_bonus"]?.doubleValue {
            if bonus >= 0.5 { return "⚡" }
            if bonus >= 0.25 { return "🌟" }
            if bonus > 0 { return "✨" }
        }
        return "😶"
    }
    
    private var resultColor: Color {
        isSuccess ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private var resultIcon: String {
        isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var buttonText: String {
        if isHuntComplete {
            return "VIEW REWARDS"
        }
        return "CONTINUE"
    }
    
    private var buttonIcon: String {
        if isHuntComplete {
            return "trophy.fill"
        }
        return "arrow.right"
    }
    
    // MARK: - Result Badges
    
    @ViewBuilder
    private func resultBadges(_ effects: [String: AnyCodableValue]) -> some View {
        VStack(spacing: 12) {
            // Main stats row
            HStack(spacing: 20) {
                // Meat earned
                if let meat = effects["total_meat"]?.intValue, meat > 0 {
                    PhaseResultStatBadge(icon: "🥩", value: "\(meat)", label: "Meat", color: KingdomTheme.Colors.buttonSuccess)
                }
                
                // Damage dealt (for strike)
                if let damage = effects["total_damage"]?.intValue, damage > 0 {
                    PhaseResultStatBadge(icon: "⚔️", value: "\(damage)", label: "Damage", color: KingdomTheme.Colors.buttonDanger)
                }
                
                // Blessing bonus
                if let bonus = effects["loot_bonus"]?.doubleValue, bonus > 0 {
                    PhaseResultStatBadge(icon: "✨", value: "+\(Int(bonus * 100))%", label: "Bonus", color: KingdomTheme.Colors.regalPurple)
                }
            }
            
            // Items dropped
            if let items = effects["items_dropped"]?.arrayValue, !items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(items.compactMap { $0.stringValue }, id: \.self) { item in
                        let displayName = item.replacingOccurrences(of: "_", with: " ").capitalized
                        ItemBadge(name: displayName)
                    }
                }
            }
        }
    }
    
    // MARK: - Animation
    
    private func animateEntrance() {
        // Icon appears with spring
        withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.2)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Text fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
            textOpacity = 1.0
        }
        
        // Badges fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
            badgesOpacity = 1.0
        }
        
        // Button appears last
        withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
            buttonOpacity = 1.0
        }
    }
    
    // MARK: - Decorative Corners
    
    private var decorativeCorners: some View {
        GeometryReader { geo in
            Group {
                Image(systemName: decorativeIcon)
                    .font(.system(size: 40))
                    .foregroundColor(resultColor.opacity(0.2))
                    .position(x: 40, y: 60)
                
                Image(systemName: decorativeIcon)
                    .font(.system(size: 40))
                    .foregroundColor(resultColor.opacity(0.2))
                    .rotationEffect(.degrees(90))
                    .position(x: geo.size.width - 40, y: 60)
                
                Image(systemName: decorativeIcon)
                    .font(.system(size: 40))
                    .foregroundColor(resultColor.opacity(0.2))
                    .rotationEffect(.degrees(-90))
                    .position(x: 40, y: geo.size.height - 60)
                
                Image(systemName: decorativeIcon)
                    .font(.system(size: 40))
                    .foregroundColor(resultColor.opacity(0.2))
                    .rotationEffect(.degrees(180))
                    .position(x: geo.size.width - 40, y: geo.size.height - 60)
            }
        }
    }
    
    private var decorativeIcon: String {
        switch currentPhase {
        case .strike: return isSuccess ? "star.fill" : "leaf.fill"
        case .blessing: return "sparkle"
        default: return "leaf.fill"
        }
    }
}

// MARK: - Phase Result Stat Badge

private struct PhaseResultStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 24))
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color, lineWidth: 2)
                    )
            }
        )
    }
}

// MARK: - Item Badge

private struct ItemBadge: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gift.fill")
                .font(.caption)
            Text(name)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                Capsule()
                    .fill(KingdomTheme.Colors.gold)
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
}
