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
                    iconColorSection
                    cardColorSection
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
            Text("Preview").font(FontStyles.labelSmall).foregroundColor(KingdomTheme.Colors.inkMedium)
            
            ProfileHeaderCard(
                displayName: player.name,
                level: player.level,
                customization: viewModel.previewCustomization,
                isSubscriber: true
            )
        }
    }
    
    private var iconColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Background").font(FontStyles.headingSmall)
            ColorPalette(selectedHex: $viewModel.iconBackgroundColor)
            
            Text("Icon Text").font(FontStyles.headingSmall).padding(.top, 8)
            ColorPalette(selectedHex: $viewModel.iconTextColor)
        }
    }
    
    private var cardColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Background").font(FontStyles.headingSmall)
            ColorPalette(selectedHex: $viewModel.cardBackgroundColor)
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Title").font(FontStyles.headingSmall)
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

// MARK: - Color Palette

private struct ColorPalette: View {
    @Binding var selectedHex: String?
    
    private let colors: [(String, String)] = [
        ("#6B21A8", "Purple"), ("#7C3AED", "Violet"), ("#166534", "Forest"),
        ("#059669", "Emerald"), ("#1E40AF", "Blue"), ("#0284C7", "Sky"),
        ("#991B1B", "Crimson"), ("#DC2626", "Ruby"), ("#CA8A04", "Gold"),
        ("#D97706", "Amber"), ("#475569", "Slate"), ("#1F2937", "Charcoal"),
        ("#BE185D", "Rose"), ("#0D9488", "Teal"), ("#4338CA", "Indigo"),
        ("#FFFFFF", "White"), ("#000000", "Black")
    ]
    
    private let columns = [GridItem(.adaptive(minimum: 44))]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            // None option
            Button { selectedHex = nil } label: {
                ZStack {
                    Circle().stroke(Color.gray, lineWidth: 1).frame(width: 40, height: 40)
                    if selectedHex == nil {
                        Image(systemName: "xmark").foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)
            
            ForEach(colors, id: \.0) { hex, _ in
                Button { selectedHex = hex } label: {
                    ZStack {
                        Circle().fill(Color(hex: hex) ?? .gray).frame(width: 40, height: 40)
                        if selectedHex == hex {
                            Circle().stroke(Color.white, lineWidth: 3).frame(width: 40, height: 40)
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(KingdomTheme.Colors.parchmentLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - View Model

class SubscriberSettingsViewModel: ObservableObject {
    @Published var settings: SubscriberSettingsResponse?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    @Published var iconBackgroundColor: String?
    @Published var iconTextColor: String?
    @Published var cardBackgroundColor: String?
    @Published var selectedTitle: APITitleData?
    
    private var originalIconBg: String?
    private var originalIconText: String?
    private var originalCardBg: String?
    private var originalTitleId: Int?
    
    var isSubscriber: Bool { settings?.isSubscriber ?? false }
    var availableTitles: [APITitleData] { settings?.availableTitles ?? [] }
    
    var hasChanges: Bool {
        iconBackgroundColor != originalIconBg ||
        iconTextColor != originalIconText ||
        cardBackgroundColor != originalCardBg ||
        selectedTitle?.achievementId != originalTitleId
    }
    
    var previewCustomization: APISubscriberCustomization {
        APISubscriberCustomization(
            iconBackgroundColor: iconBackgroundColor,
            iconTextColor: iconTextColor,
            cardBackgroundColor: cardBackgroundColor,
            selectedTitle: selectedTitle
        )
    }
    
    @MainActor
    func loadSettings() async {
        isLoading = true
        do {
            let response = try await APIClient.shared.player.getSubscriberSettings()
            settings = response
            iconBackgroundColor = response.iconBackgroundColor
            iconTextColor = response.iconTextColor
            cardBackgroundColor = response.cardBackgroundColor
            selectedTitle = response.selectedTitle
            
            originalIconBg = response.iconBackgroundColor
            originalIconText = response.iconTextColor
            originalCardBg = response.cardBackgroundColor
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
                    iconBackgroundColor: iconBackgroundColor,
                    iconTextColor: iconTextColor,
                    cardBackgroundColor: cardBackgroundColor,
                    selectedTitleAchievementId: selectedTitle?.achievementId ?? 0
                )
                let response = try await APIClient.shared.player.updateSubscriberSettings(update)
                settings = response
                originalIconBg = iconBackgroundColor
                originalIconText = iconTextColor
                originalCardBg = cardBackgroundColor
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
    let iconBackgroundColor: String?
    let iconTextColor: String?
    let cardBackgroundColor: String?
    let selectedTitle: APITitleData?
    let availableTitles: [APITitleData]
    
    enum CodingKeys: String, CodingKey {
        case isSubscriber = "is_subscriber"
        case iconBackgroundColor = "icon_background_color"
        case iconTextColor = "icon_text_color"
        case cardBackgroundColor = "card_background_color"
        case selectedTitle = "selected_title"
        case availableTitles = "available_titles"
    }
}

struct SubscriberSettingsUpdateRequest: Codable {
    let iconBackgroundColor: String?
    let iconTextColor: String?
    let cardBackgroundColor: String?
    let selectedTitleAchievementId: Int
    
    enum CodingKeys: String, CodingKey {
        case iconBackgroundColor = "icon_background_color"
        case iconTextColor = "icon_text_color"
        case cardBackgroundColor = "card_background_color"
        case selectedTitleAchievementId = "selected_title_achievement_id"
    }
}

#Preview {
    NavigationView {
        SubscriberSettingsView().environmentObject(Player())
    }
}
