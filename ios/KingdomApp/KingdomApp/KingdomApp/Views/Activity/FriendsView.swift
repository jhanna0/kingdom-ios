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
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Friends")
                    .font(KingdomTheme.Typography.title2())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, KingdomTheme.Spacing.small)
                        
                        // Friend requests received
                        if !viewModel.pendingReceived.isEmpty {
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                                Text("Friend Requests")
                                    .font(KingdomTheme.Typography.headline())
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
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                                HStack {
                                    Text("My Friends")
                                        .font(KingdomTheme.Typography.headline())
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    
                                    Text("(\(viewModel.friends.count))")
                                        .font(KingdomTheme.Typography.caption())
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                                    .font(.system(size: 60))
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                Text("No Friends Yet")
                                    .font(KingdomTheme.Typography.title2())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                Text("Add friends to see what they're up to!")
                                    .font(KingdomTheme.Typography.body())
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
                                    .font(KingdomTheme.Typography.caption())
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
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("My Activity")
                    .font(KingdomTheme.Typography.title2())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.myActivities.isEmpty {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("No Recent Activity")
                        .font(KingdomTheme.Typography.title2())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Your actions will appear here")
                        .font(KingdomTheme.Typography.body())
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
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Friend Activity")
                    .font(KingdomTheme.Typography.title2())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.friendActivities.isEmpty {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 60))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("No Friend Activity")
                        .font(KingdomTheme.Typography.title2())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Add friends to see what they're doing!")
                        .font(KingdomTheme.Typography.body())
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
            HStack(spacing: 8) {
                // Icon
                Image(systemName: activity.icon)
                    .font(.title3)
                    .foregroundColor(activityColor(activity.color))
                    .frame(width: 32, height: 32)
                    .background(activityColor(activity.color).opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    // User name if showing friend activity
                    if showUser, let displayName = activity.displayName {
                        HStack(spacing: 4) {
                            Text(displayName)
                                .font(.caption.bold())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            if let level = activity.userLevel {
                                Text("Lv\(level)")
                                    .font(.caption2)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                    
                    // Description
                    Text(activity.description)
                        .font(.subheadline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        // Time
                        Text(activity.timeAgo)
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        // Kingdom
                        if let kingdomName = activity.kingdomName {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle")
                                    .font(.caption2)
                                Text(kingdomName)
                                    .font(.caption)
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
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        if activity.actionType == "build" {
                            Text("actions")
                                .font(.caption2)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else if activity.actionType.contains("property") || activity.actionType == "train" {
                            Image(systemName: "g.circle.fill")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.gold)
                        }
                    }
                }
            }
        }
        .padding()
        .parchmentCard()
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
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(KingdomTheme.Colors.gold.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(friend.displayName.prefix(1)).uppercased())
                                .font(.title3.bold())
                                .foregroundColor(KingdomTheme.Colors.gold)
                        )
                    
                    // Online indicator
                    if let isOnline = friend.isOnline, isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(KingdomTheme.Colors.parchmentLight, lineWidth: 2)
                            )
                    }
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        // Level
                        if let level = friend.level {
                            Text("Lv\(level)")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                        }
                        
                        // Activity
                        if let activity = friend.activity {
                            HStack(spacing: 4) {
                                Image(systemName: activity.icon)
                                    .font(.caption2)
                                    .foregroundColor(activityColor(activity.color))
                                
                                Text(activity.displayText)
                                    .font(.caption)
                                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                                    .lineLimit(1)
                            }
                        } else if friend.currentKingdomName != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                
                                Text(friend.currentKingdomName!)
                                    .font(.caption)
                                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            }
            .padding()
            .parchmentCard()
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
                Circle()
                    .fill(KingdomTheme.Colors.gold.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(friend.displayName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("wants to be friends")
                        .font(KingdomTheme.Typography.caption())
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
                        .font(KingdomTheme.Typography.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(KingdomTheme.Colors.buttonSuccess)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    Task {
                        await onReject()
                        isProcessing = false
                    }
                }) {
                    Text("Decline")
                        .font(KingdomTheme.Typography.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(KingdomTheme.Colors.inkLight.opacity(0.3))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .parchmentCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.gold.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Pending Sent Card

struct PendingSentCard: View {
    let friend: Friend
    let onCancel: () async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Request pending")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await onCancel()
                }
            }) {
                Text("Cancel")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    FriendsView()
}

