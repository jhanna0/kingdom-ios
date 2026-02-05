import SwiftUI
import StoreKit
import Combine

/// Subscriber profile customization settings
/// All themes and titles are server-driven - no hardcoded values
struct SubscriberSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SubscriberSettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                if viewModel.isLoading && viewModel.settings == nil {
                    loadingSection
                } else if !viewModel.isSubscriber {
                    subscribeSection
                } else {
                    // Preview Card
                    previewSection
                    
                    // Theme Selection
                    themeSection
                    
                    // Title Selection
                    titleSection
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Profile Customization")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(KingdomTheme.Colors.imperialGold)
            
            Text("Supporter Perks")
                .font(KingdomTheme.Typography.title())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Customize how others see you")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.top, 12)
    }
    
    // MARK: - Loading
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: KingdomTheme.Colors.loadingTint))
            Text("Loading settings...")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Subscribe Prompt
    
    private var subscribeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.inkSubtle)
            
            Text("Become a Supporter")
                .font(KingdomTheme.Typography.headline())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(alignment: .leading, spacing: 8) {
                benefitRow(icon: "paintpalette.fill", text: "Custom profile themes")
                benefitRow(icon: "rosette", text: "Achievement titles")
                benefitRow(icon: "pawprint.fill", text: "Show pets on profile")
                benefitRow(icon: "trophy.fill", text: "Display achievements")
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            
            // Subscribe button
            if let subscriptionProduct = StoreService.shared.subscriptionProducts.first {
                Button {
                    Task {
                        let success = await StoreService.shared.purchaseSubscription(subscriptionProduct)
                        if success {
                            await viewModel.loadSettings()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Subscribe - \(subscriptionProduct.displayPrice)/month")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.imperialGold,
                    cornerRadius: 12
                )
            }
        }
        .padding(.vertical, 20)
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(KingdomTheme.Colors.imperialGold)
                .frame(width: 24)
            
            Text(text)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(KingdomTheme.Typography.headline())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.horizontal, 4)
            
            // Preview card with current theme
            HStack(spacing: 12) {
                // Avatar with theme
                ZStack {
                    Circle()
                        .fill(viewModel.selectedTheme?.iconBackgroundColorValue ?? KingdomTheme.Colors.parchmentLight)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.selectedTheme?.textColorValue ?? KingdomTheme.Colors.inkDark)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Name")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(viewModel.selectedTheme?.textColorValue ?? KingdomTheme.Colors.inkDark)
                    
                    if let title = viewModel.selectedTitle {
                        HStack(spacing: 4) {
                            Image(systemName: title.icon)
                                .font(.system(size: 12))
                            Text(title.displayName)
                                .font(FontStyles.labelSmall)
                        }
                        .foregroundColor(viewModel.selectedTheme?.textColorValue.opacity(0.8) ?? KingdomTheme.Colors.inkMedium)
                    }
                    
                    Text("Level 25")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(viewModel.selectedTheme?.textColorValue.opacity(0.6) ?? KingdomTheme.Colors.inkSubtle)
                }
                
                Spacer()
            }
            .padding()
            .background(viewModel.selectedTheme?.backgroundColorValue ?? KingdomTheme.Colors.parchmentLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KingdomTheme.Colors.inkDark, lineWidth: 2)
            )
        }
    }
    
    // MARK: - Theme Selection
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Theme")
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if viewModel.selectedTheme != nil {
                    Button("Clear") {
                        viewModel.selectTheme(nil)
                    }
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            .padding(.horizontal, 4)
            
            // Horizontal scroll of theme cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.availableThemes, id: \.id) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: viewModel.selectedTheme?.id == theme.id,
                            onTap: {
                                viewModel.selectTheme(theme)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Title Selection
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Title")
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if viewModel.selectedTitle != nil {
                    Button("Clear") {
                        viewModel.selectTitle(nil)
                    }
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            .padding(.horizontal, 4)
            
            if viewModel.availableTitles.isEmpty {
                Text("Earn achievements to unlock titles!")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.availableTitles, id: \.achievementId) { title in
                        TitleRow(
                            title: title,
                            isSelected: viewModel.selectedTitle?.achievementId == title.achievementId,
                            onTap: {
                                viewModel.selectTitle(title)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    let theme: APIThemeData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Color preview circle
                Circle()
                    .fill(theme.backgroundColorValue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.textColorValue)
                    )
                
                Text(theme.displayName)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
            }
            .padding(12)
            .background(isSelected ? KingdomTheme.Colors.buttonPrimary.opacity(0.1) : KingdomTheme.Colors.parchmentLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkSubtle, lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Title Row

private struct TitleRow: View {
    let title: APITitleData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: title.icon)
                    .font(.system(size: 20))
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                    .frame(width: 30)
                
                Text(title.displayName)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
            .padding()
            .background(isSelected ? KingdomTheme.Colors.buttonSuccess.opacity(0.1) : KingdomTheme.Colors.parchmentLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? KingdomTheme.Colors.buttonSuccess : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - View Model

@MainActor
class SubscriberSettingsViewModel: ObservableObject {
    @Published var settings: SubscriberSettingsResponse?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    @Published var selectedTheme: APIThemeData?
    @Published var selectedTitle: APITitleData?
    
    private let playerAPI = PlayerAPI()
    
    var isSubscriber: Bool {
        settings?.is_subscriber ?? false
    }
    
    var availableThemes: [APIThemeData] {
        settings?.available_themes ?? []
    }
    
    var availableTitles: [APITitleData] {
        settings?.available_titles ?? []
    }
    
    func loadSettings() async {
        isLoading = true
        
        do {
            let response = try await playerAPI.getSubscriberSettings()
            settings = response
            selectedTheme = response.current_theme
            selectedTitle = response.selected_title
        } catch {
            errorMessage = "Failed to load settings"
            showError = true
        }
        
        isLoading = false
    }
    
    func selectTheme(_ theme: APIThemeData?) {
        selectedTheme = theme
        saveSettings()
    }
    
    func selectTitle(_ title: APITitleData?) {
        selectedTitle = title
        saveSettings()
    }
    
    private func saveSettings() {
        Task {
            do {
                let response = try await playerAPI.updateSubscriberSettings(
                    themeId: selectedTheme?.id ?? "",
                    titleAchievementId: selectedTitle?.achievementId ?? 0
                )
                settings = response
            } catch {
                errorMessage = "Failed to save settings"
                showError = true
                // Revert to server state
                await loadSettings()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriberSettingsView()
    }
}
