import SwiftUI
import StoreKit
import Combine

struct SubscriberSettingsView: View {
    @EnvironmentObject var player: Player
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SubscriberSettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.settings == nil {
                    ProgressView().padding(.vertical, 40)
                } else if !viewModel.isSubscriber {
                    subscribeSection
                } else {
                    previewSection
                    iconStyleSection
                    cardStyleSection
                    titleSection
                    saveButton
                }
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Customize Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadSettings() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var subscribeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundColor(KingdomTheme.Colors.inkSubtle)
            Text("Become a Supporter").font(KingdomTheme.Typography.headline()).fontWeight(.bold)
            
            if let sub = StoreService.shared.subscriptionProducts.first {
                Button {
                    Task {
                        if await StoreService.shared.purchaseSubscription(sub) {
                            await viewModel.loadSettings()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Subscribe - \(sub.displayPrice)/month").fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 12)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview").font(FontStyles.headingSmall).foregroundColor(KingdomTheme.Colors.inkDark)
            
            ProfileHeaderCard(
                displayName: player.name,
                level: player.level,
                customization: viewModel.previewCustomization,
                isSubscriber: true
            )
        }
    }
    
    private var iconStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Icon Style").font(FontStyles.headingSmall).foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                if viewModel.selectedIconStyle != nil {
                    Button("Reset") { viewModel.selectedIconStyle = nil }
                        .font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            StyleGrid(styles: viewModel.availableStyles, selectedStyle: $viewModel.selectedIconStyle)
        }
    }
    
    private var cardStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Card Style").font(FontStyles.headingSmall).foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                if viewModel.selectedCardStyle != nil {
                    Button("Reset") { viewModel.selectedCardStyle = nil }
                        .font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            StyleGrid(styles: viewModel.availableStyles, selectedStyle: $viewModel.selectedCardStyle, isCard: true)
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Title").font(FontStyles.headingSmall).foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                if viewModel.selectedTitle != nil {
                    Button("Reset") { viewModel.selectedTitle = nil }
                        .font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
            
            if viewModel.availableTitles.isEmpty {
                Text("Earn achievements to unlock titles!")
                    .font(FontStyles.bodyMedium).foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(KingdomTheme.Colors.parchmentLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.availableTitles, id: \.achievementId) { title in
                        Button {
                            viewModel.selectedTitle = title
                        } label: {
                            HStack {
                                Image(systemName: title.icon).font(.system(size: 20)).foregroundColor(KingdomTheme.Colors.imperialGold).frame(width: 32)
                                Text(title.displayName).font(FontStyles.bodyMedium).foregroundColor(KingdomTheme.Colors.inkDark)
                                Spacer()
                                if viewModel.selectedTitle?.achievementId == title.achievementId {
                                    Image(systemName: "checkmark").foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if title.achievementId != viewModel.availableTitles.last?.achievementId { Divider() }
                    }
                }
                .background(KingdomTheme.Colors.parchmentLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var saveButton: some View {
        Button {
            viewModel.saveSettings()
        } label: {
            HStack {
                if viewModel.isSaving { ProgressView().tint(.white) }
                else { Image(systemName: "checkmark"); Text("Save Changes") }
            }
            .font(FontStyles.bodyMediumBold).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .brutalistBadge(backgroundColor: viewModel.hasChanges ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled, cornerRadius: 10)
        .disabled(!viewModel.hasChanges || viewModel.isSaving)
    }
}

// MARK: - Style Grid (shows preset style swatches with brutalist styling)

private struct StyleGrid: View {
    let styles: [APIStylePreset]
    @Binding var selectedStyle: APIStylePreset?
    var isCard: Bool = false
    
    private let columns = [GridItem(.adaptive(minimum: 80))]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // Default/None option
            Button { selectedStyle = nil } label: {
                VStack(spacing: 6) {
                    if isCard {
                        Text("Abc")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
                    } else {
                        Text("A")
                            .font(FontStyles.headingSmall)
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .brutalistBadge(backgroundColor: .white, cornerRadius: 12, shadowOffset: 2, borderWidth: 2)
                    }
                    Text("Default")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
                .padding(8)
                .background(selectedStyle == nil ? KingdomTheme.Colors.imperialGold.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selectedStyle == nil ? KingdomTheme.Colors.imperialGold : Color.clear, lineWidth: 3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            
            // Style presets
            ForEach(styles) { style in
                Button { selectedStyle = style } label: {
                    VStack(spacing: 6) {
                        if isCard {
                            Text("Abc")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(style.textColorValue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .brutalistBadge(backgroundColor: style.backgroundColorValue, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
                        } else {
                            Text("A")
                                .font(FontStyles.headingSmall)
                                .foregroundColor(style.textColorValue)
                                .frame(width: 48, height: 48)
                                .brutalistBadge(backgroundColor: style.backgroundColorValue, cornerRadius: 12, shadowOffset: 2, borderWidth: 2)
                        }
                        Text(style.name)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(selectedStyle?.id == style.id ? KingdomTheme.Colors.imperialGold.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedStyle?.id == style.id ? KingdomTheme.Colors.imperialGold : Color.clear, lineWidth: 3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
}

// MARK: - View Model

class SubscriberSettingsViewModel: ObservableObject {
    @Published var settings: SubscriberSettingsResponse?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    @Published var selectedIconStyle: APIStylePreset?
    @Published var selectedCardStyle: APIStylePreset?
    @Published var selectedTitle: APITitleData?
    
    private var originalIconStyleId: String?
    private var originalCardStyleId: String?
    private var originalTitleId: Int?
    
    var isSubscriber: Bool { settings?.isSubscriber ?? false }
    var availableStyles: [APIStylePreset] { settings?.availableStyles ?? [] }
    var availableTitles: [APITitleData] { settings?.availableTitles ?? [] }
    
    var hasChanges: Bool {
        selectedIconStyle?.id != originalIconStyleId ||
        selectedCardStyle?.id != originalCardStyleId ||
        selectedTitle?.achievementId != originalTitleId
    }
    
    var previewCustomization: APISubscriberCustomization {
        APISubscriberCustomization(
            iconStyle: selectedIconStyle,
            cardStyle: selectedCardStyle,
            selectedTitle: selectedTitle
        )
    }
    
    @MainActor
    func loadSettings() async {
        isLoading = true
        do {
            let response = try await KingdomAPIService.shared.player.getSubscriberSettings()
            settings = response
            selectedIconStyle = response.iconStyle
            selectedCardStyle = response.cardStyle
            selectedTitle = response.selectedTitle
            
            originalIconStyleId = response.iconStyle?.id
            originalCardStyleId = response.cardStyle?.id
            originalTitleId = response.selectedTitle?.achievementId
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    func saveSettings() {
        guard hasChanges else { return }
        isSaving = true
        
        Task { @MainActor in
            do {
                let update = SubscriberSettingsUpdateRequest(
                    iconStyleId: selectedIconStyle?.id,
                    cardStyleId: selectedCardStyle?.id,
                    selectedTitleAchievementId: selectedTitle?.achievementId ?? 0
                )
                let response = try await KingdomAPIService.shared.player.updateSubscriberSettings(update)
                settings = response
                originalIconStyleId = selectedIconStyle?.id
                originalCardStyleId = selectedCardStyle?.id
                originalTitleId = selectedTitle?.achievementId
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

// MARK: - API Models

struct SubscriberSettingsResponse: Codable {
    let isSubscriber: Bool
    let iconStyle: APIStylePreset?
    let cardStyle: APIStylePreset?
    let selectedTitle: APITitleData?
    let availableStyles: [APIStylePreset]
    let availableTitles: [APITitleData]
    
    enum CodingKeys: String, CodingKey {
        case isSubscriber = "is_subscriber"
        case iconStyle = "icon_style"
        case cardStyle = "card_style"
        case selectedTitle = "selected_title"
        case availableStyles = "available_styles"
        case availableTitles = "available_titles"
    }
}

struct SubscriberSettingsUpdateRequest: Codable {
    let iconStyleId: String?
    let cardStyleId: String?
    let selectedTitleAchievementId: Int
    
    enum CodingKeys: String, CodingKey {
        case iconStyleId = "icon_style_id"
        case cardStyleId = "card_style_id"
        case selectedTitleAchievementId = "selected_title_achievement_id"
    }
}

#Preview {
    NavigationView {
        SubscriberSettingsView().environmentObject(Player())
    }
}
