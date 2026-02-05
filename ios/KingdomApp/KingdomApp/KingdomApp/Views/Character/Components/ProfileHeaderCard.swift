import SwiftUI

/// Reusable profile header showing name, level, and optionally gold - brutalist style
/// Supports server-driven subscriber themes
struct ProfileHeaderCard: View {
    let displayName: String
    let level: Int
    let gold: Int?  // Optional - only shown for own profile
    let rulerOf: String?  // Optional - kingdom name if they're a ruler
    
    // Server-driven subscriber customization
    let subscriberTheme: APIThemeData?
    let selectedTitle: APITitleData?
    let isSubscriber: Bool
    
    init(
        displayName: String,
        level: Int,
        gold: Int? = nil,
        rulerOf: String? = nil,
        subscriberTheme: APIThemeData? = nil,
        selectedTitle: APITitleData? = nil,
        isSubscriber: Bool = false
    ) {
        self.displayName = displayName
        self.level = level
        self.gold = gold
        self.rulerOf = rulerOf
        self.subscriberTheme = subscriberTheme
        self.selectedTitle = selectedTitle
        self.isSubscriber = isSubscriber
    }
    
    // Server-driven colors with fallbacks
    private var avatarBackgroundColor: Color {
        subscriberTheme?.iconBackgroundColorValue ?? .white
    }
    
    private var avatarTextColor: Color {
        subscriberTheme?.textColorValue ?? .black
    }
    
    private var cardBackgroundColor: Color {
        subscriberTheme?.backgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    private var textColor: Color {
        subscriberTheme?.textColorValue ?? KingdomTheme.Colors.inkDark
    }
    
    private var secondaryTextColor: Color {
        subscriberTheme != nil ? textColor.opacity(0.7) : KingdomTheme.Colors.inkMedium
    }
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Avatar with level badge - themed
            ZStack(alignment: .bottomTrailing) {
                Text(String(displayName.prefix(1)).uppercased())
                    .font(FontStyles.displaySmall)
                    .foregroundColor(avatarTextColor)
                    .frame(width: 64, height: 64)
                    .brutalistBadge(
                        backgroundColor: avatarBackgroundColor,
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
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(FontStyles.headingLarge)
                        .foregroundColor(textColor)
                        .lineLimit(2)
                    
                    // Subscriber badge
                    if isSubscriber {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                    }
                }
                
                // Selected title from achievement
                if let title = selectedTitle {
                    HStack(spacing: 4) {
                        Image(systemName: title.icon)
                            .font(.system(size: 12))
                        Text(title.displayName)
                            .font(FontStyles.bodySmall)
                    }
                    .foregroundColor(secondaryTextColor)
                }
                
                // Ruler status if provided
                if let kingdom = rulerOf {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        
                        Text("Ruler of \(kingdom)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: cardBackgroundColor)
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
