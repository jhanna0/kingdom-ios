import SwiftUI

struct ActivityCard: View {
    let activity: ActivityLogEntry
    let showUser: Bool
    
    private var cardBackgroundColor: Color {
        activity.subscriberCustomization?.cardBackgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: activity.icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(backgroundColor: activity.color, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
                
            VStack(alignment: .leading, spacing: 4) {
                if showUser, let displayName = activity.displayName {
                    HStack(spacing: 4) {
                        Text(displayName).font(FontStyles.bodyMediumBold).foregroundColor(KingdomTheme.Colors.inkDark)
                        if activity.subscriberCustomization != nil {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(KingdomTheme.Colors.imperialGold)
                        }
                        if let level = activity.userLevel {
                            Text("Lv\(level)").font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    
                    if let title = activity.subscriberCustomization?.selectedTitle {
                        HStack(spacing: 4) {
                            Image(systemName: title.icon).font(.system(size: 10))
                            Text(title.displayName).font(FontStyles.labelSmall)
                        }
                        .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.8))
                    }
                }
                    
                Text(activity.description).font(FontStyles.bodySmall).foregroundColor(KingdomTheme.Colors.inkDark)
                    
                HStack(spacing: 6) {
                    Text(activity.timeAgo).font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.inkMedium)
                    if let kingdomName = activity.kingdomName {
                        Text("•").foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text(kingdomName).font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.inkMedium)
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
