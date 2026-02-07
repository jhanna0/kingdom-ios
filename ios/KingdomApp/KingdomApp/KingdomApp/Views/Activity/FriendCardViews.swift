import SwiftUI

// MARK: - Friend Card

struct FriendCard: View {
    let friend: Friend
    
    private var avatarBackgroundColor: Color {
        if let customization = friend.subscriberCustomization {
            return customization.iconBackgroundColorValue
        }
        return KingdomTheme.Colors.inkMedium
    }
    
    private var avatarTextColor: Color {
        if let customization = friend.subscriberCustomization {
            return customization.iconTextColorValue
        }
        return .white
    }
    
    private var cardBackgroundColor: Color {
        friend.subscriberCustomization?.cardBackgroundColorValue ?? KingdomTheme.Colors.parchmentLight
    }
    
    private var cardTextColor: Color {
        friend.subscriberCustomization?.cardTextColorValue ?? KingdomTheme.Colors.inkDark
    }
    
    private var cardSecondaryTextColor: Color {
        friend.subscriberCustomization?.cardTextColorValue.opacity(0.7) ?? KingdomTheme.Colors.inkMedium
    }

    var body: some View {
        NavigationLink(destination: PlayerProfileView(userId: friend.friendUserId)) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(FontStyles.headingSmall)
                        .foregroundColor(avatarTextColor)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(backgroundColor: avatarBackgroundColor, cornerRadius: 12)
                    
                    if let isOnline = friend.isOnline, isOnline {
                        Circle().fill(Color.green).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .offset(x: 4, y: 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(friend.displayName)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(cardTextColor)
                        
                        if friend.subscriberCustomization != nil {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(KingdomTheme.Colors.imperialGold)
                        }
                    }
                    
                    if let title = friend.subscriberCustomization?.selectedTitle {
                        HStack(spacing: 4) {
                            Image(systemName: title.icon).font(.system(size: 10))
                            Text(title.displayName).font(FontStyles.labelSmall)
                        }
                        .foregroundColor(cardSecondaryTextColor)
                    }
                    
                    HStack(spacing: 8) {
                        if let level = friend.level {
                            Text("Lv\(level)").font(FontStyles.labelSmall).foregroundColor(cardSecondaryTextColor)
                        }
                        
                        if let activity = friend.activity {
                            HStack(spacing: 4) {
                                Image(systemName: activity.icon).font(FontStyles.iconMini).foregroundColor(activityColor(activity.color))
                                Text(activity.displayText).font(FontStyles.labelSmall).foregroundColor(cardSecondaryTextColor).lineLimit(1)
                            }
                        } else if let kingdomName = friend.currentKingdomName {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill").font(FontStyles.iconMini).foregroundColor(cardSecondaryTextColor)
                                Text(kingdomName).font(FontStyles.labelSmall).foregroundColor(cardSecondaryTextColor).lineLimit(1)
                            }
                        }
                    }
                }
                
                Spacer()
                Image(systemName: "chevron.right").font(FontStyles.iconSmall).foregroundColor(cardSecondaryTextColor)
            }
            .padding()
            .brutalistCard(backgroundColor: cardBackgroundColor, cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return KingdomTheme.Colors.buttonSuccess
        case "blue": return KingdomTheme.Colors.buttonPrimary
        case "orange": return KingdomTheme.Colors.buttonWarning
        case "red": return KingdomTheme.Colors.buttonDanger
        case "purple": return KingdomTheme.Colors.royalPurple
        case "yellow": return KingdomTheme.Colors.imperialGold
        case "gray": return KingdomTheme.Colors.inkLight
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Friend Request Card

struct FriendRequestCard: View {
    let friend: Friend
    let onAccept: (@escaping () -> Void) -> Void
    let onReject: (@escaping () -> Void) -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: 12) {
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(FontStyles.headingSmall)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("wants to be friends")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Button(action: {
                    isProcessing = true
                    onAccept { isProcessing = false }
                }) {
                    Text("Accept")
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    onReject { isProcessing = false }
                }) {
                    Text("Decline")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
                .disabled(isProcessing)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
}

// MARK: - Pending Sent Card

struct PendingSentCard: View {
    let friend: Friend
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(String(friend.displayName.prefix(1)).uppercased())
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .frame(width: 40, height: 40)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Request pending")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            Button(action: {
                onCancel()
            }) {
                Text("Cancel")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
}

// MARK: - All Friends View

struct AllFriendsView: View {
    let friends: [Friend]
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    ForEach(friends) { friend in
                        FriendCard(friend: friend)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("All Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - All Trade History View

struct AllTradeHistoryView: View {
    let trades: [TradeOffer]
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    ForEach(trades) { trade in
                        TradeHistoryCard(trade: trade)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Trade History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - All Friend Activity View

struct AllFriendActivityView: View {
    let activities: [ActivityLogEntry]
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    ForEach(activities) { activity in
                        ActivityCard(activity: activity, showUser: true)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Friend Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
