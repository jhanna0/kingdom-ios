import SwiftUI

/// Reusable profile header showing name, level, and optionally gold - brutalist style
/// Supports server-driven subscriber colors
struct ProfileHeaderCard: View {
    let displayName: String
    let level: Int
    let gold: Int?
    let rulerOf: String?
    
    // Server-driven subscriber customization (hex colors)
    let customization: APISubscriberCustomization?
    let isSubscriber: Bool
    
    init(
        displayName: String,
        level: Int,
        gold: Int? = nil,
        rulerOf: String? = nil,
        customization: APISubscriberCustomization? = nil,
        isSubscriber: Bool = false
    ) {
        self.displayName = displayName
        self.level = level
        self.gold = gold
        self.rulerOf = rulerOf
        self.customization = customization
        self.isSubscriber = isSubscriber
    }
    
    private var avatarBackgroundColor: Color {
        customization?.iconBackgroundColorValue ?? .white
    }
    
    private var avatarTextColor: Color {
        customization?.iconTextColorValue ?? .black
    }
    
    private var cardBackgroundColor: Color {
        customization?.cardBackgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    private var cardTextColor: Color {
        customization?.cardTextColorValue ?? KingdomTheme.Colors.inkDark
    }
    
    private var cardSecondaryTextColor: Color {
        // Slightly dimmed version of the card text color
        customization?.cardTextColorValue.opacity(0.7) ?? KingdomTheme.Colors.inkMedium
    }
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            ZStack(alignment: .bottomTrailing) {
                Text(String(displayName.prefix(1)).uppercased())
                    .font(FontStyles.displaySmall)
                    .foregroundColor(avatarTextColor)
                    .frame(width: 64, height: 64)
                    .brutalistBadge(backgroundColor: avatarBackgroundColor, cornerRadius: 16, shadowOffset: 3, borderWidth: 2.5)
                
                Text("\(level)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 13, shadowOffset: 2, borderWidth: 2)
                    .offset(x: 6, y: 6)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(FontStyles.headingLarge)
                        .foregroundColor(cardTextColor)
                        .lineLimit(2)
                    
                    if isSubscriber {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                    }
                }
                
                if let title = customization?.selectedTitle {
                    HStack(spacing: 4) {
                        Image(systemName: title.icon)
                            .font(.system(size: 12))
                        Text(title.displayName)
                            .font(FontStyles.bodySmall)
                    }
                    .foregroundColor(cardSecondaryTextColor)
                }
                
                if let kingdom = rulerOf {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                        Text("Ruler of \(kingdom)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(cardSecondaryTextColor)
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
