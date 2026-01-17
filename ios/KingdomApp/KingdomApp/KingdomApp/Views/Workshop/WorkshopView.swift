import SwiftUI

/// Workshop view - Craft items using blueprints + materials
/// Server-driven: all data comes from /workshop/status
struct WorkshopView: View {
    @State private var status: WorkshopStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedItem: CraftableItem?
    @State private var showCraftResult = false
    @State private var craftResultMessage = ""
    @State private var craftResultSuccess = false
    
    private let workshopAPI = WorkshopAPI()
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(KingdomTheme.Colors.loadingTint)
            } else if let error = errorMessage {
                errorView(error)
            } else if let status = status {
                workshopContent(status: status)
            }
        }
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .task {
            await loadWorkshopStatus()
        }
        .refreshable {
            await loadWorkshopStatus()
        }
        .sheet(item: $selectedItem) { item in
            CraftDetailSheet(
                item: item,
                blueprintCount: status?.blueprintCount ?? 0,
                hasWorkshop: status?.hasWorkshop ?? false,
                onCraft: { await craftItem(itemId: item.id) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
    
    // MARK: - Content
    
    @ViewBuilder
    private func workshopContent(status: WorkshopStatusResponse) -> some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Workshop header with blueprint count
                workshopHeader(status: status)
                
                // Craftable items list
                if status.craftableItems.isEmpty {
                    emptyState
                } else {
                    craftableItemsList(items: status.craftableItems, status: status)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Workshop Header
    
    private func workshopHeader(status: WorkshopStatusResponse) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Workshop icon
                Image(systemName: "hammer.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .brutalistBadge(
                        backgroundColor: status.hasWorkshop ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled,
                        cornerRadius: 14,
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
                                .font(.caption)
                            Text("\(status.blueprintCount) blueprint\(status.blueprintCount == 1 ? "" : "s")")
                                .font(FontStyles.bodySmall)
                        }
                        .foregroundColor(status.blueprintCount > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
                    } else {
                        Text(status.workshopRequirement)
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                }
                
                Spacer()
            }
            
            // No blueprints warning
            if status.hasWorkshop && status.blueprintCount == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    Text("You need blueprints to craft. Find them through science discoveries!")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding(.top, 4)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Craftable Items List
    
    private func craftableItemsList(items: [CraftableItem], status: WorkshopStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Section header
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Craftable Items")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            // Item cards
            ForEach(items) { item in
                CraftableItemCard(
                    item: item,
                    hasBlueprint: status.blueprintCount > 0,
                    hasWorkshop: status.hasWorkshop,
                    onTap: { selectedItem = item }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundColor(KingdomTheme.Colors.disabled)
            
            Text("No Recipes")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("No craftable items available yet.")
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
            
            Text(message)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await loadWorkshopStatus() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .padding()
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
                selectedItem = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showCraftResult = true
                }
            }
        } catch {
            await MainActor.run {
                craftResultSuccess = false
                craftResultMessage = error.localizedDescription
                withAnimation {
                    showCraftResult = true
                }
            }
        }
    }
}

// MARK: - Craftable Item Card

struct CraftableItemCard: View {
    let item: CraftableItem
    let hasBlueprint: Bool
    let hasWorkshop: Bool
    let onTap: () -> Void
    
    private var canCraft: Bool {
        item.canCraft && hasBlueprint && hasWorkshop
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                // Item icon
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.color(fromThemeName: item.color),
                        cornerRadius: 12,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Stats preview
                    HStack(spacing: 8) {
                        if item.attackBonus > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption2)
                                Text("+\(item.attackBonus)")
                                    .font(FontStyles.bodySmall)
                            }
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        }
                        if item.defenseBonus > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "shield.fill")
                                    .font(.caption2)
                                Text("+\(item.defenseBonus)")
                                    .font(FontStyles.bodySmall)
                            }
                            .foregroundColor(KingdomTheme.Colors.royalBlue)
                        }
                    }
                }
                
                Spacer()
                
                // Status indicator
                VStack {
                    if canCraft {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(KingdomTheme.Colors.disabled)
                    }
                }
                .font(.title3)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            .padding(KingdomTheme.Spacing.medium)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Craft Detail Sheet

struct CraftDetailSheet: View {
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
        NavigationStack {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Item preview
                    itemPreview
                    
                    // Blueprint cost
                    blueprintCost
                    
                    // Recipe ingredients
                    recipeSection
                    
                    // Craft button
                    craftButton
                }
                .padding()
            }
            .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
            .navigationTitle("Craft Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
        }
    }
    
    // MARK: - Item Preview
    
    private var itemPreview: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Item icon
            Image(systemName: item.icon)
                .font(.system(size: 48))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.color(fromThemeName: item.color),
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text(item.displayName)
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(item.description)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            // Stats
            HStack(spacing: KingdomTheme.Spacing.large) {
                if item.attackBonus > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("+\(item.attackBonus)")
                                .font(FontStyles.bodyMediumBold)
                        }
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        Text("Attack")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                if item.defenseBonus > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .font(.caption)
                            Text("+\(item.defenseBonus)")
                                .font(FontStyles.bodyMediumBold)
                        }
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                        Text("Defense")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Blueprint Cost
    
    private var blueprintCost: some View {
        HStack {
            Image(systemName: "scroll.fill")
                .font(.title3)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 32)
            
            Text("Blueprint")
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(blueprintCount)")
                    .foregroundColor(blueprintCount > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                Text("/")
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("1")
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .font(FontStyles.bodyMediumBold)
            
            Image(systemName: blueprintCount > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(blueprintCount > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Recipe Section
    
    private var recipeSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("Materials Required")
                    .font(FontStyles.headingSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            ForEach(item.recipe) { ingredient in
                IngredientRow(ingredient: ingredient)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Craft Button
    
    private var craftButton: some View {
        VStack(spacing: 8) {
            Button {
                isCrafting = true
                Task {
                    await onCraft()
                    isCrafting = false
                }
            } label: {
                HStack {
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
                fullWidth: true
            ))
            .disabled(!canCraft || isCrafting)
            
            if !canCraft {
                if blueprintCount == 0 {
                    Text("Need a blueprint")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                } else {
                    Text("Missing materials")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                }
            }
        }
    }
}

// MARK: - Ingredient Row

struct IngredientRow: View {
    let ingredient: RecipeIngredient
    
    var body: some View {
        HStack {
            // Material icon
            Image(systemName: ingredient.icon)
                .font(.title3)
                .foregroundColor(KingdomTheme.Colors.color(fromThemeName: ingredient.color))
                .frame(width: 32)
            
            Text(ingredient.displayName)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            // Amount: have/need
            HStack(spacing: 4) {
                Text("\(ingredient.playerHas)")
                    .foregroundColor(ingredient.hasEnough ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                Text("/")
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("\(ingredient.required)")
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .font(FontStyles.bodyMediumBold)
            
            // Status icon
            Image(systemName: ingredient.hasEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(ingredient.hasEnough ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Craft Result Overlay

struct CraftResultOverlay: View {
    let success: Bool
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isShowing = false }
                }
            
            VStack(spacing: KingdomTheme.Spacing.large) {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                
                Text(success ? "Success!" : "Failed")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(message)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                
                Button("OK") {
                    withAnimation { isShowing = false }
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
            }
            .padding(KingdomTheme.Spacing.xxLarge)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkshopView()
    }
}
