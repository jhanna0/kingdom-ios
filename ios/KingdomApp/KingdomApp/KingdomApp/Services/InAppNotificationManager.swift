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
        
        // Create the toast view
        let toastView = InAppNotificationToastView(
            notification: notification,
            onDismiss: { [weak self] in
                self?.dismissCurrent()
            }
        )
        
        let hostingController = UIHostingController(rootView: AnyView(toastView))
        hostingController.view.backgroundColor = .clear
        
        // Size to fit the content
        let screenWidth = windowScene.screen.bounds.width
        let targetSize = hostingController.sizeThatFits(in: CGSize(width: screenWidth - 32, height: .infinity))
        
        // Create a small window just for the toast - NOT full screen
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(
            x: 16,
            y: 60, // Below status bar/notch
            width: screenWidth - 32,
            height: targetSize.height + 20
        )
        window.rootViewController = hostingController
        window.windowLevel = UIWindow.Level(rawValue: CGFloat.greatestFiniteMagnitude)
        window.backgroundColor = .clear
        window.clipsToBounds = false
        window.isHidden = false
        
        self.overlayWindow = window
        self.hostingController = hostingController
        
        // Animate in
        window.transform = CGAffineTransform(translationX: 0, y: -150)
        window.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            window.transform = .identity
            window.alpha = 1
        }
        
        print("📲 InApp: Showing notification - \(notification.type.title)")
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismissCurrent()
        }
    }
    
    /// Dismiss current notification and show next in queue
    @MainActor
    func dismissCurrent() {
        guard let window = overlayWindow else { return }
        
        // Slide up and fade out
        UIView.animate(withDuration: 0.25, animations: {
            window.transform = CGAffineTransform(translationX: 0, y: -150)
            window.alpha = 0
        }, completion: { [weak self] _ in
            window.isHidden = true
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

// MARK: - Toast View

/// The actual toast notification view - uses brutalist style matching TravelNotificationToast
private struct InAppNotificationToastView: View {
    let notification: InAppNotification
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Icon with brutalist badge
            Image(systemName: notification.type.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .brutalistBadge(
                    backgroundColor: notification.type.backgroundColor,
                    cornerRadius: 12,
                    shadowOffset: 3,
                    borderWidth: 2
                )
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.type.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(notification.type.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .background(
            ZStack {
                // Offset shadow (brutalist style)
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                    .fill(Color.black)
                    .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                
                // Main card
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                    .fill(KingdomTheme.Colors.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                    )
            }
        )
        // Soft shadow for extra depth
        .shadow(
            color: KingdomTheme.Shadows.brutalistSoft.color,
            radius: KingdomTheme.Shadows.brutalistSoft.radius,
            x: KingdomTheme.Shadows.brutalistSoft.x,
            y: KingdomTheme.Shadows.brutalistSoft.y
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow dragging up
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        // Swiped up - dismiss
                        onDismiss()
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}
