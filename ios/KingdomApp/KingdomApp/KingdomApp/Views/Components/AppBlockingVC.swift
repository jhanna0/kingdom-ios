import SwiftUI

/// Full-screen blocking view for critical app states
/// - Update required: Forces user to update app
/// - Maintenance mode: Informs user of maintenance
/// - Connection error: Shows connection issues
struct AppBlockingVC: View {
    enum BlockingType {
        case updateRequired
        case maintenance
        case connectionError
    }
    
    let blockingType: BlockingType
    let maintenanceMessage: String
    let updateURLString: String?
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background - parchment theme
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon with brutalist badge
                iconView
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .brutalistBadge(
                        backgroundColor: iconBackgroundColor,
                        cornerRadius: 24,
                        shadowOffset: 6,
                        borderWidth: 4
                    )
                
                VStack(spacing: 16) {
                    // Title
                    Text(titleText)
                        .font(KingdomTheme.Typography.largeTitle())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                    
                    // Message card with brutalist styling
                    Text(messageText)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .brutalistCard(
                            backgroundColor: KingdomTheme.Colors.parchmentLight,
                            borderColor: Color.black,
                            cornerRadius: 16
                        )
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action button with brutalist style
                if blockingType == .updateRequired {
                    Button(action: openUpdateURL) {
                        Text("Update Now")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.brutalist(
                        backgroundColor: KingdomTheme.Colors.buttonPrimary,
                        foregroundColor: .white,
                        fullWidth: true
                    ))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var iconBackgroundColor: Color {
        switch blockingType {
        case .updateRequired:
            return KingdomTheme.Colors.buttonPrimary
        case .maintenance:
            return KingdomTheme.Colors.buttonWarning
        case .connectionError:
            return KingdomTheme.Colors.buttonDanger
        }
    }
    
    // MARK: - Content
    
    private var iconView: some View {
        Group {
            switch blockingType {
            case .updateRequired:
                Image(systemName: "arrow.up.circle.fill")
            case .maintenance:
                Image(systemName: "wrench.and.screwdriver.fill")
            case .connectionError:
                Image(systemName: "wifi.slash")
            }
        }
    }
    
    private var titleText: String {
        switch blockingType {
        case .updateRequired:
            return "Update Required"
        case .maintenance:
            return "Under Maintenance"
        case .connectionError:
            return "Unable to Connect"
        }
    }
    
    private var messageText: String {
        switch blockingType {
        case .updateRequired:
            return "Please update to continue your conquest!"
        case .maintenance:
            return maintenanceMessage
        case .connectionError:
            return "Unable to connect to Kingdom servers. Please check your internet connection and try again."
        }
    }
    
    // MARK: - Actions
    
    private func openUpdateURL() {
        let urlString = updateURLString ?? "https://testflight.apple.com/join/4jxSyUmW"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Static Convenience Methods
    
    static func showUpdateRequired(updateURLString: String) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let blockingView = AppBlockingVC(
                    blockingType: .updateRequired,
                    maintenanceMessage: "",
                    updateURLString: updateURLString
                )
                let hostingController = UIHostingController(rootView: blockingView)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
            }
        }
    }
    
    static func showMaintenance(message: String = "Kingdom: Territory is currently undergoing maintenance. Please check back later.") {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let blockingView = AppBlockingVC(
                    blockingType: .maintenance,
                    maintenanceMessage: message,
                    updateURLString: nil
                )
                let hostingController = UIHostingController(rootView: blockingView)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
            }
        }
    }
    
    static func showConnectionError() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let blockingView = AppBlockingVC(
                    blockingType: .connectionError,
                    maintenanceMessage: "",
                    updateURLString: nil
                )
                let hostingController = UIHostingController(rootView: blockingView)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
            }
        }
    }
}

// MARK: - Preview

#Preview("Update Required") {
    AppBlockingVC(
        blockingType: .updateRequired,
        maintenanceMessage: "",
        updateURLString: "https://testflight.apple.com/join/4jxSyUmW"
    )
}

#Preview("Maintenance") {
    AppBlockingVC(
        blockingType: .maintenance,
        maintenanceMessage: "Kingdom: Territory is currently undergoing maintenance to improve your experience. Please check back in a few hours.",
        updateURLString: nil
    )
}

#Preview("Connection Error") {
    AppBlockingVC(
        blockingType: .connectionError,
        maintenanceMessage: "",
        updateURLString: nil
    )
}

