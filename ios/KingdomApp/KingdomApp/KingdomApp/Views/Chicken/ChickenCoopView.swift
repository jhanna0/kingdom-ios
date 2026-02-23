import SwiftUI
import Combine

/// Chicken Coop view - Hatch eggs, raise chickens, collect eggs
/// Tamagotchi-style design with 4 slots (2x2 grid)
struct ChickenCoopView: View {
    @State private var status: ChickenStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showResultOverlay = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    @State private var actionInProgress: Int? = nil
    @State private var selectedSlot: ChickenSlot? = nil
    @State private var showNamingSheet = false
    @State private var namingSlot: ChickenSlot? = nil
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let chickenAPI = ChickenAPI()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let status = status {
                    coopContent(status: status)
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("Chicken Coop")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .task {
            await loadCoopStatus()
        }
        .refreshable {
            await loadCoopStatus()
        }
        .overlay {
            if showResultOverlay {
                ChickenResultOverlay(
                    success: resultSuccess,
                    message: resultMessage,
                    isShowing: $showResultOverlay
                )
                .transition(.opacity)
            }
        }
        .sheet(item: $selectedSlot) { slot in
            if slot.isAlive {
                ChickenDetailSheet(
                    slot: slot,
                    currentTime: currentTime,
                    onAction: { action in performAction(slotIndex: slot.slotIndex, action: action) },
                    onCollect: { performCollect(slotIndex: slot.slotIndex) },
                    onName: { showNamingForSlot(slot) }
                )
                .presentationDetents([.height(620)])
                .presentationDragIndicator(.hidden)
            } else if slot.isIncubating {
                ChickenIncubatingSheet(slot: slot, currentTime: currentTime)
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.hidden)
            }
        }
        .sheet(isPresented: $showNamingSheet) {
            if let slot = namingSlot {
                ChickenNamingSheet(
                    slot: slot,
                    currentName: slot.name ?? "Clucky",
                    onConfirm: { name in
                        performName(slotIndex: slot.slotIndex, name: name)
                    }
                )
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.hidden)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(KingdomTheme.Colors.loadingTint)
            Text("Loading coop...")
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func coopContent(status: ChickenStatusResponse) -> some View {
        if !status.hasCoop {
            noCoopView(requirement: status.coopRequirement ?? "Build a Beautiful Maison (Tier 4) to unlock.")
        } else {
            coopHeaderCard(status: status)
            coopView(slots: status.slots, rareEggCount: status.rareEggCount)
            coopTipsCard
        }
    }
    
    // MARK: - No Coop View
    
    private func noCoopView(requirement: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "oval.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.disabled,
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text("No Chicken Coop Yet")
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
    
    // MARK: - Coop Header Card
    
    private func coopHeaderCard(status: ChickenStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "oval.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.imperialGold,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chicken Coop")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "oval.fill")
                                .font(FontStyles.iconMini)
                            Text("\(status.rareEggCount) rare egg\(status.rareEggCount == 1 ? "" : "s")")
                                .font(FontStyles.labelMedium)
                        }
                        .foregroundColor(status.rareEggCount > 0 ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.inkMedium)
                        
                        if let stats = status.stats, stats.aliveChickens > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "oval.fill")
                                    .font(FontStyles.iconMini)
                                Text("\(stats.aliveChickens) chicken\(stats.aliveChickens == 1 ? "" : "s")")
                                    .font(FontStyles.labelMedium)
                            }
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "heart.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Coop View (Main Visual!)
    
    private func coopView(slots: [ChickenSlot], rareEggCount: Int) -> some View {
        VStack(spacing: 0) {
            // Barn roof
            ZStack {
                // Red barn roof
                Color(red: 0.7, green: 0.25, blue: 0.2)
                
                // Roof texture lines
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(red: 0.6, green: 0.2, blue: 0.15).opacity(0.6))
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 20)
                
                // Barn window/vent
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.3, green: 0.2, blue: 0.15))
                            .frame(width: 30, height: 20)
                        Rectangle()
                            .fill(Color(red: 0.5, green: 0.35, blue: 0.25))
                            .frame(width: 2, height: 16)
                        Rectangle()
                            .fill(Color(red: 0.5, green: 0.35, blue: 0.25))
                            .frame(width: 26, height: 2)
                    }
                    .offset(y: 5)
                    Spacer()
                }
            }
            .frame(height: 50)
            
            // Barn interior with nests - 2x2 grid
            ZStack {
                // Barn wood background
                Color(red: 0.55, green: 0.4, blue: 0.28)
                
                // Wood grain texture
                VStack(spacing: 12) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(red: 0.5, green: 0.35, blue: 0.22).opacity(0.4))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 10)
                
                // Nest slots grid
                VStack(spacing: 20) {
                    HStack(spacing: 24) {
                        ForEach(slots.prefix(2)) { slot in
                            chickenSlotView(slot: slot, rareEggCount: rareEggCount)
                        }
                    }
                    HStack(spacing: 24) {
                        ForEach(slots.dropFirst(2).prefix(2)) { slot in
                            chickenSlotView(slot: slot, rareEggCount: rareEggCount)
                        }
                    }
                }
                .padding(.vertical, 24)
            }
            .frame(height: 280)
            
            // Hay/straw floor
            ZStack(alignment: .top) {
                Color(red: 0.85, green: 0.75, blue: 0.5)
                
                HStack(spacing: 2) {
                    ForEach(0..<30, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 0.75, green: 0.65, blue: 0.4))
                            .frame(width: 3, height: CGFloat.random(in: 6...12))
                            .offset(y: -2)
                    }
                }
            }
            .frame(height: 25)
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
    
    // MARK: - Chicken Slot View
    
    private func chickenSlotView(slot: ChickenSlot, rareEggCount: Int) -> some View {
        let isActing = actionInProgress == slot.slotIndex
        
        return Button {
            handleSlotTap(slot: slot, rareEggCount: rareEggCount)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Nest base
                    nestGraphic
                    
                    // Slot content
                    slotContentView(slot: slot, isActing: isActing)
                }
                .frame(width: 90, height: 90)
                
                // Badge
                chickenSlotBadge(slot: slot)
            }
        }
        .buttonStyle(.plain)
        .disabled(isActing)
    }
    
    private var nestGraphic: some View {
        ZStack {
            // Straw nest
            Ellipse()
                .fill(Color(red: 0.8, green: 0.7, blue: 0.45))
                .frame(width: 85, height: 40)
                .offset(y: 20)
            
            // Nest rim
            Ellipse()
                .fill(Color(red: 0.7, green: 0.6, blue: 0.35))
                .frame(width: 75, height: 30)
                .offset(y: 18)
            
            // Inner nest
            Ellipse()
                .fill(Color(red: 0.85, green: 0.75, blue: 0.5))
                .frame(width: 60, height: 22)
                .offset(y: 16)
        }
    }
    
    private func chickenSlotBadge(slot: ChickenSlot) -> some View {
        let (text, bgColor) = slotBadgeInfo(slot: slot)
        
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(bgColor == KingdomTheme.Colors.buttonWarning || bgColor == KingdomTheme.Colors.buttonSuccess ? .white : KingdomTheme.Colors.inkDark)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(bgColor)
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 1)
                    )
            )
    }
    
    private func slotBadgeInfo(slot: ChickenSlot) -> (String, Color) {
        if slot.isEmpty {
            return ("Hatch egg", Color.white.opacity(0.9))
        } else if slot.isIncubating {
            return (formatTimer(seconds: slot.secondsUntilHatch), KingdomTheme.Colors.imperialGold)
        } else if slot.isAlive {
            if slot.canCollect {
                return ("Eggs!", KingdomTheme.Colors.buttonSuccess)
            } else if slot.needsAttention == true {
                return ("Needs care", KingdomTheme.Colors.buttonWarning)
            } else if slot.isHappy {
                return ("Happy", KingdomTheme.Colors.buttonSuccess)
            } else {
                return ("Sad", KingdomTheme.Colors.buttonDanger)
            }
        }
        return ("", Color.white.opacity(0.9))
    }
    
    private func formatTimer(seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else { return "Ready!" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    @ViewBuilder
    private func slotContentView(slot: ChickenSlot, isActing: Bool) -> some View {
        if isActing {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.white)
        } else if slot.isEmpty {
            emptySlotGraphic
        } else if slot.isIncubating {
            incubatingEggGraphic(progress: slot.progressPercent ?? 0)
        } else if slot.isAlive {
            chickenGraphic(isHappy: slot.isHappy, hasEgg: slot.canCollect)
        }
    }
    
    // MARK: - Slot Graphics
    
    private var emptySlotGraphic: some View {
        ZStack {
            Text("+")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: -5)
        }
    }
    
    private func incubatingEggGraphic(progress: Int) -> some View {
        ZStack {
            // Golden egg
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.85, blue: 0.4),
                            Color(red: 0.9, green: 0.7, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 52)
                .overlay(
                    Ellipse()
                        .stroke(Color(red: 0.7, green: 0.55, blue: 0.15), lineWidth: 2)
                )
                .offset(y: -8)
            
            // Shine
            Ellipse()
                .fill(Color.white.opacity(0.4))
                .frame(width: 12, height: 16)
                .offset(x: -8, y: -16)
            
            // Crack lines if close to hatching
            if progress > 70 {
                Path { path in
                    path.move(to: CGPoint(x: 45, y: 30))
                    path.addLine(to: CGPoint(x: 50, y: 38))
                    path.addLine(to: CGPoint(x: 46, y: 42))
                }
                .stroke(Color(red: 0.5, green: 0.4, blue: 0.2), lineWidth: 1.5)
                .offset(x: -25, y: -30)
            }
        }
    }
    
    private func chickenGraphic(isHappy: Bool, hasEgg: Bool) -> some View {
        AnimatedChickenGraphic(isHappy: isHappy, hasEgg: hasEgg)
    }
    
    // MARK: - Tips Card
    
    private var coopTipsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("How to Raise Chickens")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "1.circle.fill", text: "Hatch eggs in empty nests")
                tipRow(icon: "2.circle.fill", text: "Name your chicken when it hatches")
                tipRow(icon: "3.circle.fill", text: "Only happy chickens lay eggs")
            }
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
                Task { await loadCoopStatus() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Slot Tap Handler
    
    private func handleSlotTap(slot: ChickenSlot, rareEggCount: Int) {
        if slot.isIncubating || slot.isAlive {
            selectedSlot = slot
            return
        }
        
        Task {
            if slot.isEmpty && rareEggCount > 0 {
                await hatchEgg(slotIndex: slot.slotIndex)
            } else if slot.isEmpty && rareEggCount == 0 {
                showResult(success: false, message: "No rare eggs! Find them while foraging.")
            }
        }
    }
    
    private func showNamingForSlot(_ slot: ChickenSlot) {
        selectedSlot = nil
        namingSlot = slot
        showNamingSheet = true
    }
    
    private func performAction(slotIndex: Int, action: String) {
        Task {
            await doAction(slotIndex: slotIndex, action: action)
        }
    }
    
    private func performCollect(slotIndex: Int) {
        Task {
            selectedSlot = nil
            selectedSlot = nil
            await collectEggs(slotIndex: slotIndex)
        }
    }
    
    private func performName(slotIndex: Int, name: String) {
        Task {
            showNamingSheet = false
            namingSlot = nil
            await nameChicken(slotIndex: slotIndex, name: name)
        }
    }
    
    // MARK: - API Calls
    
    private func loadCoopStatus() async {
        isLoading = true
        errorMessage = nil
        await refreshCoopStatus()
        isLoading = false
    }
    
    private func refreshCoopStatus() async {
        do {
            status = try await chickenAPI.getStatus()
            
            // Schedule notifications for incubating eggs
            if let slots = status?.slots {
                for slot in slots {
                    if slot.isIncubating, let seconds = slot.secondsUntilHatch, seconds > 0 {
                        await NotificationManager.shared.scheduleChickenHatchNotification(
                            slotIndex: slot.slotIndex,
                            secondsUntilHatch: seconds
                        )
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func hatchEgg(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await chickenAPI.hatchEgg(slotIndex: slotIndex)
            HapticService.shared.notification(.success)
            
            // Schedule notification for when egg hatches
            if response.success {
                let secondsUntilHatch = response.incubationHours * 3600
                await NotificationManager.shared.scheduleChickenHatchNotification(
                    slotIndex: slotIndex,
                    secondsUntilHatch: secondsUntilHatch
                )
            }
            
            await refreshCoopStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func nameChicken(slotIndex: Int, name: String) async {
        actionInProgress = slotIndex
        
        do {
            _ = try await chickenAPI.nameChicken(slotIndex: slotIndex, name: name)
            HapticService.shared.notification(.success)
            await refreshCoopStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func doAction(slotIndex: Int, action: String) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await chickenAPI.performAction(slotIndex: slotIndex, action: action)
            HapticService.shared.lightImpact()
            
            // Update the selected slot with new data so sheet stays updated
            selectedSlot = response.slot
            
            // Also refresh the main list
            await refreshCoopStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func collectEggs(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await chickenAPI.collectEggs(slotIndex: slotIndex)
            HapticService.shared.notification(.success)
            await refreshCoopStatus()
            
            // Update selected slot so sheet reflects the change
            if let updatedSlot = status?.slots.first(where: { $0.slotIndex == slotIndex }) {
                selectedSlot = updatedSlot
            }
            
            if response.rareEggsGained > 0 {
                HapticService.shared.notification(.success)
            }
        } catch {
            // Silent fail - just haptic
            HapticService.shared.notification(.error)
        }
        
        actionInProgress = nil
    }
    
    private func showResult(success: Bool, message: String) {
        resultSuccess = success
        resultMessage = message
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showResultOverlay = true
        }
        
        if !success {
            HapticService.shared.notification(.error)
        }
    }
}

// MARK: - Result Overlay

struct ChickenResultOverlay: View {
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
                Image(systemName: success ? "oval.fill" : "xmark.circle.fill")
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

// MARK: - Chicken Preview (for slot cards)

struct ChickenPreview: View {
    let isHappy: Bool
    let hasEgg: Bool
    
    var body: some View {
        ZStack {
            // Body
            Ellipse()
                .fill(Color(red: 1.0, green: 0.9, blue: 0.7))
                .frame(width: 36, height: 28)
            
            // Head
            Circle()
                .fill(Color(red: 1.0, green: 0.9, blue: 0.7))
                .frame(width: 20, height: 20)
                .offset(x: -10, y: -12)
            
            // Comb
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .offset(x: -12, y: -22)
            Circle()
                .fill(Color.red)
                .frame(width: 5, height: 5)
                .offset(x: -8, y: -24)
            
            // Eye
            Circle()
                .fill(Color.black)
                .frame(width: 3, height: 3)
                .offset(x: -12, y: -13)
        }
    }
}

// MARK: - Animated Chicken Graphic (for slot cards)

struct AnimatedChickenGraphic: View {
    let isHappy: Bool
    let hasEgg: Bool
    
    @State private var isBlinking = false
    
    var body: some View {
        ZStack {
            // Body
            Ellipse()
                .fill(Color(red: 1.0, green: 0.9, blue: 0.7))
                .frame(width: 50, height: 40)
                .offset(y: -2)
            
            // Wing
            Ellipse()
                .fill(Color(red: 0.95, green: 0.85, blue: 0.6))
                .frame(width: 20, height: 15)
                .offset(x: 12, y: 0)
            
            // Head
            Circle()
                .fill(Color(red: 1.0, green: 0.9, blue: 0.7))
                .frame(width: 28, height: 28)
                .offset(x: -15, y: -18)
            
            // Comb (red)
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: -18, y: -32)
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .offset(x: -13, y: -34)
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .offset(x: -9, y: -32)
            }
            
            // Eye - blinks
            if isBlinking {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 6, height: 2)
                    .offset(x: -18, y: -20)
            } else {
                Circle()
                    .fill(Color.black)
                    .frame(width: 5, height: 5)
                    .offset(x: -18, y: -20)
            }
            
            // Egg underneath if available
            if hasEgg {
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.98, blue: 0.9))
                    .frame(width: 18, height: 22)
                    .overlay(
                        Ellipse()
                            .stroke(Color(red: 0.85, green: 0.8, blue: 0.7), lineWidth: 1)
                    )
                    .offset(x: 5, y: 18)
            }
            
            // Happiness indicator (backend-driven)
            if !isHappy {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    .offset(x: 25, y: -25)
            }
        }
        .onAppear {
            startBlinking()
        }
    }
    
    private func startBlinking() {
        scheduleBlink()
    }
    
    private func scheduleBlink() {
        let nextBlink = Double.random(in: 2.0...6.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + nextBlink) {
            withAnimation(.easeIn(duration: 0.08)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.12)) {
                    isBlinking = false
                }
                scheduleBlink()
            }
        }
    }
}

// MARK: - Chicken Incubating Sheet

struct ChickenIncubatingSheet: View {
    let slot: ChickenSlot
    let currentTime: Date
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Incubating egg
                ZStack {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.75, blue: 0.5))
                        .frame(width: 100, height: 100)
                    
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.4),
                                    Color(red: 0.9, green: 0.7, blue: 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 65)
                        .overlay(
                            Ellipse()
                                .stroke(Color(red: 0.7, green: 0.55, blue: 0.15), lineWidth: 2)
                        )
                }
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 100, height: 100)
                )
                
                Text("Incubating...")
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(FontStyles.labelBold)
                        Spacer()
                        Text("\(slot.progressPercent ?? 0)%")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.imperialGold)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.disabled.opacity(0.3))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.imperialGold)
                                .frame(width: geo.size.width * CGFloat(slot.progressPercent ?? 0) / 100)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                        )
                    }
                    .frame(height: 20)
                    
                    if let seconds = slot.secondsUntilHatch, seconds > 0 {
                        let hours = seconds / 3600
                        let minutes = (seconds % 3600) / 60
                        Text("Hatches in \(hours)h \(minutes)m")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 2))
                )
                .padding(.horizontal)
                
                Text("Keep the egg warm! A new chicken will hatch soon.")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .background(KingdomTheme.Colors.parchment)
    }
}

// MARK: - Chicken Naming Sheet

struct ChickenNamingSheet: View {
    let slot: ChickenSlot
    let currentName: String
    let onConfirm: (String) -> Void
    
    @State private var chickenName: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            Image(systemName: "oval.fill")
                .font(.system(size: 48))
                .foregroundColor(KingdomTheme.Colors.imperialGold)
            
            Text("Name Your Chicken!")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Choose wisely - you can only name them once!")
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            TextField("Enter name", text: $chickenName)
                .font(FontStyles.bodyMedium)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                )
                .padding(.horizontal)
            
            Button {
                let finalName = chickenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalName.isEmpty {
                    onConfirm(finalName)
                }
            } label: {
                Text("Confirm Name")
                    .font(FontStyles.headingSmall)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSuccess))
            .padding(.horizontal)
            .disabled(chickenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Spacer()
        }
        .background(KingdomTheme.Colors.parchment)
        .onAppear {
            chickenName = currentName
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChickenCoopView()
    }
}
