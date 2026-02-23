import SwiftUI

/// Workshop view - Craft items using blueprints + materials
/// Uses contract system: start craft → work actions → complete
struct WorkshopView: View {
    @State private var status: WorkshopStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showResultOverlay = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    
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
            if showResultOverlay {
                ResultOverlay(
                    success: resultSuccess,
                    message: resultMessage,
                    isShowing: $showResultOverlay
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
        
        // Active Contract Section (if crafting in progress)
        if let contract = status.activeContract {
            activeContractCard(contract: contract)
        }
        
        // Craftable items section (only show if no active contract)
        if status.activeContract == nil {
            if status.craftableItems.isEmpty {
                emptyRecipesCard
            } else {
                craftableItemsSection(items: status.craftableItems, status: status)
            }
        }
    }
    
    // MARK: - Workshop Header Card
    
    private func workshopHeaderCard(status: WorkshopStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
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
            
            if status.hasWorkshop && status.blueprintCount == 0 && status.activeContract == nil {
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
    
    // MARK: - Active Contract Card
    
    private func activeContractCard(contract: ActiveCraftContract) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "gearshape.2.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                
                Text("Crafting in Progress")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Item being crafted
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: contract.icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.color(fromThemeName: contract.color),
                        cornerRadius: 14,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(contract.displayName)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Progress
                    HStack(spacing: 8) {
                        Text("\(contract.actionsCompleted)/\(contract.actionsRequired) actions")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("(\(contract.progressPercent)%)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KingdomTheme.Colors.disabled.opacity(0.3))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KingdomTheme.Colors.buttonSuccess)
                        .frame(width: geo.size.width * CGFloat(contract.progressPercent) / 100)
                }
            }
            .frame(height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black, lineWidth: 2)
            )
            
            // Hint to go to Actions
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(FontStyles.iconSmall)
                Text("Go to Actions to work on this")
                    .font(FontStyles.labelMedium)
            }
            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Craftable Items Section
    
    private func craftableItemsSection(items: [CraftableItem], status: WorkshopStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
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
            
            ForEach(items) { item in
                NavigationLink {
                    CraftDetailView(
                        item: item,
                        blueprintCount: status.blueprintCount,
                        hasWorkshop: status.hasWorkshop,
                        onStartCraft: { await startCraft(itemId: item.id) }
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
    
    private func startCraft(itemId: String) async {
        do {
            let response = try await workshopAPI.startCraft(itemId: itemId)
            resultSuccess = response.success
            resultMessage = response.message
            
            await loadWorkshopStatus()
            
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showResultOverlay = true
                }
                
                HapticService.shared.notification(response.success ? .success : .error)
            }
        } catch {
            await MainActor.run {
                resultSuccess = false
                resultMessage = error.localizedDescription
                withAnimation {
                    showResultOverlay = true
                }
                
                HapticService.shared.error()
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
                    
                    // Actions required
                    HStack(spacing: 4) {
                        Image(systemName: "hammer")
                            .font(FontStyles.iconMini)
                        Text("\(item.actionsRequired)")
                            .font(FontStyles.labelBold)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Spacer()
            
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

// MARK: - Craft Detail View

struct CraftDetailView: View {
    let item: CraftableItem
    let blueprintCount: Int
    let hasWorkshop: Bool
    let onStartCraft: () async -> Void
    
    @State private var isStarting = false
    @State private var showConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    private var canCraft: Bool {
        item.canCraft && blueprintCount > 0 && hasWorkshop
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                itemHeroCard
                requirementsCard
                craftActionSection
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .alert("Start Crafting?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Craft") {
                isStarting = true
                Task {
                    await onStartCraft()
                    await MainActor.run {
                        isStarting = false
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will consume 1 blueprint and all required materials. Crafted items cannot be traded.")
        }
    }
    
    private var itemHeroCard: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
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
                
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "hammer.fill")
                            .font(FontStyles.iconMedium)
                        Text("\(item.actionsRequired)")
                            .font(FontStyles.headingMedium)
                    }
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    
                    Text("Actions")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
        }
        .padding(KingdomTheme.Spacing.large)
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
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
            
            requirementRow(
                icon: "scroll.fill",
                iconColor: KingdomTheme.Colors.buttonPrimary,
                label: "Blueprint",
                required: 1,
                available: blueprintCount,
                hasEnough: blueprintCount > 0
            )
            
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
            
            HStack(spacing: 4) {
                Text("\(available)")
                    .foregroundColor(hasEnough ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                Text("/")
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("\(required)")
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .font(FontStyles.bodyMediumBold)
            
            Image(systemName: hasEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(FontStyles.iconMedium)
                .foregroundColor(hasEnough ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
        }
        .padding(.vertical, 8)
    }
    
    private var craftActionSection: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isStarting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hammer.fill")
                    Text(canCraft ? "Start Crafting" : craftBlockReason)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.brutalist(
            backgroundColor: canCraft ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
            foregroundColor: .white,
            fullWidth: true
        ))
        .disabled(!canCraft || isStarting)
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

// MARK: - Result Overlay

struct ResultOverlay: View {
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
