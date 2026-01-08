import SwiftUI

/// Section displaying player's recent activity
struct MyActivitySection: View {
    let activities: [ActivityLogEntry]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("My Activity")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("Last 7 days")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(KingdomTheme.Colors.inkMedium)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if activities.isEmpty {
                emptyStateView
            } else {
                activityList
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text("No Recent Activity")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("Your actions will appear here")
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private var activityList: some View {
        VStack(spacing: 6) {
            ForEach(activities.prefix(5)) { activity in
                MyActivityRow(activity: activity)
            }
            
            if activities.count > 5 {
                Text("+ \(activities.count - 5) more activities")
                    .font(.system(size: 12))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Activity Row

struct MyActivityRow: View {
    let activity: ActivityLogEntry
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: activity.icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .brutalistBadge(backgroundColor: activity.color, cornerRadius: 7, shadowOffset: 1.5, borderWidth: 1.5)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 4) {
                    Text(activity.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    if let kingdomName = activity.kingdomName {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text(kingdomName)
                            .font(.system(size: 11))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            
            Spacer()
            
            if let amount = activity.amount {
                HStack(spacing: 2) {
                    // Special formatting for different action types
                    if activity.actionType == "kingdom_visits" {
                        Text("\(amount)×")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Image(systemName: "map.fill")
                            .font(.system(size: 12))
                            .foregroundColor(KingdomTheme.Colors.royalPurple)
                    } else {
                        let prefix = activity.actionType == "travel_fee" ? "-" : "+"
                        Text("\(prefix)\(amount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        if activity.actionType == "patrol" {
                            Image(systemName: "r.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(KingdomTheme.Colors.royalPurple)
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                        }
                    }
                }
            }
        }
        .padding(8)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8, shadowOffset: 1.5, borderWidth: 1.5)
    }
}

