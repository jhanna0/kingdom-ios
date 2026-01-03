import SwiftUI

/// Reusable profile header showing name, level, and optionally gold - brutalist style
struct ProfileHeaderCard: View {
    let displayName: String
    let level: Int
    let gold: Int?  // Optional - only shown for own profile
    let rulerOf: String?  // Optional - kingdom name if they're a ruler
    
    init(displayName: String, level: Int, gold: Int? = nil, rulerOf: String? = nil) {
        self.displayName = displayName
        self.level = level
        self.gold = gold
        self.rulerOf = rulerOf
    }
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Avatar with level badge
            ZStack(alignment: .bottomTrailing) {
                Text(String(displayName.prefix(1)).uppercased())
                    .font(FontStyles.displaySmall)
                    .foregroundColor(.black)
                    .frame(width: 64, height: 64)
                    .brutalistBadge(
                        backgroundColor: .white,
                        cornerRadius: 16,
                        shadowOffset: 3,
                        borderWidth: 2.5
                    )
                
                // Level badge
                Text("\(level)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonPrimary,
                        cornerRadius: 13,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                    .offset(x: 6, y: 6)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(2)
                
                // Ruler status if provided
                if let kingdom = rulerOf {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        
                        Text("Ruler of \(kingdom)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                // Gold display (only if provided)
                // if let gold = gold {
                //     HStack(spacing: 4) {
                //         Text("\(gold)")
                //             .font(FontStyles.bodyMediumBold)
                //             .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                //         Image(systemName: "g.circle.fill")
                //             .font(FontStyles.iconMini)
                //             .foregroundColor(KingdomTheme.Colors.goldLight)
                //     }
                // }
            }
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ProfileHeaderCard(
            displayName: "Alice",
            level: 5,
            gold: 1250
        )
        
        ProfileHeaderCard(
            displayName: "Bob",
            level: 12,
            gold: 5780
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
