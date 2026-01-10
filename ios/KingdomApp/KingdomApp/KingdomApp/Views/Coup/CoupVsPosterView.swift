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
/// Smash Bros-style vertical "VS" fight poster for coup events
/// Challenger on top, VS in middle, Crown on bottom - centered and dramatic

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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header strip with kingdom name and status
            headerStrip
            
            // Main VS arena - vertical stack
            VStack(spacing: 0) {
                // Challenger (top)
                fighterSection(
                    role: "CHALLENGER",
                    name: challengerName,
                    icon: "figure.fencing",
                    tint: KingdomTheme.Colors.buttonDanger,
                    count: attackerCount,
                    countLabel: "ATTACKERS",
                    stats: challengerStats
                )
                
                // VS divider
                vsDivider
                
                // Crown (bottom)
                fighterSection(
                    role: "THE CROWN",
                    name: rulerName,
                    icon: "crown.fill",
                    tint: KingdomTheme.Colors.royalBlue,
                    count: defenderCount,
                    countLabel: "DEFENDERS",
                    stats: rulerStats
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        KingdomTheme.Colors.parchmentRich,
                        KingdomTheme.Colors.parchmentDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Timer strip
            timerStrip
        }
        .clipShape(RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                .stroke(Color.black, lineWidth: 3)
        )
        .background(
            RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                .fill(Color.black)
                .offset(x: 4, y: 4)
        )
    }
    
    // MARK: - Header Strip
    
    private var headerStrip: some View {
        HStack(spacing: 10) {
            // Coup icon
            Image(systemName: status == "battle" ? "bolt.horizontal.fill" : "bolt.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(statusTint)
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    }
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("COUP")
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(1)
                Text(kingdomName)
                    .font(.system(size: 16, weight: .black, design: .serif))
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
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(statusTint)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    }
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Fighter Section
    
    private func fighterSection(role: String, name: String, icon: String, tint: Color, count: Int, countLabel: String, stats: FighterStats) -> some View {
        VStack(spacing: 12) {
            // Big icon - the hero element
            Image(systemName: icon)
                .font(.system(size: 60, weight: .black))
                .foregroundColor(tint)
                .frame(width: 100, height: 80)
            
            // Name and role
            VStack(spacing: 4) {
                Text(role)
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(1)
                
                Text(name)
                    .font(.system(size: 18, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
            }
            
            // Stats pills - only Level and Rep for minimal clutter
            HStack(spacing: 8) {
                if stats.level > 0 {
                    statPill(label: "LV", value: "\(stats.level)", color: KingdomTheme.Colors.gold)
                }
                if stats.reputation > 0 {
                    statPill(label: "REP", value: "\(stats.reputation)", color: KingdomTheme.Colors.buttonSpecial)
                }
            }
            
            // Count badge - prominent
            countBadge(count: count, label: countLabel, tint: tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private func statPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .serif))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .offset(x: 1.5, y: 1.5)
                RoundedRectangle(cornerRadius: 8)
                    .fill(KingdomTheme.Colors.parchmentLight)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
            }
        )
    }
    
    private func countBadge(count: Int, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchmentLight)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(tint, lineWidth: 2)
            }
        )
    }
    
    // MARK: - VS Divider
    
    private var vsDivider: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(height: 2)
            
            // VS badge
            Text("VS")
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [KingdomTheme.Colors.inkDark, Color.black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KingdomTheme.Colors.imperialGold, lineWidth: 3)
                    }
                )
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Timer Strip
    
    private var timerStrip: some View {
        HStack(spacing: 12) {
            // Timer
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(status == "pledge" ? "PLEDGE ENDS" : (status == "resolved" ? "FINISHED" : "TIME LEFT"))
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text(timeRemaining)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
            }
            
            Spacer()
            
            // User side indicator (if pledged)
            if let side = userSide {
                pledgedBadge(side: side)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    private func pledgedBadge(side: String) -> some View {
        let isAttacker = side.lowercased().contains("attack")
        let tint = isAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        let icon = isAttacker ? "figure.fencing" : "shield.fill"
        let label = isAttacker ? "ATK" : "DEF"
        
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchmentLight)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(tint, lineWidth: 2)
            }
        )
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

// MARK: - Pledge Choice Card (Big & Bold)

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
                // Big icon
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(isSelected ? .white : tint)
                    .frame(width: 64, height: 64)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.black)
                                .offset(x: 2, y: 2)
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? tint : tint.opacity(0.15))
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(tint, lineWidth: 2)
                        }
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
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? tint.opacity(0.1) : KingdomTheme.Colors.parchmentLight)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? tint : Color.black, lineWidth: isSelected ? 3 : 2)
                }
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: status == "battle" ? "bolt.horizontal.fill" : "bolt.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                                .offset(x: 1.5, y: 1.5)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(statusTint)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                        }
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("COUP")
                            .font(.system(size: 10, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("•")
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text(status.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .foregroundColor(statusTint)
                    }
                    
                    HStack(spacing: 8) {
                        Text(timeRemaining)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Score
                        HStack(spacing: 4) {
                            Text("\(attackerCount)")
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text("–")
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Text("\(defenderCount)")
                                .foregroundColor(KingdomTheme.Colors.royalBlue)
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black)
                        .offset(x: 3, y: 3)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(KingdomTheme.Colors.parchmentLight)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black, lineWidth: 2)
                }
            )
        }
        .buttonStyle(.plain)
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
