import SwiftUI

struct ActivityView: View {
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
                            
                            Text("Activity Feed")
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
                                
                                Text("No new activity")
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
            .navigationTitle("Activity")
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

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: ActivityNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: iconForNotification)
                        .font(.title2)
                        .foregroundColor(iconColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text(notification.message)
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                }
                
                // Coup-specific info
                if let coupData = notification.coupData {
                    Divider()
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text("\(coupData.attackerCount)")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            Text("\(coupData.defenderCount)")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(coupData.timeRemainingFormatted)
                                .font(KingdomTheme.Typography.caption())
                        }
                        .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                
                // Invasion-specific info
                if let invasionData = notification.invasionData {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text(invasionData.attackingFromKingdomName)
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Text(invasionData.targetKingdomName)
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                Text("\(invasionData.attackerCount)")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .font(.caption)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                Text("\(invasionData.defenderCount)")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                Text(invasionData.timeRemainingFormatted)
                                    .font(KingdomTheme.Typography.caption())
                            }
                            .foregroundColor(KingdomTheme.Colors.gold)
                        }
                        
                        // Show alliance badge if applicable
                        if invasionData.isAllied == true {
                            HStack(spacing: 4) {
                                Image(systemName: "handshake.fill")
                                    .font(.caption)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                Text("Allied Empire")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            }
                        }
                    }
                }
            }
            .padding()
            .parchmentCard()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    private var iconForNotification: String {
        switch notification.type {
        case .coupVoteNeeded, .coupInProgress, .coupAgainstYou:
            return "crown.fill"
        case .coupResolved:
            return "flag.checkered"
        case .invasionAgainstYou:
            return "exclamationmark.shield.fill"
        case .allyUnderAttack:
            return "handshake.fill"
        case .invasionDefenseNeeded, .invasionInProgress:
            return "shield.fill"
        case .invasionResolved:
            return "flag.checkered"
        case .contractReady:
            return "checkmark.circle.fill"
        case .levelUp:
            return "star.fill"
        case .skillPoints:
            return "sparkles"
        case .treasuryFull:
            return "dollarsign.circle.fill"
        case .checkinReady:
            return "location.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.priority {
        case .critical: return KingdomTheme.Colors.buttonDanger
        case .high: return KingdomTheme.Colors.buttonWarning
        case .medium: return KingdomTheme.Colors.gold
        case .low: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private var borderColor: Color {
        switch notification.priority {
        case .critical: return KingdomTheme.Colors.buttonDanger.opacity(0.5)
        case .high: return KingdomTheme.Colors.buttonWarning.opacity(0.5)
        case .medium: return KingdomTheme.Colors.gold.opacity(0.3)
        case .low: return KingdomTheme.Colors.inkLight.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}

