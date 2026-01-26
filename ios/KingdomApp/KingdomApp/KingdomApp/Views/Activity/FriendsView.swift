import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel = FriendsViewModel()
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
                        
                        // Pending Trade Offers (Merchant skill)
                        if !viewModel.incomingTrades.isEmpty {
                            pendingTradesSection
                        }
                        
                        // Pending Duel Challenges
                        if !viewModel.incomingDuelChallenges.isEmpty {
                            duelChallengesSection
                        }
                        
                        // Alliance Requests Received (Rulers only)
                        if !viewModel.pendingAlliancesReceived.isEmpty {
                            allianceRequestsSection
                        }
                        
                        // Pending Alliances Sent (Rulers only)
                        // Note: Active Alliances are now shown in KingdomInfoSheetView for hometown
                        if !viewModel.pendingAlliancesSent.isEmpty {
                            pendingAlliancesSentSection
                        }
                        
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
                await viewModel.loadTrades()
                await viewModel.loadAlliances()
                await viewModel.loadDuelChallenges()
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
}

// MARK: - Preview

#Preview {
    FriendsView()
}
