import SwiftUI

// MARK: - FriendsView Section Extensions

extension FriendsView {
    
    // MARK: - Header Section
    
    var headerSection: some View {
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
                        
    var friendRequestsSection: some View {
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
    
    var friendsListSection: some View {
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
                                
                ForEach(viewModel.friends.prefix(5)) { friend in
                                    FriendCard(friend: friend)
                }
                
                // View All button if more than 5 friends
                if viewModel.friends.count > 5 {
                    NavigationLink(destination: AllFriendsView(friends: viewModel.friends)) {
                        HStack(spacing: 6) {
                            Text("All Friends")
                                .font(FontStyles.headingSmall)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(FontStyles.iconSmall)
                        }
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            } else if !viewModel.isLoading && viewModel.pendingReceived.isEmpty {
                emptyFriendsState
            }
                                }
                            }
    
    // MARK: - Empty State
    
    var emptyFriendsState: some View {
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
    
    var pendingSentSection: some View {
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
    
    var friendActivitySection: some View {
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
    
    // MARK: - Duel Challenges Section
    
    var duelChallengesSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                Image(systemName: "figure.fencing")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.royalCrimson)
                
                Text("Duel Challenges")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(viewModel.incomingDuelChallenges.count)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalCrimson, cornerRadius: 10, shadowOffset: 1, borderWidth: 1.5)
            }
            .padding(.horizontal)
            
            ForEach(viewModel.incomingDuelChallenges) { challenge in
                DuelChallengeCard(
                    challenge: challenge,
                    onAccept: {
                        await viewModel.acceptDuelChallenge(challenge.invitationId)
                    },
                    onDecline: {
                        await viewModel.declineDuelChallenge(challenge.invitationId)
                    }
                )
            }
        }
    }
    
    // MARK: - Pending Trades Section (Incoming)
    
    var pendingTradesSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                
                Text("Incoming Offers")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(viewModel.incomingTrades.count)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10, shadowOffset: 1, borderWidth: 1.5)
            }
            .padding(.horizontal)
            
            ForEach(viewModel.incomingTrades) { trade in
                TradeOfferCard(
                    trade: trade,
                    onAccept: {
                        await viewModel.acceptTrade(trade.id)
                        NotificationCenter.default.post(name: .playerStateDidChange, object: nil)
                    },
                    onDecline: {
                        await viewModel.declineTrade(trade.id)
                    }
                )
            }
        }
    }
    
    // MARK: - Outgoing Trades Section
    
    var outgoingTradesSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                
                Text("Your Pending Offers")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .padding(.horizontal)
            
            ForEach(viewModel.outgoingTrades) { trade in
                OutgoingTradeCard(
                    trade: trade,
                    onCancel: {
                        await viewModel.cancelTrade(trade.id)
                        NotificationCenter.default.post(name: .playerStateDidChange, object: nil)
                    }
                )
            }
        }
    }
    
    // MARK: - Trade History Section
    
    var tradeHistorySection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Recent Trades")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            .padding(.horizontal)
            
            // Show only 2 trades inline
            ForEach(viewModel.tradeHistory.prefix(2)) { trade in
                TradeHistoryCard(trade: trade)
            }
            
            // "See More" NavigationLink if more than 2 trades
            if viewModel.tradeHistory.count > 2 {
                NavigationLink(destination: AllTradeHistoryView(trades: Array(viewModel.tradeHistory.prefix(5)))) {
                    HStack(spacing: 6) {
                        Text("See More")
                            .font(FontStyles.headingSmall)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(FontStyles.iconSmall)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Alliance Requests Section
    
    var allianceRequestsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            HStack {
                Image(systemName: "person.2.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                
                Text("Alliance Proposals")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(viewModel.pendingAlliancesReceived.count)")
                    .font(FontStyles.labelBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10, shadowOffset: 1, borderWidth: 1.5)
            }
            .padding(.horizontal)
            
            ForEach(viewModel.pendingAlliancesReceived) { alliance in
                AllianceProposalCard(
                    alliance: alliance,
                    onAccept: {
                        await viewModel.acceptAlliance(alliance.id)
                    },
                    onDecline: {
                        await viewModel.declineAlliance(alliance.id)
                    }
                )
            }
        }
    }
    
    // MARK: - Pending Alliances Sent Section
    // Note: Active Alliances are now shown in KingdomInfoSheetView for hometown
    
    var pendingAlliancesSentSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            Text("Pending Alliance Proposals")
                .font(FontStyles.labelLarge)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .padding(.horizontal)
            
            ForEach(viewModel.pendingAlliancesSent) { alliance in
                PendingAllianceSentCard(alliance: alliance)
            }
        }
    }
}
