import SwiftUI

/// Workshop view - Craft items using blueprints + materials
/// Server-driven: all data comes from /workshop/status
struct WorkshopView: View {
    @State private var status: WorkshopStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCraftResult = false
    @State private var craftResultMessage = ""
    @State private var craftResultSuccess = false
    
    private let workshopAPI = WorkshopAPI()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
            if isLoading {
                    loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let status = status {
                workshopContent(status: status)
            }
        }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .task {
            await loadWorkshopStatus()
        }
        .refreshable {
            await loadWorkshopStatus()
        }
        .overlay {
            if showCraftResult {
                CraftResultOverlay(
                    success: craftResultSuccess,
                    message: craftResultMessage,
                    isShowing: $showCraftResult
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(KingdomTheme.Colors.loadingTint)
            Text("Loading workshop...")
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func workshopContent(status: WorkshopStatusResponse) -> some View {
        // Workshop Header Card
        workshopHeaderCard(status: status)
        
        // Craftable items section
                if status.craftableItems.isEmpty {
            emptyRecipesCard
                } else {
            craftableItemsSection(items: status.craftableItems, status: status)
        }
    }
    
    // MARK: - Workshop Header Card
    
    private func workshopHeaderCard(status: WorkshopStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header row: Icon + Title + Blueprint count
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                // Workshop icon
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: status.hasWorkshop ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.hasWorkshop ? "Workshop" : "No Workshop")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if status.hasWorkshop {
                        HStack(spacing: 4) {
                            Image(systemName: "scroll.fill")
                                .font(FontStyles.iconMini)
                            Text("\(status.blueprintCount) blueprint\(status.blueprintCount == 1 ? "" : "s")")
                                .font(FontStyles.labelMedium)
                        }
                        .foregroundColor(status.blueprintCount > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
                    } else {
                        Text(status.workshopRequirement)
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
            }
            
            // Warning banner if no blueprints
            if status.hasWorkshop && status.blueprintCount == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    
                    Text("You need blueprints to craft. Find them through science discoveries!")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KingdomTheme.Colors.buttonWarning.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KingdomTheme.Colors.buttonWarning.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Craftable Items Section
    
    private func craftableItemsSection(items: [CraftableItem], status: WorkshopStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "scroll.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Recipes")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("\(items.count) available")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Item cards as NavigationLinks
            ForEach(items) { item in
                NavigationLink {
                    CraftDetailView(
                        item: item,
                        blueprintCount: status.blueprintCount,
                        hasWorkshop: status.hasWorkshop,
                        onCraft: { await craftItem(itemId: item.id) }
                    )
                } label: {
                    CraftableItemRow(
                    item: item,
                    hasBlueprint: status.blueprintCount > 0,
                        hasWorkshop: status.hasWorkshop
                )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Empty Recipes Card
    
    private var emptyRecipesCard: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "scroll")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.disabled,
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text("No Recipes Available")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Discover blueprints through science to unlock crafting recipes.")
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonDanger,
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text("Something went wrong")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(message)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await loadWorkshopStatus() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - API Calls
    
    private func loadWorkshopStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            status = try await workshopAPI.getStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func craftItem(itemId: String) async {
        do {
            let response = try await workshopAPI.craft(itemId: itemId)
            craftResultSuccess = response.success
            craftResultMessage = response.message
            
            // Reload status to update materials/blueprints
            await loadWorkshopStatus()
            
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showCraftResult = true
                }
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(response.success ? .success : .error)
            }
        } catch {
            await MainActor.run {
                craftResultSuccess = false
                craftResultMessage = error.localizedDescription
                withAnimation {
                    showCraftResult = true
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Craftable Item Row

struct CraftableItemRow: View {
    let item: CraftableItem
    let hasBlueprint: Bool
    let hasWorkshop: Bool
    
    private var canCraft: Bool {
        item.canCraft && hasBlueprint && hasWorkshop
    }
    
    var body: some View {
            HStack(spacing: KingdomTheme.Spacing.medium) {
            // Item icon with brutalist badge
                Image(systemName: item.icon)
                .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.color(fromThemeName: item.color),
                        cornerRadius: 12,
                    shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                    .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Stats preview
                HStack(spacing: 12) {
                        if item.attackBonus > 0 {
                        HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                .font(FontStyles.iconMini)
                                Text("+\(item.attackBonus)")
                                .font(FontStyles.labelBold)
                            }
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        }
                        if item.defenseBonus > 0 {
                        HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                .font(FontStyles.iconMini)
                                Text("+\(item.defenseBonus)")
                                .font(FontStyles.labelBold)
                            }
                            .foregroundColor(KingdomTheme.Colors.royalBlue)
                        }
                    }
                }
                
                Spacer()
                
            // Status badge
            HStack(spacing: 6) {
                    if canCraft {
                    Text("Ready")
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black)
                                    .offset(x: 1, y: 1)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(KingdomTheme.Colors.buttonSuccess)
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.black, lineWidth: 1.5)
                            }
                        )
                    } else {
                    Image(systemName: "lock.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(KingdomTheme.Colors.parchment)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1.5)
            }
        )
    }
}

// MARK: - Craft Detail View (Full page, not sheet)

struct CraftDetailView: View {
    let item: CraftableItem
    let blueprintCount: Int
    let hasWorkshop: Bool
    let onCraft: () async -> Void
    
    @State private var isCrafting = false
    @Environment(\.dismiss) var dismiss
    
    private var canCraft: Bool {
        item.canCraft && blueprintCount > 0 && hasWorkshop
    }
    
    var body: some View {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                // Item hero card
                itemHeroCard
                
                // Requirements card
                requirementsCard
                
                // Craft button section
                craftActionSection
                }
                .padding()
            }
        .parchmentBackground()
        .navigationTitle(item.displayName)
            .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
    }
    
    // MARK: - Item Hero Card
    
    private var itemHeroCard: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Large item icon
            Image(systemName: item.icon)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.color(fromThemeName: item.color),
                    cornerRadius: 24,
                    shadowOffset: 5,
                    borderWidth: 3
                )
            
            Text(item.displayName)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(item.description)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Stats row
            HStack(spacing: KingdomTheme.Spacing.xxLarge) {
                if item.attackBonus > 0 {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(FontStyles.iconMedium)
                            Text("+\(item.attackBonus)")
                                .font(FontStyles.headingMedium)
                        }
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        
                        Text("Attack")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                if item.defenseBonus > 0 {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                                .font(FontStyles.iconMedium)
                            Text("+\(item.defenseBonus)")
                                .font(FontStyles.headingMedium)
                        }
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                        
                        Text("Defense")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.large)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Requirements Card
    
    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Requirements")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Blueprint requirement
            requirementRow(
                icon: "scroll.fill",
                iconColor: KingdomTheme.Colors.buttonPrimary,
                label: "Blueprint",
                required: 1,
                available: blueprintCount,
                hasEnough: blueprintCount > 0
            )
            
            // Material requirements
            ForEach(item.recipe) { ingredient in
                requirementRow(
                    icon: ingredient.icon,
                    iconColor: KingdomTheme.Colors.color(fromThemeName: ingredient.color),
                    label: ingredient.displayName,
                    required: ingredient.required,
                    available: ingredient.playerHas,
                    hasEnough: ingredient.hasEnough
                )
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func requirementRow(icon: String, iconColor: Color, label: String, required: Int, available: Int, hasEnough: Bool) -> some View {
        HStack(spacing: 12) {
            // Material icon
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1.5)
                    }
                )
            
            Text(label)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            // Amount: have/need
            HStack(spacing: 4) {
                Text("\(available)")
                    .foregroundColor(hasEnough ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                Text("/")
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("\(required)")
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .font(FontStyles.bodyMediumBold)
            
            // Status icon
            Image(systemName: hasEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(FontStyles.iconMedium)
                .foregroundColor(hasEnough ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Craft Action Section
    
    private var craftActionSection: some View {
        VStack(spacing: KingdomTheme.Spacing.small) {
            Button {
                isCrafting = true
                Task {
                    await onCraft()
                    await MainActor.run {
                        isCrafting = false
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isCrafting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "hammer.fill")
                        Text("Craft \(item.displayName)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(
                backgroundColor: canCraft ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
                foregroundColor: .white,
                fullWidth: true
            ))
            .disabled(!canCraft || isCrafting)
            
            // Show reason if can't craft
            if !canCraft {
                Text(craftBlockReason)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
    }
    
    private var craftBlockReason: String {
        if !hasWorkshop {
            return "Workshop required (Property Tier 3+)"
        } else if blueprintCount == 0 {
            return "Need a blueprint to craft"
        } else if !item.canCraft {
            return "Missing materials"
        }
        return ""
    }
}

// MARK: - Craft Result Overlay

struct CraftResultOverlay: View {
    let success: Bool
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
            
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Icon
                Image(systemName: success ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(
                        backgroundColor: success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 24,
                        shadowOffset: 5,
                        borderWidth: 3
                    )
                
                Text(success ? "Success!" : "Failed")
                    .font(FontStyles.displaySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(message)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("OK") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
            }
            .padding(KingdomTheme.Spacing.xxLarge)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(KingdomTheme.Colors.parchment)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black, lineWidth: 3)
                }
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkshopView()
    }
}
