import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsViewModel()
    @State private var selectedFriend: Friend?
    @State private var showFriendActivity = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Header
                        headerSection
                        
                        // Friend Requests
                        if !viewModel.pendingReceived.isEmpty {
                            friendRequestsSection
                        }
                        
                        // Friends List
                        friendsListSection
                        
                        // Pending Sent
                        if !viewModel.pendingSent.isEmpty {
                            pendingSentSection
                        }
                        
                        // Friend Activity Section
                        if !viewModel.friendActivities.isEmpty {
                            friendActivitySection
                            }
                        }
                        .padding(.vertical)
                }
                
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    MedievalLoadingView(status: "Loading...")
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
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
                await viewModel.loadFriendActivity()
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
                HStack {
                    Image(systemName: "person.2.fill")
                    .font(FontStyles.iconExtraLarge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Friends")
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                
                // Friend count badge
                if !viewModel.friends.isEmpty {
                    Text("\(viewModel.friends.count)")
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 12, shadowOffset: 2, borderWidth: 2)
                }
            }
            
            // Add Friend Button
            NavigationLink(destination: AddFriendView(onAdded: {
                Task {
                    await viewModel.loadFriends()
                }
            })) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(FontStyles.iconSmall)
                    Text("Add Friend")
                        .font(FontStyles.bodyMediumBold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    cornerRadius: 10,
                    shadowOffset: 3,
                    borderWidth: 2
                )
            }
            }
            .padding(.horizontal)
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Friend Requests Section
                        
    private var friendRequestsSection: some View {
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                                Text("Friend Requests")
                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(viewModel.pendingReceived.count)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 10, shadowOffset: 1, borderWidth: 1.5)
            }
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
                        
    // MARK: - Friends List Section
    
    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            if !viewModel.pendingReceived.isEmpty || !viewModel.friends.isEmpty {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 2)
                                .padding(.horizontal)
            }
                            
            if !viewModel.friends.isEmpty {
                                    Text("My Friends")
                    .font(FontStyles.headingLarge)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                .padding(.horizontal)
                                
                                ForEach(viewModel.friends) { friend in
                                    FriendCard(friend: friend, onTap: {
                                        selectedFriend = friend
                                    })
                }
            } else if !viewModel.isLoading && viewModel.pendingReceived.isEmpty {
                emptyFriendsState
            }
                                }
                            }
    
    // MARK: - Empty State
    
    private var emptyFriendsState: some View {
                            VStack(spacing: KingdomTheme.Spacing.large) {
                                Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(KingdomTheme.Colors.inkLight)
                                
                                Text("No Friends Yet")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
            Text("Add friends to see what they're up to and compete together!")
                                    .font(FontStyles.bodyMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                            }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
                        }
                        
    // MARK: - Pending Sent Section
    
    private var pendingSentSection: some View {
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
                                Text("Pending Requests")
                .font(FontStyles.labelLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .padding(.horizontal)
                                
                                ForEach(viewModel.pendingSent) { friend in
                                    PendingSentCard(friend: friend, onCancel: {
                                        await viewModel.removeFriend(friend.id)
                                    })
            }
        }
    }
    
    // MARK: - Friend Activity Section
    
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            .padding(.horizontal)
            
            HStack {
                Text("Friend Activity")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("Last 7 days")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(.horizontal)
            
            ForEach(viewModel.friendActivities.prefix(5)) { activity in
                    ActivityCard(activity: activity, showUser: true)
                }
            
            if viewModel.friendActivities.count > 5 {
                Text("+ \(viewModel.friendActivities.count - 5) more activities")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
}

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
                    
                // Simple action label
                Text(ActionIconHelper.activityDescription(for: activity.actionType))
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
                    Text("+\(amount)")
                            .font(FontStyles.headingSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Image(systemName: "g.circle.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                }
            }
        }
        .padding()
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12, shadowOffset: 3, borderWidth: 2)
        .padding(.horizontal)
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
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(FontStyles.headingSmall)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 12)
                    
                    // Online indicator
                    if let isOnline = friend.isOnline, isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .offset(x: 4, y: 4)
                    }
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 8) {
                        if let level = friend.level {
                            Text("Lv\(level)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
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
                        } else if let kingdomName = friend.currentKingdomName {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                Text(kingdomName)
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
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return KingdomTheme.Colors.buttonSuccess
        case "blue": return KingdomTheme.Colors.buttonPrimary
        case "orange": return KingdomTheme.Colors.buttonWarning
        case "red": return KingdomTheme.Colors.buttonDanger
        case "yellow": return KingdomTheme.Colors.inkMedium
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
