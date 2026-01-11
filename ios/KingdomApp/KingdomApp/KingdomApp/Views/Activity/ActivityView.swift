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
                                .font(FontStyles.iconMedium)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                            
                            Text("Activity Feed")
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
                                
                                Text("No new activity")
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
                CoupView(coupId: coupData.id, onDismiss: {
                    viewModel.selectedCoup = nil
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
                        .font(FontStyles.iconMedium)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .brutalistBadge(backgroundColor: iconColor, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text(notification.message)
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                
                // Coup-specific info (only show for active coups with participant data)
                if let coupData = notification.coupData,
                   let attackerCount = coupData.attackerCount,
                   let defenderCount = coupData.defenderCount {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text("\(attackerCount)")
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            Text("\(defenderCount)")
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Spacer()
                        
                        if coupData.timeRemainingSeconds != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(FontStyles.iconMini)
                                Text(coupData.timeRemainingFormatted)
                                    .font(FontStyles.labelBold)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                }
                
                // Invasion-specific info
                if let invasionData = notification.invasionData {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text(invasionData.attackingFromKingdomName)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Image(systemName: "arrow.right")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            Text(invasionData.targetKingdomName)
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                Text("\(invasionData.attackerCount)")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                Text("\(invasionData.defenderCount)")
                                    .font(FontStyles.labelBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(FontStyles.iconMini)
                                Text(invasionData.timeRemainingFormatted)
                                    .font(FontStyles.labelBold)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        // Show alliance badge if applicable
                        if invasionData.isAllied == true {
                            HStack(spacing: 4) {
                                Image(systemName: "handshake.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                Text("Allied Empire")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                            }
                        }
                    }
                }
                
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    // MARK: - Dynamic from Backend (no switch statements!)
    
    private var iconForNotification: String {
        // Use backend-provided icon, fallback to bell
        notification.icon ?? "bell.fill"
    }
    
    private var iconColor: Color {
        // Use backend-provided color, fallback based on priority
        if let colorName = notification.priorityColor {
            return ThemeColorHelper.color(for: colorName)
        }
        // Fallback
        return KingdomTheme.Colors.inkMedium
    }
    
    private var borderColor: Color {
        // Use backend-provided border color
        if let colorName = notification.borderColor {
            return ThemeColorHelper.color(for: colorName).opacity(0.5)
        }
        // Fallback
        return KingdomTheme.Colors.inkMedium.opacity(0.3)
    }
}

// MARK: - Theme Color Helper

/// Maps backend color names to KingdomTheme.Colors
/// SINGLE SOURCE OF TRUTH - backend sends color name, frontend renders
struct ThemeColorHelper {
    static func color(for name: String) -> Color {
        switch name {
        case "buttonDanger": return KingdomTheme.Colors.buttonDanger
        case "buttonWarning": return KingdomTheme.Colors.buttonWarning
        case "buttonSuccess": return KingdomTheme.Colors.buttonSuccess
        case "buttonPrimary": return KingdomTheme.Colors.buttonPrimary
        case "imperialGold": return KingdomTheme.Colors.imperialGold
        case "inkDark": return KingdomTheme.Colors.inkDark
        case "inkMedium": return KingdomTheme.Colors.inkMedium
        case "inkLight": return KingdomTheme.Colors.inkLight
        case "royalBlue": return KingdomTheme.Colors.royalBlue
        case "royalEmerald": return KingdomTheme.Colors.royalEmerald
        default: return KingdomTheme.Colors.inkMedium
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}

