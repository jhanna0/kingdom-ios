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
                                .font(FontStyles.iconMedium)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 10)
                            
                            Text("Kingdom Notifications")
                                .font(FontStyles.headingLarge)
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
                                    .font(FontStyles.iconExtraLarge)
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 80)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 20)
                                
                                Text("All Caught Up")
                                    .font(FontStyles.headingLarge)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                Text("No kingdom activity")
                                    .font(FontStyles.bodyMedium)
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



