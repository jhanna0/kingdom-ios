import SwiftUI

/// Reusable reputation display card
struct ReputationStatsCard: View {
    let reputation: Int
    let honor: Int?  // Optional - not all contexts have honor
    let showAbilities: Bool  // Whether to show the ability unlocks
    
    init(reputation: Int, honor: Int? = nil, showAbilities: Bool = true) {
        self.reputation = reputation
        self.honor = honor
        self.showAbilities = showAbilities
    }
    
    private var reputationTier: ReputationTier {
        ReputationTier.from(reputation: reputation)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reputation")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reputationTier.displayName)
                        .font(.title3.bold())
                        .foregroundColor(reputationTier.color)
                    
                    HStack(spacing: 8) {
                        Text("\(reputation) reputation")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                        
                        if let honor = honor {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                            
                            Text("\(honor) honor")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: reputationTier.icon)
                    .font(.system(size: 40))
                    .foregroundColor(reputationTier.color)
            }
            
            if showAbilities {
                Divider()
                
                // Abilities unlocked
                VStack(alignment: .leading, spacing: 6) {
                    Text("Abilities:")
                        .font(.caption.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    abilityRow(
                        icon: "checkmark.circle.fill",
                        text: "Accept contracts",
                        unlocked: true
                    )
                    
                    abilityRow(
                        icon: "house.fill",
                        text: "Buy property",
                        unlocked: reputation >= 50
                    )
                    
                    abilityRow(
                        icon: "hand.raised.fill",
                        text: "Vote on coups",
                        unlocked: reputation >= 150
                    )
                    
                    abilityRow(
                        icon: "flag.fill",
                        text: "Propose coups",
                        unlocked: reputation >= 300
                    )
                    
                    abilityRow(
                        icon: "star.fill",
                        text: "Vote counts 2x",
                        unlocked: reputation >= 500
                    )
                    
                    abilityRow(
                        icon: "crown.fill",
                        text: "Vote counts 3x",
                        unlocked: reputation >= 1000
                    )
                }
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func abilityRow(icon: String, text: String, unlocked: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(unlocked ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(unlocked ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkDark.opacity(0.5))
            
            if !unlocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            }
        }
    }
}

// MARK: - Reputation Tier Helper

enum ReputationTier {
    case stranger
    case resident
    case citizen
    case notable
    case champion
    case legendary
    
    var displayName: String {
        switch self {
        case .stranger: return "Stranger"
        case .resident: return "Resident"
        case .citizen: return "Citizen"
        case .notable: return "Notable"
        case .champion: return "Champion"
        case .legendary: return "Legendary"
        }
    }
    
    var icon: String {
        switch self {
        case .stranger: return "person.fill"
        case .resident: return "house.fill"
        case .citizen: return "person.2.fill"
        case .notable: return "star.fill"
        case .champion: return "crown.fill"
        case .legendary: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .stranger: return .gray
        case .resident: return KingdomTheme.Colors.inkDark.opacity(0.7)
        case .citizen: return .blue
        case .notable: return .purple
        case .champion: return KingdomTheme.Colors.gold
        case .legendary: return .orange
        }
    }
    
    static func from(reputation: Int) -> ReputationTier {
        if reputation >= 1000 { return .legendary }
        if reputation >= 500 { return .champion }
        if reputation >= 300 { return .notable }
        if reputation >= 150 { return .citizen }
        if reputation >= 50 { return .resident }
        return .stranger
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ReputationStatsCard(reputation: 250, honor: 85, showAbilities: true)
        ReputationStatsCard(reputation: 750, showAbilities: false)
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}

