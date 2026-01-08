import SwiftUI
import UIKit

/// Window-based blocking error that appears ABOVE everything including sheets
/// Uses a separate UIWindow to guarantee it's always on top
class BlockingErrorWindow {
    static let shared = BlockingErrorWindow()
    
    private var window: UIWindow?
    private var hostingController: UIHostingController<AnyView>?
    
    private init() {}
    
    /// Show blocking error above all content
    @MainActor
    func show(title: String, message: String, retryAction: @escaping () -> Void) {
        guard window == nil else { return } // Already showing
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            print("❌ BlockingErrorWindow: No window scene available")
            return
        }
        
        let errorView = BlockingErrorView(
            title: title,
            message: message,
            primaryAction: .init(
                label: "Retry",
                icon: "arrow.triangle.2.circlepath",
                color: KingdomTheme.Colors.buttonPrimary,
                action: retryAction
            ),
            secondaryAction: nil
        )
        
        let containerView = ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            errorView
        }
        
        let hostingController = UIHostingController(rootView: AnyView(containerView))
        hostingController.view.backgroundColor = .clear
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        window.windowLevel = .alert + 1 // Above alerts
        window.backgroundColor = .clear
        window.makeKeyAndVisible()
        
        self.window = window
        self.hostingController = hostingController
        
        print("🚨 BlockingErrorWindow: SHOWN")
    }
    
    /// Hide the blocking error
    @MainActor
    func hide() {
        window?.isHidden = true
        window = nil
        hostingController = nil
        print("✅ BlockingErrorWindow: HIDDEN")
    }
}
