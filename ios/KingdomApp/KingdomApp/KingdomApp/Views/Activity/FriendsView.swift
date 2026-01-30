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
                        
                        // Incoming Trade Offers
                        if !viewModel.incomingTrades.isEmpty {
                            pendingTradesSection
                        }
                        
                        // Outgoing Trade Offers
                        if !viewModel.outgoingTrades.isEmpty {
                            outgoingTradesSection
                        }
                        
                        // Alliance Requests Received (Rulers only)
                        if !viewModel.pendingAlliancesReceived.isEmpty {
                            allianceRequestsSection
                        }
                        
                        // Pending Alliances Sent (Rulers only)
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
                        
                        // Recent Trade Results (accepted/declined/etc)
                        if !viewModel.tradeHistory.isEmpty {
                            tradeHistorySection
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
                await viewModel.loadDashboard()
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
