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
    
    init(from participant: CoupParticipant) {
        self.level = participant.level
        self.reputation = participant.kingdomReputation
        self.attack = participant.attackPower
        self.defense = participant.defensePower
        self.leadership = participant.leadership
    }
}

// MARK: - Coup VS Poster View
/// Clean, cohesive VS poster for coup events
/// One unified card - no fragmented strips

struct CoupVsPosterView: View {
    let kingdomName: String
    let challengerName: String
    let rulerName: String
    let attackerCount: Int
    let defenderCount: Int
    let timeRemaining: String
    let status: String
    let userSide: String?
    
    // Fighter stats
    var challengerStats: FighterStats = .empty
    var rulerStats: FighterStats = .empty
    
    // Optional dismiss action
    var onDismiss: (() -> Void)?
    
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
            // Coup icon badge
            Image(systemName: status == "battle" ? "bolt.horizontal.fill" : "bolt.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(backgroundColor: statusTint, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("COUP")
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(2)
                Text(kingdomName)
                    .font(.system(size: 18, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status badge
            Text(status.uppercased())
                .font(.system(size: 10, weight: .black, design: .serif))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .brutalistBadge(backgroundColor: statusTint, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
            
            // Close button
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
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
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                .tracking(2)
            
            // Name - BIG
            Text(challengerName)
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Stats row
            if challengerStats.level > 0 || challengerStats.reputation > 0 {
                HStack(spacing: 12) {
                    if challengerStats.level > 0 {
                        statLabel(icon: "star.fill", value: "Lv.\(challengerStats.level)", color: KingdomTheme.Colors.gold)
                    }
                    if challengerStats.reputation > 0 {
                        statLabel(icon: "crown.fill", value: "\(challengerStats.reputation) rep", color: KingdomTheme.Colors.buttonSpecial)
                    }
                }
                .padding(.top, 2)
            }
            
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
            if rulerStats.level > 0 || rulerStats.reputation > 0 {
                HStack(spacing: 12) {
                    if rulerStats.level > 0 {
                        statLabel(icon: "star.fill", value: "Lv.\(rulerStats.level)", color: KingdomTheme.Colors.gold)
                    }
                    if rulerStats.reputation > 0 {
                        statLabel(icon: "crown.fill", value: "\(rulerStats.reputation) rep", color: KingdomTheme.Colors.buttonSpecial)
                    }
                }
                .padding(.bottom, 2)
            }
            
            // Name - BIG
            Text(rulerName)
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Role label
            Text("THE CROWN")
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.royalBlue)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private func statLabel(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .serif))
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
                .font(.system(size: 22, weight: .black, design: .serif))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkDark, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
        }
    }
    
    // MARK: - Footer Row
    
    private var footerRow: some View {
        HStack(spacing: 12) {
            // Timer
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(status == "pledge" ? "PLEDGE ENDS" : (status == "resolved" ? "FINISHED" : "BATTLE ENDS"))
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .tracking(1)
                    Text(timeRemaining)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
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
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 11, weight: .black, design: .serif))
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

struct CoupPledgeChoiceCard: View {
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
                        .font(.system(size: 16, weight: .black, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                } else {
                    Circle()
                        .stroke(KingdomTheme.Colors.border, lineWidth: 3)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .brutalistCard(
                backgroundColor: isSelected ? tint.opacity(0.1) : KingdomTheme.Colors.parchmentLight
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Map Badge View

struct CoupMapBadgeView: View {
    let status: String
    let timeRemaining: String
    let attackerCount: Int
    let defenderCount: Int
    let onTap: () -> Void
    
    @State private var shimmerOffset: CGFloat = -100
    
    private let size: CGFloat = 70
    
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
                    Text("COUP")
                        .font(.system(size: 10, weight: .black, design: .serif))
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1)
                    
                    Image(systemName: status == "battle" ? "bolt.horizontal.fill" : "bolt.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                    
                    Text(timeRemaining)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
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
        status == "battle" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.buttonSpecial
    }
}

// MARK: - Preview

#Preview("VS Poster") {
    ZStack {
        KingdomTheme.Colors.parchment.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 20) {
                CoupVsPosterView(
                    kingdomName: "San Francisco",
                    challengerName: "John the Bold",
                    rulerName: "King Marcus",
                    attackerCount: 5,
                    defenderCount: 3,
                    timeRemaining: "2h 45m",
                    status: "pledge",
                    userSide: nil,
                    challengerStats: FighterStats(level: 15, reputation: 650, attack: 12, defense: 10, leadership: 4),
                    rulerStats: FighterStats(level: 20, reputation: 800, attack: 5, defense: 15, leadership: 5)
                )
                
                CoupMapBadgeView(
                    status: "pledge",
                    timeRemaining: "2h 45m",
                    attackerCount: 5,
                    defenderCount: 3,
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
            CoupPledgeChoiceCard(
                title: "ATTACKERS",
                subtitle: "Join the revolt",
                icon: "figure.fencing",
                tint: KingdomTheme.Colors.buttonDanger,
                isSelected: true,
                onTap: {}
            )
            
            CoupPledgeChoiceCard(
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
