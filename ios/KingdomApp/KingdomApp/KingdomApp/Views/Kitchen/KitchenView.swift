import SwiftUI
import Combine

/// Kitchen view - Bake wheat into sourdough bread!
/// Warm bakery-style design with 4 oven slots
struct KitchenView: View {
    @State private var status: KitchenStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showResultOverlay = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    @State private var flavorText: String?
    @State private var actionInProgress: Int? = nil  // slot index being acted on
    @State private var selectedSlot: OvenSlot? = nil  // For detail sheet
    
    // Mini-game state
    @State private var showMiniGame = false
    @State private var miniGameSlotIndex: Int? = nil
    
    // Timer for updating countdowns
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let kitchenAPI = KitchenAPI()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let status = status {
                    kitchenContent(status: status)
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("Kitchen")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .task {
            await loadKitchenStatus()
        }
        .refreshable {
            await loadKitchenStatus()
        }
        .sheet(item: $selectedSlot) { slot in
            if slot.isBaking {
                OvenBakingSheet(slot: slot, currentTime: currentTime)
                    .presentationDetents([.height(420)])
                    .presentationDragIndicator(.hidden)
            } else if slot.isReady {
                OvenReadySheet(slot: slot, onCollect: {
                    performCollect(slotIndex: slot.slotIndex)
                })
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.hidden)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .fullScreenCover(isPresented: $showMiniGame) {
            SourdoughMiniGameView(
                onComplete: {
                    showMiniGame = false
                    // After mini-game, actually load the oven
                    if let slotIndex = miniGameSlotIndex {
                        Task {
                            await loadOven(slotIndex: slotIndex)
                        }
                    }
                    miniGameSlotIndex = nil
                },
                onCancel: {
                    showMiniGame = false
                    miniGameSlotIndex = nil
                }
            )
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(KingdomTheme.Colors.loadingTint)
            Text("Warming up the oven...")
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func kitchenContent(status: KitchenStatusResponse) -> some View {
        if !status.hasKitchen {
            noKitchenView(requirement: status.kitchenRequirement ?? "Upgrade to Villa (Tier 3) to unlock kitchen.")
        } else {
            // Kitchen Header
            kitchenHeaderCard(status: status)
            
            // Oven - The main visual!
            ovenView(slots: status.slots, wheatCount: status.wheatCount)
        }
    }
    
    // MARK: - No Kitchen View
    
    private func noKitchenView(requirement: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "flame.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.disabled,
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text("No Kitchen Yet")
                .font(FontStyles.headingMedium)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(requirement)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Kitchen Header Card
    
    private func kitchenHeaderCard(status: KitchenStatusResponse) -> some View {
        HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
            // Flame icon badge
            Image(systemName: "flame.fill")
                .font(FontStyles.iconLarge)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonWarning,
                    cornerRadius: 12,
                    shadowOffset: 3,
                    borderWidth: 2
                )
            
            // Title and stats
            VStack(alignment: .leading, spacing: 6) {
                Text("My Kitchen")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Wheat available
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(status.wheatCount) wheat available")
                        .font(FontStyles.labelMedium)
                }
                .foregroundColor(status.wheatCount > 0 ? KingdomTheme.Colors.goldLight : KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Status badges on the right
            VStack(alignment: .trailing, spacing: 6) {
                if let stats = status.stats, stats.baking > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(stats.baking)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(KingdomTheme.Colors.buttonWarning)
                            .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                    )
                }
                
                if let stats = status.stats, stats.ready > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(stats.ready)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                    )
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Oven View (Main Visual!)
    
    private func ovenView(slots: [OvenSlot], wheatCount: Int) -> some View {
        GeometryReader { geo in
            let slotSize = (geo.size.width - 60) / 2  // 2 columns with padding
            let slotHeight = slotSize * 0.9  // Slightly shorter than wide
            
            VStack(spacing: 0) {
                // Warm kitchen header
                LinearGradient(
                    colors: [
                        Color(red: 0.85, green: 0.65, blue: 0.45),
                        Color(red: 0.95, green: 0.85, blue: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                
                // Oven body with slots
                ZStack {
                    // Warm brick background
                    LinearGradient(
                        colors: [
                            Color(red: 0.75, green: 0.55, blue: 0.40),
                            Color(red: 0.65, green: 0.45, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Oven slots grid (2x2) - fills the space
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ForEach(slots.prefix(2)) { slot in
                                ovenSlotView(slot: slot, wheatCount: wheatCount, size: slotSize, height: slotHeight)
                            }
                        }
                        HStack(spacing: 16) {
                            ForEach(slots.dropFirst(2).prefix(2)) { slot in
                                ovenSlotView(slot: slot, wheatCount: wheatCount, size: slotSize, height: slotHeight)
                            }
                        }
                    }
                    .padding(20)
                }
                
                // Oven bottom / floor
                ZStack(alignment: .top) {
                    Color(red: 0.55, green: 0.40, blue: 0.30)
                    
                    // Wood floor planks
                    HStack(spacing: 4) {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.65, green: 0.50, blue: 0.40))
                        }
                    }
                    .frame(height: 16)
                    .padding(.horizontal, 8)
                    .offset(y: 4)
                }
                .frame(height: 24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black, lineWidth: 3)
            )
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
            )
        }
        .aspectRatio(0.85, contentMode: .fit)
    }
    
    // MARK: - Oven Slot View
    
    private func ovenSlotView(slot: OvenSlot, wheatCount: Int, size: CGFloat, height: CGFloat) -> some View {
        let isActing = actionInProgress == slot.slotIndex
        
        return Button {
            handleSlotTap(slot: slot, wheatCount: wheatCount)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Oven door frame
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.25, green: 0.15, blue: 0.1))
                    
                    // Oven interior
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ovenInteriorColor(for: slot))
                        .padding(6)
                    
                    // Slot content
                    slotContentView(slot: slot, isActing: isActing, size: size)
                }
                .frame(width: size, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                
                // Badge
                ovenSlotBadge(slot: slot)
            }
        }
        .buttonStyle(.plain)
        .disabled(isActing)
    }
    
    private func ovenInteriorColor(for slot: OvenSlot) -> Color {
        switch slot.status {
        case "baking":
            return Color(red: 0.8, green: 0.3, blue: 0.1)  // Hot orange
        case "ready":
            return Color(red: 0.5, green: 0.35, blue: 0.2)  // Warm brown
        default:
            return Color(red: 0.2, green: 0.12, blue: 0.08)  // Dark interior
        }
    }
    
    private func ovenSlotBadge(slot: OvenSlot) -> some View {
        let text = slotBadgeText(slot: slot)
        let isReady = slot.isReady
        let isBaking = slot.isBaking
        
        return Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(isReady ? .white : KingdomTheme.Colors.inkDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isReady ? KingdomTheme.Colors.buttonSuccess : (isBaking ? KingdomTheme.Colors.buttonWarning : Color.white.opacity(0.9)))
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 1.5)
                    )
            )
    }
    
    private func slotBadgeText(slot: OvenSlot) -> String {
        if slot.isEmpty {
            return "Load"
        } else if slot.isReady {
            return "Collect!"
        } else if slot.isBaking {
            if let seconds = slot.secondsRemaining, seconds > 0 {
                return formatTimeRemaining(seconds: seconds)
            }
            return "Baking..."
        }
        return ""
    }
    
    private func formatTimeRemaining(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    @ViewBuilder
    private func slotContentView(slot: OvenSlot, isActing: Bool, size: CGFloat) -> some View {
        if isActing {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
        } else if slot.isEmpty {
            emptyOvenGraphic(size: size)
        } else if slot.isBaking {
            bakingDoughGraphic(progress: slot.progressPercent ?? 0, size: size)
        } else if slot.isReady {
            readyBreadGraphic(size: size)
        }
    }
    
    // MARK: - Oven Graphics
    
    private func emptyOvenGraphic(size: CGFloat) -> some View {
        ZStack {
            // Empty oven rack lines
            VStack(spacing: size * 0.08) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: size * 0.5, height: 2)
                }
            }
            
            // Plus hint
            Image(systemName: "plus")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    private func bakingDoughGraphic(progress: Int, size: CGFloat) -> some View {
        ZStack {
            // Flame glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)
            
            // Rising dough/bread shape
            let doughWidth = size * 0.45
            let doughHeight = size * 0.25 + CGFloat(progress) * size * 0.002
            
            Ellipse()
                .fill(Color(red: 0.9, green: 0.75, blue: 0.5))
                .frame(width: doughWidth, height: doughHeight)
                .overlay(
                    Ellipse()
                        .fill(Color(red: 0.95, green: 0.85, blue: 0.65))
                        .frame(width: doughWidth * 0.7, height: doughHeight * 0.6)
                        .offset(y: -doughHeight * 0.15)
                )
            
            // Heat waves / flame
            if progress > 30 {
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.15))
                    .foregroundColor(.orange.opacity(0.8))
                    .offset(y: size * 0.28)
            }
        }
    }
    
    private func readyBreadGraphic(size: CGFloat) -> some View {
        ZStack {
            // Golden glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)
            
            // Finished bread loaves
            VStack(spacing: size * 0.03) {
                // Top loaf
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.65, blue: 0.35),
                                Color(red: 0.7, green: 0.5, blue: 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.4, height: size * 0.2)
                    .overlay(
                        // Score marks on bread
                        VStack(spacing: size * 0.025) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color(red: 0.5, green: 0.35, blue: 0.2))
                                    .frame(width: size * 0.2, height: 1.5)
                            }
                        }
                    )
                
                // Bottom loaf
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.8, green: 0.6, blue: 0.3),
                                Color(red: 0.65, green: 0.45, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.35, height: size * 0.18)
            }
            
            // Steam wisps
            Image(systemName: "wind")
                .font(.system(size: size * 0.12))
                .foregroundColor(.white.opacity(0.7))
                .offset(x: size * 0.25, y: -size * 0.2)
        }
    }
    
    // MARK: - Tips Card
    
    private var kitchenTipsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("How to Bake")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "1.circle.fill", text: "Harvest wheat from your garden")
                tipRow(icon: "2.circle.fill", text: "Tap a slot to make sourdough!")
                tipRow(icon: "3.circle.fill", text: "Wait 3 hours, then collect your bread!")
            }
            
            // Mini-game hint
            HStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                Text("Mix, knead, shape & score like a real baker!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(.top, 2)
            
            // Conversion info
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("1 wheat = 12 loaves of sourdough")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(.top, 4)
        }
        .padding(KingdomTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.buttonWarning)
            Text(text)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
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
                Task { await loadKitchenStatus() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Slot Tap Handler
    
    private func handleSlotTap(slot: OvenSlot, wheatCount: Int) {
        // For baking or ready slots, show detail sheet
        if slot.isBaking || slot.isReady {
            selectedSlot = slot
            return
        }
        
        if slot.isEmpty && wheatCount > 0 {
            // Show the sourdough mini-game!
            miniGameSlotIndex = slot.slotIndex
            showMiniGame = true
        } else if slot.isEmpty && wheatCount == 0 {
            showResult(success: false, message: "No wheat! Harvest some from your garden.")
        }
    }
    
    private func performCollect(slotIndex: Int) {
        Task {
            selectedSlot = nil
            await collectBread(slotIndex: slotIndex)
        }
    }
    
    // MARK: - API Calls
    
    private func loadKitchenStatus() async {
        isLoading = true
        errorMessage = nil
        await refreshKitchenStatus()
        isLoading = false
    }
    
    private func refreshKitchenStatus() async {
        do {
            status = try await kitchenAPI.getStatus()
            
            // Schedule notifications for any baking slots
            if let slots = status?.slots {
                for slot in slots where slot.isBaking {
                    if let seconds = slot.secondsRemaining, seconds > 0 {
                        await NotificationManager.shared.scheduleKitchenBakingNotification(
                            slotIndex: slot.slotIndex,
                            secondsUntilReady: seconds
                        )
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadOven(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await kitchenAPI.loadOven(slotIndex: slotIndex)
            
            // Schedule notification for when bread is ready
            if response.success, let seconds = response.readyInSeconds, seconds > 0 {
                await NotificationManager.shared.scheduleKitchenBakingNotification(
                    slotIndex: slotIndex,
                    secondsUntilReady: seconds
                )
            }
            
            flavorText = response.flavor
            showResult(success: true, message: response.message)
            await refreshKitchenStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func collectBread(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await kitchenAPI.collectBread(slotIndex: slotIndex)
            
            // Cancel notification for this slot
            if response.success {
                NotificationManager.shared.cancelKitchenNotification(slotIndex: slotIndex)
            }
            
            flavorText = response.flavor
            showResult(success: true, message: response.message)
            await refreshKitchenStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func showResult(success: Bool, message: String) {
        resultSuccess = success
        resultMessage = message
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showResultOverlay = true
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
    }
}

// MARK: - Result Overlay

struct KitchenResultOverlay: View {
    let success: Bool
    let message: String
    let flavor: String?
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
                Image(systemName: success ? "cloud.fill" : "xmark.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(
                        backgroundColor: success ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 24,
                        shadowOffset: 5,
                        borderWidth: 3
                    )
                
                Text(success ? "Success!" : "Oops!")
                    .font(FontStyles.displaySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let flavor = flavor, success {
                    Text(flavor)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
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

// MARK: - Oven Baking Sheet

struct OvenBakingSheet: View {
    let slot: OvenSlot
    let currentTime: Date
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Drag handle
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Oven visual
                ZStack {
                    Circle()
                        .fill(Color(red: 0.8, green: 0.3, blue: 0.1))
                        .frame(width: 100, height: 100)
                    
                    // Bread rising
                    Ellipse()
                        .fill(Color(red: 0.9, green: 0.75, blue: 0.5))
                        .frame(width: 50, height: CGFloat(25 + (slot.progressPercent ?? 0) / 4))
                    
                    // Flame
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                        .offset(y: 30)
                }
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 100, height: 100)
                )
                
                Text("Baking...")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Progress
                VStack(spacing: 12) {
                    HStack {
                        Text("Progress")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Spacer()
                        Text("\(slot.progressPercent ?? 0)%")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.disabled.opacity(0.3))
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.buttonWarning)
                                .frame(width: geo.size.width * CGFloat(slot.progressPercent ?? 0) / 100)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                        )
                    }
                    .frame(height: 20)
                    
                    // Time remaining
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        Text(timeRemainingText)
                            .font(FontStyles.labelMedium)
                    }
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black, lineWidth: 2)
                        )
                )
                .padding(.horizontal)
                
                // Info
                VStack(spacing: 8) {
                    HStack {
                        Text("Wheat used:")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Spacer()
                        Text("\(slot.wheatUsed ?? 0)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                    HStack {
                        Text("Loaves cooking:")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Spacer()
                        Text("\(slot.loavesPending ?? 0)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black, lineWidth: 2)
                        )
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(KingdomTheme.Colors.parchment)
    }
    
    private var timeRemainingText: String {
        guard let seconds = slot.secondsRemaining, seconds > 0 else {
            return "Almost ready!"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "Ready in \(hours)h \(minutes)m"
        }
        return "Ready in \(minutes)m"
    }
}

// MARK: - Oven Ready Sheet

struct OvenReadySheet: View {
    let slot: OvenSlot
    let onCollect: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Drag handle
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Bread visual
                ZStack {
                    Circle()
                        .fill(Color(red: 0.5, green: 0.35, blue: 0.2))
                        .frame(width: 100, height: 100)
                    
                    // Golden glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    // Bread loaves
                    VStack(spacing: 4) {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.65, blue: 0.35),
                                        Color(red: 0.7, green: 0.5, blue: 0.25)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 45, height: 22)
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.8, green: 0.6, blue: 0.3),
                                        Color(red: 0.65, green: 0.45, blue: 0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: 20)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 100, height: 100)
                )
                
                Text("Fresh Bread!")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("\(slot.loavesPending ?? 0) loaves of sourdough are ready!")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                
                // Collect button
                Button {
                    onCollect()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Collect Bread")
                            .font(FontStyles.headingSmall)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    }
                )
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(KingdomTheme.Colors.parchment)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        KitchenView()
    }
}
