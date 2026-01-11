import SwiftUI

/// Shows important notifications at the top of the screen
struct NotificationBanner: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
        .onTapGesture {
            onTap()
        }
    }
    
    private var iconName: String {
        switch notification.type {
        case "contract_ready":
            return "checkmark.circle.fill"
        case "level_up":
            return "arrow.up.circle.fill"
        case "skill_points":
            return "star.circle.fill"
        case "treasury_full":
            return "dollarsign.circle.fill"
        case "checkin_ready":
            return "location.circle.fill"
        default:
            return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.priority {
        case "high":
            return .yellow
        case "medium":
            return .blue
        default:
            return .gray
        }
    }
    
    private var backgroundColor: Color {
        switch notification.priority {
        case "high":
            return Color.green.opacity(0.9)
        case "medium":
            return Color.blue.opacity(0.9)
        default:
            return Color.gray.opacity(0.9)
        }
    }
}

/// Container for showing notifications
struct NotificationOverlay: View {
    @EnvironmentObject var appInit: AppInitService
    @State private var visibleNotifications: [AppNotification] = []
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(visibleNotifications) { notification in
                NotificationBanner(
                    notification: notification,
                    onDismiss: {
                        withAnimation {
                            visibleNotifications.removeAll { $0.id == notification.id }
                            appInit.dismissNotification(notification)
                        }
                    },
                    onTap: {
                        handleNotificationTap(notification)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: appInit.notifications) { oldValue, newValue in
            // Show new high priority notifications
            let newHighPriority = newValue.filter { $0.priority == "high" }
            withAnimation {
                visibleNotifications = Array(newHighPriority.prefix(3)) // Show max 3
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // TODO: Navigate to appropriate screen based on action
        print("🔔 Tapped notification: \(notification.action)")
        
        withAnimation {
            visibleNotifications.removeAll { $0.id == notification.id }
            appInit.dismissNotification(notification)
        }
    }
}

#Preview {
    NotificationBanner(
        notification: AppNotification(
            type: "contract_ready",
            priority: "high",
            title: "Contract Complete!",
            message: "Market construction complete",
            action: "complete_contract",
            action_id: "123",
            created_at: ISO8601DateFormatter().string(from: Date()),
            show_popup: nil,
            coup_data: nil,
            icon: "checkmark.circle.fill",
            icon_color: "buttonSuccess",
            priority_color: "buttonWarning",
            border_color: "buttonWarning"
        ),
        onDismiss: {},
        onTap: {}
    )
}

