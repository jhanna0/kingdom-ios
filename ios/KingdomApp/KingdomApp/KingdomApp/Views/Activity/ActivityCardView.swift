import SwiftUI

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityLogEntry
    let showUser: Bool
    
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
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            if let level = activity.userLevel {
                                Text("Lv\(level)")
                                .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        }
                    }
                    
                // Activity description from API
                Text(activity.description)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                // Time and location
                HStack(spacing: 6) {
                        Text(activity.timeAgo)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        if let kingdomName = activity.kingdomName {
                            Text("•")
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text(kingdomName)
                                    .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    }
                }
                
                Spacer()
                
            // Amount
                if let amount = activity.amount {
                HStack(spacing: 4) {
                    // Show minus for spending (travel_fee), plus for earning
                    let prefix = activity.actionType == "travel_fee" ? "-" : "+"
                    Text("\(prefix)\(amount)")
                            .font(FontStyles.headingSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // Show R for reputation (patrol) or G for gold
                    if activity.actionType == "patrol" {
                        Image(systemName: "r.circle.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.royalPurple)
                    } else {
                        Image(systemName: "g.circle.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                    }
                }
            }
        }
        .padding()
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12, shadowOffset: 3, borderWidth: 2)
        .padding(.horizontal)
    }
}
