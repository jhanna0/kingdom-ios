import SwiftUI

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActivityViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        // Header
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.title2)
                                .foregroundColor(KingdomTheme.Colors.gold)
                            
                            Text("Kingdom Notifications")
                                .font(KingdomTheme.Typography.title2())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, KingdomTheme.Spacing.small)
                        
                        // Notifications
                        if !viewModel.notifications.isEmpty {
                            ForEach(viewModel.notifications) { notification in
                                NotificationCard(notification: notification, onTap: {
                                    viewModel.handleNotificationTap(notification)
                                })
                            }
                        } else if !viewModel.isLoading {
                            VStack(spacing: KingdomTheme.Spacing.large) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                
                                Text("All Caught Up")
                                    .font(KingdomTheme.Typography.title2())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                Text("No kingdom activity")
                                    .font(KingdomTheme.Typography.body())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            .padding(.top, 60)
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
            .navigationTitle("Notifications")
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
                await viewModel.loadActivity()
            }
            .sheet(item: $viewModel.selectedCoup) { coupData in
                CoupVotingSheet(coupData: coupData, onVote: { side in
                    Task {
                        await viewModel.voteCoup(coupData.id, side: side)
                    }
                })
            }
        }
    }
}

// Note: NotificationCard is already defined in ActivityView.swift, so we'll reuse it

#Preview {
    NotificationsSheet()
}



