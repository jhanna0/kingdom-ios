import SwiftUI

/// Settings view with sign out, music, and notification controls
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var musicService: MusicService
    @Environment(\.dismiss) var dismiss
    
    @State private var notificationsEnabled = false
    @State private var showLogoutConfirmation = false
    @State private var isCheckingNotifications = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 48))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Settings")
                        .font(KingdomTheme.Typography.title())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.top, 20)
                
                // Audio Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio")
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 16)
                    
                    // Music Toggle
                    HStack {
                        Image(systemName: musicService.isMusicEnabled ? "music.note" : "music.note.slash")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Background Music")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        Toggle("", isOn: $musicService.isMusicEnabled)
                            .labelsHidden()
                            .tint(KingdomTheme.Colors.buttonPrimary)
                    }
                    .padding()
                    .brutalistCard(
                        backgroundColor: KingdomTheme.Colors.parchmentLight,
                        cornerRadius: 12
                    )
                    
                    // Sound Effects Toggle
                    HStack {
                        Image(systemName: musicService.isSoundEffectsEnabled ? "speaker.wave.3" : "speaker.slash")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Sound Effects")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        Toggle("", isOn: $musicService.isSoundEffectsEnabled)
                            .labelsHidden()
                            .tint(KingdomTheme.Colors.buttonPrimary)
                    }
                    .padding()
                    .brutalistCard(
                        backgroundColor: KingdomTheme.Colors.parchmentLight,
                        cornerRadius: 12
                    )
                }
                
                // Notifications Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notifications")
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 16)
                    
                    // Notification Toggle
                    HStack {
                        Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Action Notifications")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            if isCheckingNotifications {
                                Text("Checking permissions...")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.inkSubtle)
                            } else if !notificationsEnabled {
                                Text("Enable in System Settings")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(KingdomTheme.Colors.error)
                            }
                        }
                        
                        Spacer()
                        
                        if !isCheckingNotifications {
                            Toggle("", isOn: Binding(
                                get: { notificationsEnabled },
                                set: { newValue in
                                    if newValue && !notificationsEnabled {
                                        // Request permission
                                        Task {
                                            await requestNotificationPermission()
                                        }
                                    } else if !newValue {
                                        // User wants to disable - direct to settings
                                        openAppSettings()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(KingdomTheme.Colors.buttonSuccess)
                            .disabled(!notificationsEnabled && !isCheckingNotifications)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: KingdomTheme.Colors.loadingTint))
                        }
                    }
                    .padding()
                    .brutalistCard(
                        backgroundColor: KingdomTheme.Colors.parchmentLight,
                        cornerRadius: 12
                    )
                }
                
                // Data Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data")
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 16)
                    
                    // Clear Cache Button
                    Button {
                        Task {
                            try? await TierManager.shared.forceRefresh()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(FontStyles.iconSmall)
                            Text("Clear Cache & Refresh")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkSubtle)
                        }
                        .padding()
                    }
                    .brutalistCard(
                        backgroundColor: KingdomTheme.Colors.parchmentLight,
                        cornerRadius: 12
                    )
                }
                
                // Account Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account")
                        .font(KingdomTheme.Typography.headline())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal, 16)
                    
                    // Logout Button
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(FontStyles.iconSmall)
                            Text("Sign Out")
                                .font(FontStyles.bodyMediumBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await checkNotificationStatus()
        }
        .alert("Sign Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.logout()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Notification Helpers
    
    private func checkNotificationStatus() async {
        let authorized = await NotificationManager.shared.checkPermission()
        await MainActor.run {
            notificationsEnabled = authorized
            isCheckingNotifications = false
        }
    }
    
    private func requestNotificationPermission() async {
        let granted = await NotificationManager.shared.requestPermission()
        await MainActor.run {
            notificationsEnabled = granted
            if !granted {
                // If denied, prompt user to go to settings
                openAppSettings()
            }
        }
    }
    
    private func openAppSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager())
            .environmentObject(MusicService.shared)
    }
}
