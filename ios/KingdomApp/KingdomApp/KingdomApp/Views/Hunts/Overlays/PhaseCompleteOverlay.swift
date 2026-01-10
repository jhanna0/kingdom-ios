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
                        // Show the animal for strike results - animals keep emojis
                        Text(animal.icon ?? "🎯")
                            .font(.system(size: 100))
                    } else if currentPhase == .blessing {
                        // Blessing result icon - SF Symbol with color
                        Image(systemName: blessingIcon)
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(blessingColor)
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
                    HStack(spacing: 8) {
                        Text(buttonText)
                            .font(FontStyles.headingSmall)
                        Image(systemName: buttonIcon)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: resultColor, foregroundColor: .white, fullWidth: true))
                .opacity(buttonOpacity)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
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
    
    private var blessingIcon: String {
        if let bonus = phaseResult?.effects?["loot_bonus"]?.doubleValue {
            if bonus >= 0.5 { return "star.fill" }
            if bonus >= 0.25 { return "sparkles" }
            if bonus > 0 { return "sparkle" }
        }
        return "hands.sparkles"
    }
    
    private var blessingColor: Color {
        if let bonus = phaseResult?.effects?["loot_bonus"]?.doubleValue {
            if bonus >= 0.5 { return KingdomTheme.Colors.gold }
            if bonus >= 0.25 { return KingdomTheme.Colors.regalPurple }
            if bonus > 0 { return KingdomTheme.Colors.royalPurple }
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private var resultColor: Color {
        isSuccess ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
    }
    
    private var resultIcon: String {
        isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var buttonText: String {
        if isHuntComplete {
            return "VIEW LOOT"
        }
        return "CONTINUE"
    }
    
    private var buttonIcon: String {
        if isHuntComplete {
            return "archivebox.fill"
        }
        return "arrow.right"
    }
    
    private var showRareChanceHint: Bool {
        currentPhase == .blessing && isSuccess
    }
    
    // MARK: - Result Badges
    
    @ViewBuilder
    private func resultBadges(_ effects: [String: AnyCodableValue]) -> some View {
        VStack(spacing: 12) {
            // Main stats row - using SF Symbols, no emojis!
            HStack(spacing: 20) {
                // Meat earned
                if let meat = effects["total_meat"]?.intValue, meat > 0 {
                    PhaseResultStatBadge(icon: "leaf.fill", value: "\(meat)", label: "Meat", color: KingdomTheme.Colors.buttonSuccess)
                }
                
                // Damage dealt (for strike)
                if let damage = effects["total_damage"]?.intValue, damage > 0 {
                    PhaseResultStatBadge(icon: "bolt.fill", value: "\(damage)", label: "Damage", color: KingdomTheme.Colors.buttonDanger)
                }
                
                // Blessing bonus
                if let bonus = effects["loot_bonus"]?.doubleValue, bonus > 0 {
                    PhaseResultStatBadge(icon: "sparkles", value: "+\(Int(bonus * 100))%", label: "Bonus", color: KingdomTheme.Colors.regalPurple)
                }
            }
            
            // Items dropped
            if let items = effects["items_dropped"]?.arrayValue, !items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(items.compactMap { $0.stringValue }, id: \.self) { item in
                        let displayName = item.replacingOccurrences(of: "_", with: " ").capitalized
                        let icon = item == "sinew" ? "waveform.path" : "cube.fill"
                        let color = item == "sinew" ? KingdomTheme.Colors.regalPurple : KingdomTheme.Colors.gold
                        ItemBadge(name: displayName, icon: icon, color: color)
                    }
                }
            }
            
            // Show rare loot chance hint for blessing - uses backend config
            if currentPhase == .blessing {
                if let bonus = effects["loot_bonus"]?.doubleValue, bonus > 0.2,
                   let rareItemName = effects["rare_item_name"]?.stringValue,
                   let rareItemIcon = effects["rare_item_icon"]?.stringValue {
                    RareLootHintCard(itemName: rareItemName, itemIcon: rareItemIcon)
                        .padding(.horizontal, 20)
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
    let icon: String  // SF Symbol name
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
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
    let icon: String
    let color: Color
    
    init(name: String, icon: String = "cube.fill", color: Color = KingdomTheme.Colors.gold) {
        self.name = name
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(name)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                Capsule()
                    .fill(color)
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
        )
    }
}

// MARK: - Rare Loot Hint Card

private struct RareLootHintCard: View {
    let itemName: String
    let itemIcon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: itemIcon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.regalPurple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("RARE DROP POSSIBLE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text(itemName)
                    .font(.system(size: 16, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(KingdomTheme.Colors.regalPurple.opacity(0.5))
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 12)
                    .fill(KingdomTheme.Colors.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KingdomTheme.Colors.regalPurple.opacity(0.5), lineWidth: 2)
                    )
            }
        )
    }
}
