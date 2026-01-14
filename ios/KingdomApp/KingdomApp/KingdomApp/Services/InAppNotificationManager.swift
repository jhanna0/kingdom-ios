import SwiftUI
import UIKit
import UserNotifications
import Combine

// MARK: - In-App Notification Types

/// Types of in-app notifications
enum InAppNotificationType {
    case cooldownComplete(actionName: String, slot: String?)
    case actionSuccess(message: String)
    case warning(message: String)
    case info(message: String)
    
    var icon: String {
        switch self {
        case .cooldownComplete: return "checkmark.circle.fill"
        case .actionSuccess: return "sparkles"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .cooldownComplete(let actionName, _):
            return "\(actionName) Ready!"
        case .actionSuccess:
            return "Success!"
        case .warning:
            return "Warning"
        case .info:
            return "Info"
        }
    }
    
    var message: String {
        switch self {
        case .cooldownComplete(let actionName, _):
            return "You can \(actionName.lowercased()) again"
        case .actionSuccess(let message):
            return message
        case .warning(let message):
            return message
        case .info(let message):
            return message
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .cooldownComplete:
            return KingdomTheme.Colors.buttonSuccess
        case .actionSuccess:
            return KingdomTheme.Colors.buttonSuccess
        case .warning:
            return KingdomTheme.Colors.buttonWarning
        case .info:
            return KingdomTheme.Colors.buttonPrimary
        }
    }
}

// MARK: - In-App Notification Item

/// A single notification to display
struct InAppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: InAppNotificationType
    let createdAt = Date()
    
    static func == (lhs: InAppNotification, rhs: InAppNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - In-App Notification Manager

/// Centralized manager for in-app toast notifications
/// Intercepts OS notifications when app is in foreground and shows stylish in-app toast instead
class InAppNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = InAppNotificationManager()
    
    /// Queue of pending notifications
    private var notificationQueue: [InAppNotification] = []
    
    /// Currently showing notification
    private var currentNotification: InAppNotification?
    
    /// The overlay window
    private var overlayWindow: UIWindow?
    private var hostingController: UIHostingController<AnyView>?
    
    private override init() {
        super.init()
        // Set ourselves as the notification center delegate to intercept notifications
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when a notification arrives while app is in FOREGROUND
    /// We intercept it and show our stylish in-app toast instead
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let userInfo = content.userInfo
        
        // Extract action name from notification
        let actionName = userInfo["action"] as? String ?? content.title.replacingOccurrences(of: "Action Complete!", with: "").trimmingCharacters(in: .whitespaces)
        let slot = userInfo["slot"] as? String
        
        print("📲 InApp: Intercepted notification - \(content.title)")
        
        // Show in-app toast
        Task { @MainActor in
            // Use the notification title/body to create our toast
            if content.categoryIdentifier == "ACTION_COOLDOWN" || content.categoryIdentifier == "COUP_PHASE" {
                self.show(.cooldownComplete(actionName: actionName.isEmpty ? "Action" : actionName, slot: slot))
            } else {
                self.show(.info(message: content.body))
            }
        }
        
        // Don't show the system notification banner since we're showing our own
        completionHandler([])
    }
    
    /// Called when user taps on a notification (app was in background)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // User tapped notification - app is now opening
        // Could navigate to relevant screen here if needed
        completionHandler()
    }
    
    // MARK: - Show Notifications
    
    /// Show a notification immediately (or queue it if one is showing)
    @MainActor
    func show(_ type: InAppNotificationType, duration: TimeInterval = 3.5) {
        let notification = InAppNotification(type: type)
        
        if currentNotification != nil {
            // Queue it
            notificationQueue.append(notification)
            print("📲 InApp: Queued notification - \(type.title)")
        } else {
            // Show immediately
            displayNotification(notification, duration: duration)
        }
    }
    
    /// Display a notification with auto-dismiss using UIWindow overlay
    @MainActor
    private func displayNotification(_ notification: InAppNotification, duration: TimeInterval) {
        guard overlayWindow == nil else {
            // Already showing, queue this one
            notificationQueue.append(notification)
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            print("❌ InAppNotification: No window scene available")
            return
        }
        
        currentNotification = notification
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Create the toast view wrapped in animation container
        let toastView = InAppNotificationWindowContent(
            notification: notification,
            onDismiss: { [weak self] in
                self?.dismissCurrent()
            }
        )
        
        let hostingController = UIHostingController(rootView: AnyView(toastView))
        hostingController.view.backgroundColor = .clear
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        window.windowLevel = .alert + 2 // Above alerts and blocking errors
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true
        window.makeKeyAndVisible()
        
        self.overlayWindow = window
        self.hostingController = hostingController
        
        print("📲 InApp: Showing notification - \(notification.type.title)")
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismissCurrent()
        }
    }
    
    /// Dismiss current notification and show next in queue
    @MainActor
    func dismissCurrent() {
        guard overlayWindow != nil else { return }
        
        // Hide with animation
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.overlayWindow?.alpha = 0
        }, completion: { [weak self] _ in
            self?.overlayWindow?.isHidden = true
            self?.overlayWindow = nil
            self?.hostingController = nil
            self?.currentNotification = nil
            
            print("📲 InApp: Dismissed notification")
            
            // Show next in queue after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task { @MainActor [weak self] in
                    guard let self = self, !self.notificationQueue.isEmpty else { return }
                    let next = self.notificationQueue.removeFirst()
                    self.displayNotification(next, duration: 3.5)
                }
            }
        })
    }
    
}

// MARK: - Window Content View

/// The content view for the notification window - handles its own animation state
private struct InAppNotificationWindowContent: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack {
            if isVisible {
                InAppNotificationToastView(
                    notification: notification,
                    onDismiss: onDismiss
                )
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -50 {
                                // Swipe up to dismiss
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = -200
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDismiss()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding(.top, 60) // Below status bar and notch
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Toast View

/// The actual toast notification view
private struct InAppNotificationToastView: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    
    @State private var isGlowing = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with subtle accent
            ZStack {
                // Icon background with accent color
                Circle()
                    .fill(notification.type.backgroundColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(notification.type.backgroundColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.type.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(notification.type.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
        .onAppear {
            isGlowing = true
        }
    }
}
