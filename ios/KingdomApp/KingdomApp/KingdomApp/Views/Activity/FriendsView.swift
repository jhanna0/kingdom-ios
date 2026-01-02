import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriend = false
    @State private var selectedFriend: Friend?
    @State private var selectedTab: Tab = .friends
    
    enum Tab {
        case friends
        case myActivity
        case friendActivity
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 0) {
                        TabButton(title: "Friends", icon: "person.2.fill", isSelected: selectedTab == .friends) {
                            selectedTab = .friends
                        }
                        
                        TabButton(title: "My Activity", icon: "list.bullet.clipboard", isSelected: selectedTab == .myActivity) {
                            selectedTab = .myActivity
                        }
                        
                        TabButton(title: "Friend Activity", icon: "person.3", isSelected: selectedTab == .friendActivity) {
                            selectedTab = .friendActivity
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, KingdomTheme.Spacing.small)
                    
                    // Content
                    ScrollView {
                        VStack(spacing: KingdomTheme.Spacing.large) {
                            switch selectedTab {
                            case .friends:
                                friendsContent
                            case .myActivity:
                                myActivityContent
                            case .friendActivity:
                                friendActivityContent
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    MedievalLoadingView(status: "Loading...")
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedTab == .friends {
                        Button(action: { showAddFriend = true }) {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .task {
                await viewModel.loadFriends()
                await viewModel.loadMyActivity()
                await viewModel.loadFriendActivity()
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView(onAdded: {
                    showAddFriend = false
                    Task {
                        await viewModel.loadFriends()
                    }
                })
            }
            .sheet(item: $selectedFriend) { friend in
                NavigationStack {
                    PlayerProfileView(userId: friend.friendUserId)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Friends Content
    
    @ViewBuilder
    private var friendsContent: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            // Header with add button (moved to content for this tab)
            HStack {
                Image(systemName: "person.2.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                
                Text("Friends")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, KingdomTheme.Spacing.small)
                        
                        // Friend requests received
                        if !viewModel.pendingReceived.isEmpty {
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                                Text("Friend Requests")
                                    .font(FontStyles.headingMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.pendingReceived) { friend in
                                    FriendRequestCard(
                                        friend: friend,
                                        onAccept: {
                                            await viewModel.acceptFriend(friend.id)
                                        },
                                        onReject: {
                                            await viewModel.rejectFriend(friend.id)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Friends list
                        if !viewModel.friends.isEmpty {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 2)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                                HStack {
                                    Text("My Friends")
                                        .font(FontStyles.headingMedium)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    
                                    Text("(\(viewModel.friends.count))")
                                        .font(FontStyles.labelSmall)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10, shadowOffset: 1, borderWidth: 1.5)
                                }
                                .padding(.horizontal)
                                
                                ForEach(viewModel.friends) { friend in
                                    FriendCard(friend: friend, onTap: {
                                        selectedFriend = friend
                                    })
                                }
                            }
                        } else if !viewModel.isLoading && viewModel.pendingReceived.isEmpty {
                            VStack(spacing: KingdomTheme.Spacing.large) {
                                Image(systemName: "person.2.slash")
                                    .font(FontStyles.iconExtraLarge)
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 80)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20)
                                
                                Text("No Friends Yet")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                Text("Add friends to see what they're up to!")
                                    .font(FontStyles.bodyMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: { showAddFriend = true }) {
                                    Label("Add Friends", systemImage: "person.badge.plus")
                                }
                                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonPrimary))
                            }
                            .padding(.top, 60)
                            .padding(.horizontal)
                        }
                        
                        // Pending sent requests
                        if !viewModel.pendingSent.isEmpty {
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                                Text("Pending Requests")
                                    .font(FontStyles.labelMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.pendingSent) { friend in
                                    PendingSentCard(friend: friend, onCancel: {
                                        await viewModel.removeFriend(friend.id)
                                    })
                                }
                            }
                        }
        }
    }
    
    // MARK: - My Activity Content
    
    @ViewBuilder
    private var myActivityContent: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                
                Text("My Activity")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.myActivities.isEmpty {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Image(systemName: "tray")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20)
                    
                    Text("No Recent Activity")
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Your actions will appear here")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding(.top, 60)
            } else {
                ForEach(viewModel.myActivities) { activity in
                    ActivityCard(activity: activity, showUser: false)
                }
            }
        }
    }
    
    // MARK: - Friend Activity Content
    
    @ViewBuilder
    private var friendActivityContent: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "person.3")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                
                Text("Friend Activity")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.friendActivities.isEmpty {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Image(systemName: "person.2.slash")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20)
                    
                    Text("No Friend Activity")
                        .font(FontStyles.headingLarge)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Add friends to see what they're doing!")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding(.top, 60)
            } else {
                ForEach(viewModel.friendActivities) { activity in
                    ActivityCard(activity: activity, showUser: true)
                }
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkMedium)
            .background(
                isSelected ? KingdomTheme.Colors.buttonPrimary.opacity(0.1) : Color.clear
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityLogEntry
    let showUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Icon with brutalist badge
                Image(systemName: activity.icon)
                    .font(FontStyles.iconSmall)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .brutalistBadge(backgroundColor: activityColor(activity.color), cornerRadius: 8, shadowOffset: 2, borderWidth: 1.5)
                
                VStack(alignment: .leading, spacing: 2) {
                    // User name if showing friend activity
                    if showUser, let displayName = activity.displayName {
                        HStack(spacing: 4) {
                            Text(displayName)
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            if let level = activity.userLevel {
                                Text("Lv\(level)")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                    
                    // Description
                    Text(activity.description)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        // Time
                        Text(activity.timeAgo)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        // Kingdom
                        if let kingdomName = activity.kingdomName {
                            Text("•")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle")
                                    .font(FontStyles.iconMini)
                                Text(kingdomName)
                                    .font(FontStyles.labelSmall)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                }
                
                Spacer()
                
                // Amount if present
                if let amount = activity.amount {
                    VStack(spacing: 2) {
                        Text("\(amount)")
                            .font(FontStyles.headingSmall)
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        if activity.actionType == "build" {
                            Text("actions")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else if activity.actionType.contains("property") || activity.actionType == "train" {
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.gold)
                        }
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return KingdomTheme.Colors.buttonSuccess
        case "blue": return KingdomTheme.Colors.buttonPrimary
        case "orange": return KingdomTheme.Colors.buttonWarning
        case "red": return KingdomTheme.Colors.buttonDanger
        case "yellow": return KingdomTheme.Colors.gold
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Friend Card

struct FriendCard: View {
    let friend: Friend
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator and brutalist style
                ZStack(alignment: .bottomTrailing) {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(FontStyles.headingSmall)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 12)
                    
                    // Online indicator
                    if let isOnline = friend.isOnline, isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .offset(x: 2, y: 2)
                    }
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        // Level
                        if let level = friend.level {
                            Text("Lv\(level)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Text("•")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                        }
                        
                        // Activity
                        if let activity = friend.activity {
                            HStack(spacing: 4) {
                                Image(systemName: activity.icon)
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(activityColor(activity.color))
                                
                                Text(activity.displayText)
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .lineLimit(1)
                            }
                        } else if friend.currentKingdomName != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                
                                Text(friend.currentKingdomName!)
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return KingdomTheme.Colors.buttonSuccess
        case "blue": return KingdomTheme.Colors.buttonPrimary
        case "orange": return KingdomTheme.Colors.buttonWarning
        case "red": return KingdomTheme.Colors.buttonDanger
        case "yellow": return KingdomTheme.Colors.gold
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Friend Request Card

struct FriendRequestCard: View {
    let friend: Friend
    let onAccept: () async -> Void
    let onReject: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: 12) {
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(FontStyles.headingSmall)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                
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
                    Task {
                        await onAccept()
                        isProcessing = false
                    }
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
                    Task {
                        await onReject()
                        isProcessing = false
                    }
                }) {
                    Text("Decline")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
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
    let onCancel: () async -> Void
    
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
                Task {
                    await onCancel()
                }
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

// MARK: - Preview

#Preview {
    FriendsView()
}

