import SwiftUI

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityLogEntry
    let showUser: Bool
    
    // Server-driven theme colors
    private var cardBackgroundColor: Color {
        activity.subscriberTheme?.backgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    private var cardTextColor: Color {
        activity.subscriberTheme?.textColorValue ?? KingdomTheme.Colors.inkDark
    }
    
    private var secondaryTextColor: Color {
        activity.subscriberTheme != nil ? cardTextColor.opacity(0.7) : KingdomTheme.Colors.inkMedium
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon with brutalist badge
            Image(systemName: activity.icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(backgroundColor: activity.color, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
                
            VStack(alignment: .leading, spacing: 4) {
                // User name if showing friend activity
                if showUser, let displayName = activity.displayName {
                    HStack(spacing: 4) {
                        Text(displayName)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(cardTextColor)
                        
                        // Subscriber badge
                        if activity.subscriberTheme != nil {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                        }
                        
                        if let level = activity.userLevel {
                            Text("Lv\(level)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    
                    // Selected title from achievement
                    if let title = activity.selectedTitle {
                        HStack(spacing: 4) {
                            Image(systemName: title.icon)
                                .font(.system(size: 10))
                            Text(title.displayName)
                                .font(FontStyles.labelSmall)
                        }
                        .foregroundColor(secondaryTextColor.opacity(0.8))
                    }
                }
                    
                // Activity description from API
                Text(activity.description)
                    .font(FontStyles.bodySmall)
                    .foregroundColor(cardTextColor)
                    
                // Time and location
                HStack(spacing: 6) {
                    Text(activity.timeAgo)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(secondaryTextColor)
                        
                    if let kingdomName = activity.kingdomName {
                        Text("•")
                            .foregroundColor(secondaryTextColor)
                        Text(kingdomName)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
                
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: cardBackgroundColor, cornerRadius: 12)
        .padding(.horizontal)
    }
}
