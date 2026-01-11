import SwiftUI

// MARK: - Fighter Stats (for VS display)

struct FighterStats {
    let level: Int
    let reputation: Int
    let attack: Int
    let defense: Int
    let leadership: Int
    
    static let empty = FighterStats(level: 0, reputation: 0, attack: 0, defense: 0, leadership: 0)
    
    init(level: Int, reputation: Int, attack: Int, defense: Int, leadership: Int) {
        self.level = level
        self.reputation = reputation
        self.attack = attack
        self.defense = defense
        self.leadership = leadership
    }
    
    init(from stats: InitiatorStats) {
        self.level = stats.level
        self.reputation = stats.kingdomReputation
        self.attack = stats.attackPower
        self.defense = stats.defensePower
        self.leadership = stats.leadership
    }
    
    init(from participant: BattleParticipant) {
        self.level = participant.level
        self.reputation = participant.kingdomReputation
        self.attack = participant.attackPower
        self.defense = participant.defensePower
        self.leadership = participant.leadership
    }
}

// MARK: - Battle VS Poster View
/// Clean, cohesive VS poster for battle events (Coups & Invasions)
/// One unified card - no fragmented strips

struct BattleVsPosterView: View {
    // New unified initializer from BattleEventResponse
    let battle: BattleEventResponse
    let timeRemaining: String
    var onDismiss: (() -> Void)?
    
    // Computed properties from battle
    private var kingdomName: String { battle.kingdomName ?? "Kingdom" }
    private var challengerName: String { battle.initiatorName }
    private var rulerName: String { battle.rulerName ?? "The Crown" }
    private var attackerCount: Int { battle.attackerCount }
    private var defenderCount: Int { battle.defenderCount }
    private var status: String { battle.status }
    private var userSide: String? { battle.userSide }
    private var battleType: BattleType { battle.battleType }
    
    private var challengerStats: FighterStats {
        battle.initiatorStats.map { FighterStats(from: $0) } ?? .empty
    }
    
    private var rulerStats: FighterStats {
        battle.rulerStats.map { FighterStats(from: $0) } ?? .empty
    }
    
    // Battle-type aware labels
    private var battleTypeLabel: String { battleType.displayName.uppercased() }
    private var attackerLabel: String { battle.attackerLabel }
    private var defenderLabel: String { battle.defenderLabel }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row
            headerRow
            
            // Black separator
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Main VS content
            VStack(spacing: 0) {
                challengerSection
                vsDivider
                crownSection
            }
            .padding(.vertical, 8)
            
            // Black separator
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Footer row
            footerRow
        }
        .padding(16)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            // Battle type icon badge
            Image(systemName: status == "battle" ? "bolt.horizontal.fill" : battleType.icon)
                .font(FontStyles.iconTiny)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(backgroundColor: statusTint, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(battleTypeLabel)
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(2)
                Text(kingdomName)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status badge
            Text(status.uppercased())
                .font(FontStyles.labelBadge)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .brutalistBadge(backgroundColor: statusTint, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
            
            // Close button
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(FontStyles.iconTiny)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(width: 32, height: 32)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 16, shadowOffset: 2, borderWidth: 2)
                }
            }
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Challenger Section
    
    private var challengerSection: some View {
        VStack(spacing: 6) {
            // Role label
            Text("CHALLENGER")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                .tracking(2)
            
            // Name - BIG
            Text(challengerName)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Stats row
            HStack(spacing: 12) {
                if challengerStats.level > 0 {
                    statLabel(icon: "star.fill", value: "Lv.\(challengerStats.level)", color: KingdomTheme.Colors.gold)
                }
                if challengerStats.reputation > 0 {
                    statLabel(icon: "crown.fill", value: "\(challengerStats.reputation) rep", color: KingdomTheme.Colors.buttonSpecial)
                }
                statLabel(icon: "person.2.fill", value: "\(attackerCount)", color: KingdomTheme.Colors.buttonDanger)
            }
            .padding(.top, 2)
            
            // Icon
            Image(systemName: "figure.fencing")
                .font(.system(size: 48, weight: .black))
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    // MARK: - Crown Section
    
    private var crownSection: some View {
        VStack(spacing: 6) {
            // Icon
            Image(systemName: "crown.fill")
                .font(.system(size: 48, weight: .black))
                .foregroundColor(KingdomTheme.Colors.royalBlue)
                .padding(.bottom, 4)
            
            // Stats row
            HStack(spacing: 12) {
                if rulerStats.level > 0 {
                    statLabel(icon: "star.fill", value: "Lv.\(rulerStats.level)", color: KingdomTheme.Colors.gold)
                }
                if rulerStats.reputation > 0 {
                    statLabel(icon: "crown.fill", value: "\(rulerStats.reputation) rep", color: KingdomTheme.Colors.buttonSpecial)
                }
                statLabel(icon: "person.2.fill", value: "\(defenderCount)", color: KingdomTheme.Colors.royalBlue)
            }
            .padding(.bottom, 2)
            
            // Name - BIG
            Text(rulerName)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Role label
            Text("THE CROWN")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.royalBlue)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private func statLabel(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(FontStyles.iconMini)
            Text(value)
                .font(FontStyles.labelTiny)
        }
        .foregroundColor(color)
    }
    
    // MARK: - VS Divider
    
    private var vsDivider: some View {
        ZStack {
            Rectangle()
                .fill(KingdomTheme.Colors.border)
                .frame(height: 1)
            
            Text("VS")
                .font(FontStyles.headingLarge)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkDark, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
        }
    }
    
    // MARK: - Footer Row
    
    private var footerRow: some View {
        HStack(spacing: 12) {
            // Timer / Status
            HStack(spacing: 8) {
                Image(systemName: status == "battle" ? "bolt.horizontal.fill" : "hourglass")
                    .font(FontStyles.iconTiny)
                    .foregroundColor(status == "battle" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.inkMedium)
                
                VStack(alignment: .leading, spacing: 1) {
                    if status == "pledge" {
                        Text("PLEDGE ENDS")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .tracking(1)
                        Text(timeRemaining)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    } else if status == "battle" {
                        Text("BATTLE IN PROGRESS")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            .tracking(1)
                        Text("Awaiting resolution...")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else {
                        Text("FINISHED")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .tracking(1)
                        Text(timeRemaining)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
            }
            
            Spacer()
            
            // User side indicator
            if let side = userSide {
                pledgedBadge(side: side)
            }
        }
        .padding(.top, 12)
    }
    
    private func pledgedBadge(side: String) -> some View {
        let isAttacker = side.lowercased().contains("attack")
        let tint = isAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        let icon = isAttacker ? "figure.fencing" : "shield.fill"
        let label = isAttacker ? "ATTACKING" : "DEFENDING"
        
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(FontStyles.iconMini)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            Image(systemName: icon)
                .font(FontStyles.iconMini)
                .foregroundColor(tint)
            Text(label)
                .font(FontStyles.labelBadge)
                .foregroundColor(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    // MARK: - Helpers
    
    private var statusTint: Color {
        switch status.lowercased() {
        case "battle": return KingdomTheme.Colors.buttonDanger
        case "resolved": return KingdomTheme.Colors.buttonSuccess
        default: return KingdomTheme.Colors.buttonSpecial
        }
    }
}

// MARK: - Pledge Choice Card

struct BattlePledgeChoiceCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(isSelected ? .white : tint)
                    .frame(width: 56, height: 56)
                    .brutalistBadge(
                        backgroundColor: isSelected ? tint : KingdomTheme.Colors.parchment,
                        cornerRadius: 12,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(subtitle)
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(tint)
                } else {
                    Circle()
                        .stroke(KingdomTheme.Colors.border, lineWidth: 3)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .brutalistCard(
                backgroundColor: KingdomTheme.Colors.parchmentLight
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Map Badge View

struct BattleMapBadgeView: View {
    let battleType: BattleType
    let status: String
    let timeRemaining: String
    let attackerCount: Int
    let defenderCount: Int
    let onTap: () -> Void
    
    @State private var shimmerOffset: CGFloat = -100
    
    private let size: CGFloat = 70
    
    private var isBattle: Bool { status == "battle" }
    
    /// Display text: time remaining in pledge phase, "BATTLE" in battle phase
    private var displayText: String {
        if isBattle {
            return "BATTLE"
        }
        return timeRemaining
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main square
                RoundedRectangle(cornerRadius: 14)
                    .fill(statusTint)
                    .frame(width: size, height: size)
                    .overlay(
                        // Shimmer effect
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.4),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .mask(
                                RoundedRectangle(cornerRadius: 14)
                                    .frame(width: size, height: size)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black, lineWidth: 3)
                    )
                
                // Content
                VStack(spacing: 3) {
                    Text(battleType.displayName.uppercased())
                        .font(FontStyles.labelBadge)
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1)
                    
                    Image(systemName: isBattle ? "bolt.horizontal.fill" : battleType.icon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                    
                    Text(displayText)
                        .font(.system(size: 10, weight: .bold, design: isBattle ? .serif : .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 100
            }
        }
    }
    
    private var statusTint: Color {
        if battleType == .invasion {
            return isBattle ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        }
        return isBattle ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.buttonSpecial
    }
}

// Backwards compatible alias
typealias CoupMapBadgeView = BattleMapBadgeView

// Backwards compatible alias
typealias CoupVsPosterView = BattleVsPosterView

// MARK: - Preview

#Preview("VS Poster") {
    ZStack {
        KingdomTheme.Colors.parchment.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 20) {
                // Preview would need a mock BattleEventResponse
                Text("BattleVsPosterView Preview")
                    .font(FontStyles.headingMedium)
                
                BattleMapBadgeView(
                    battleType: .coup,
                    status: "pledge",
                    timeRemaining: "2h 45m",
                    attackerCount: 5,
                    defenderCount: 3,
                    onTap: {}
                )
                
                BattleMapBadgeView(
                    battleType: .invasion,
                    status: "battle",
                    timeRemaining: "",
                    attackerCount: 12,
                    defenderCount: 8,
                    onTap: {}
                )
            }
            .padding()
        }
    }
}

#Preview("Pledge Cards") {
    ZStack {
        KingdomTheme.Colors.parchment.ignoresSafeArea()
        
        VStack(spacing: 12) {
            BattlePledgeChoiceCard(
                title: "ATTACKERS",
                subtitle: "Join the revolt",
                icon: "figure.fencing",
                tint: KingdomTheme.Colors.buttonDanger,
                isSelected: true,
                onTap: {}
            )
            
            BattlePledgeChoiceCard(
                title: "DEFENDERS",
                subtitle: "Protect the crown",
                icon: "shield.fill",
                tint: KingdomTheme.Colors.royalBlue,
                isSelected: false,
                onTap: {}
            )
        }
        .padding()
    }
}
