import SwiftUI
import Combine

/// Garden view - Plant, water, and harvest in your personal garden
/// Beautiful tamagotchi-style design with 6 slots
struct GardenView: View {
    @State private var status: GardenStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showResultOverlay = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    @State private var actionInProgress: Int? = nil  // slot index being acted on
    @State private var selectedSlot: GardenSlot? = nil  // For detail sheet
    
    // Timer for updating countdowns
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let gardenAPI = GardenAPI()
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let status = status {
                    gardenContent(status: status)
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("My Garden")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
        .task {
            await loadGardenStatus()
        }
        .refreshable {
            await loadGardenStatus()
        }
        .overlay {
            if showResultOverlay {
                GardenResultOverlay(
                    success: resultSuccess,
                    message: resultMessage,
                    isShowing: $showResultOverlay
                )
                .transition(.opacity)
            }
        }
        .sheet(item: $selectedSlot) { slot in
            if slot.isGrowing {
                GardenSlotDetailSheet(slot: slot, currentTime: currentTime) {
                    performWater(slotIndex: slot.slotIndex)
                }
                .presentationDetents([.height(480)])
                .presentationDragIndicator(.hidden)
            } else if slot.isReady {
                GardenReadySheet(slot: slot, onAction: {
                    performReadyAction(slot: slot)
                })
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)
            } else if slot.isDead {
                GardenDeadSheet(slot: slot, onClear: {
                    performClear(slotIndex: slot.slotIndex)
                })
                .presentationDetents([.height(380)])
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
            Text("Loading garden...")
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private func gardenContent(status: GardenStatusResponse) -> some View {
        if !status.hasGarden {
            noGardenView(requirement: status.gardenRequirement ?? "Purchase property to unlock garden.")
        } else {
            // Garden Header
            gardenHeaderCard(status: status)
            
            // Garden Bed - The main visual!
            gardenBedView(slots: status.slots, seedCount: status.seedCount)
            
            // Info/Tips Card
            gardenTipsCard
        }
    }
    
    // MARK: - No Garden View
    
    private func noGardenView(requirement: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.disabled,
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text("No Garden Yet")
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
    
    // MARK: - Garden Header Card
    
    private func gardenHeaderCard(status: GardenStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: "leaf.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonSuccess,
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Garden")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    HStack(spacing: 12) {
                        // Seed count
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.circle.fill")
                                .font(FontStyles.iconMini)
                            Text("\(status.seedCount) seed\(status.seedCount == 1 ? "" : "s")")
                                .font(FontStyles.labelMedium)
                        }
                        .foregroundColor(status.seedCount > 0 ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium)
                        
                        // Growing count
                        if let stats = status.stats, stats.growingPlants > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(FontStyles.iconMini)
                                Text("\(stats.growingPlants) growing")
                                    .font(FontStyles.labelMedium)
                            }
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        }
                    }
                }
                
                Spacer()
                
                // Watering can icon
                Image(systemName: "drop.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(KingdomTheme.Colors.royalBlue)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Garden Bed View (Main Visual!)
    
    private func gardenBedView(slots: [GardenSlot], seedCount: Int) -> some View {
        VStack(spacing: 0) {
            // Sky with clouds
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.7, green: 0.85, blue: 0.95),
                        Color(red: 0.85, green: 0.92, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Clouds
                HStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .offset(y: -5)
                    Spacer()
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(y: -8)
                }
                .padding(.horizontal, 20)
                
                // Sun
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow)
                    .offset(x: 60, y: -10)
            }
            .frame(height: 60)
            
            // Garden soil with plots - 2 rows x 3 columns
            ZStack {
                // Rich brown soil background
                Color(red: 0.45, green: 0.35, blue: 0.25)
                
                // Soil texture rows
                VStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.5))
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 10)
                
                // Garden fence posts on sides
                HStack {
                    gardenFence
                    Spacer()
                    gardenFence
                }
                .padding(.horizontal, 4)
                
                // Flower/plant slots grid
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        ForEach(slots.prefix(3)) { slot in
                            gardenSlotView(slot: slot, seedCount: seedCount)
                        }
                    }
                    HStack(spacing: 20) {
                        ForEach(slots.dropFirst(3).prefix(3)) { slot in
                            gardenSlotView(slot: slot, seedCount: seedCount)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .frame(height: 240)
            
            // Grass border at bottom
            ZStack(alignment: .top) {
                Color(red: 0.55, green: 0.75, blue: 0.45)
                
                HStack(spacing: 3) {
                    ForEach(0..<25, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 0.45, green: 0.65, blue: 0.35))
                            .frame(width: 4, height: CGFloat.random(in: 8...14))
                            .offset(y: -4)
                    }
                }
            }
            .frame(height: 30)
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
    
    // MARK: - Garden Fence
    
    private var gardenFence: some View {
        VStack(spacing: 30) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.55, green: 0.4, blue: 0.25))
                    .frame(width: 8, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Garden Slot View
    
    private func gardenSlotView(slot: GardenSlot, seedCount: Int) -> some View {
        let isActing = actionInProgress == slot.slotIndex
        
        return Button {
            handleSlotTap(slot: slot, seedCount: seedCount)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Soil plot circle
                    Circle()
                        .fill(Color(red: 0.35, green: 0.25, blue: 0.18))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    // Plant/slot content
                    slotContentView(slot: slot, isActing: isActing)
                }
                
                // Badge - always present for alignment
                gardenSlotBadge(slot: slot)
            }
        }
        .buttonStyle(.plain)
        .disabled(isActing)
    }
    
    private func gardenSlotBadge(slot: GardenSlot) -> some View {
        let text = slotBadgeText(slot: slot)
        let needsWater = slot.isGrowing && slot.canWater
        let showWaterIcon = slot.isGrowing
        
        return HStack(spacing: 3) {
            if showWaterIcon {
                Image(systemName: needsWater ? "drop.fill" : "drop")
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(needsWater ? .white : KingdomTheme.Colors.inkDark)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(needsWater ? KingdomTheme.Colors.royalBlue : Color.white.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(Color.black, lineWidth: 1)
                )
        )
    }
    
    private func slotBadgeText(slot: GardenSlot) -> String {
        if slot.isEmpty {
            return "Plant me"
        } else if slot.isDead {
            return "Clear"
        } else if slot.isReady {
            switch slot.plantType {
            case "wheat": return "Harvest"
            case "flower": return "Pretty!"
            case "weed": return "Clear"
            default: return "Harvest"
            }
        } else if slot.isGrowing {
            if slot.canWater {
                return "Water!"
            } else {
                return formatWaterTimer(seconds: slot.secondsUntilWater)
            }
        }
        return ""
    }
    
    private func formatWaterTimer(seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else {
            return "Water!"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    @ViewBuilder
    private func slotContentView(slot: GardenSlot, isActing: Bool) -> some View {
        if isActing {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.white)
        } else if slot.isEmpty {
            // Empty slot - small mound of soil with hole
            emptySlotGraphic
        } else if slot.isGrowing {
            // Growing plant - different stages based on watering cycles
            let stage = slot.wateringCycles ?? 0
            growingPlantGraphic(stage: stage, canWater: slot.canWater)
        } else if slot.isDead {
            // Dead plant - wilted brown
            deadPlantGraphic
        } else if slot.isReady {
            // Ready! Show the actual plant type
            readyPlantGraphic(plantType: slot.plantType, color: slot.color)
        }
    }
    
    // MARK: - Drawn Plant Graphics
    
    /// Empty slot - small soil mound ready for planting
    private var emptySlotGraphic: some View {
        ZStack {
            // Soil mound
            Ellipse()
                .fill(Color(red: 0.4, green: 0.28, blue: 0.18))
                .frame(width: 40, height: 16)
                .offset(y: 12)
            
            // Planting hole
            Ellipse()
                .fill(Color(red: 0.25, green: 0.18, blue: 0.12))
                .frame(width: 18, height: 10)
                .offset(y: 10)
            
            // Plus hint
            Text("+")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: -4)
        }
    }
    
    /// Growing plant graphic based on stage (0-3)
    private func growingPlantGraphic(stage: Int, canWater: Bool) -> some View {
        ZStack {
            // Draw plant based on growth stage
            switch stage {
            case 0:
                // Just planted - tiny seed sprout
                seedSproutGraphic
            case 1:
                // Small sprout with first leaves
                smallSproutGraphic
            case 2:
                // Medium plant
                mediumPlantGraphic
            case 3:
                // Almost ready - full plant but still mystery
                largePlantGraphic
            default:
                largePlantGraphic
            }
            
            // Water droplet indicator if can water
            if canWater {
                waterDropletIndicator
                    .offset(x: 22, y: -18)
            }
        }
    }
    
    /// Stage 0: Tiny seed just sprouting
    private var seedSproutGraphic: some View {
        ZStack {
            // Soil mound
            Ellipse()
                .fill(Color(red: 0.4, green: 0.28, blue: 0.18))
                .frame(width: 36, height: 14)
                .offset(y: 14)
            
            // Tiny stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.4, green: 0.6, blue: 0.3))
                .frame(width: 3, height: 12)
                .offset(y: 4)
            
            // Two tiny seed leaves (cotyledons)
            HStack(spacing: 0) {
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.65, blue: 0.35))
                    .frame(width: 8, height: 5)
                    .rotationEffect(.degrees(-30))
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.65, blue: 0.35))
                    .frame(width: 8, height: 5)
                    .rotationEffect(.degrees(30))
            }
            .offset(y: -4)
        }
    }
    
    /// Stage 1: Small sprout with leaves
    private var smallSproutGraphic: some View {
        ZStack {
            // Soil mound
            Ellipse()
                .fill(Color(red: 0.4, green: 0.28, blue: 0.18))
                .frame(width: 36, height: 14)
                .offset(y: 16)
            
            // Stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.35, green: 0.55, blue: 0.28))
                .frame(width: 4, height: 22)
                .offset(y: 2)
            
            // Left leaf
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-40))
                .offset(x: -10, y: -2)
            
            // Right leaf
            Ellipse()
                .fill(Color(red: 0.45, green: 0.7, blue: 0.35))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(40))
                .offset(x: 10, y: -4)
            
            // Top bud
            Circle()
                .fill(Color(red: 0.35, green: 0.6, blue: 0.3))
                .frame(width: 8, height: 8)
                .offset(y: -12)
        }
    }
    
    /// Stage 2: Medium plant
    private var mediumPlantGraphic: some View {
        ZStack {
            // Soil mound
            Ellipse()
                .fill(Color(red: 0.4, green: 0.28, blue: 0.18))
                .frame(width: 38, height: 14)
                .offset(y: 18)
            
            // Main stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.3, green: 0.5, blue: 0.25))
                .frame(width: 5, height: 32)
                .offset(y: 0)
            
            // Lower left leaf
            Ellipse()
                .fill(Color(red: 0.38, green: 0.62, blue: 0.3))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(-50))
                .offset(x: -12, y: 6)
            
            // Lower right leaf
            Ellipse()
                .fill(Color(red: 0.42, green: 0.68, blue: 0.34))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(50))
                .offset(x: 12, y: 4)
            
            // Upper left leaf
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-35))
                .offset(x: -10, y: -8)
            
            // Upper right leaf
            Ellipse()
                .fill(Color(red: 0.45, green: 0.72, blue: 0.36))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(35))
                .offset(x: 10, y: -10)
            
            // Top growth
            Circle()
                .fill(Color(red: 0.35, green: 0.58, blue: 0.28))
                .frame(width: 10, height: 10)
                .offset(y: -18)
        }
    }
    
    /// Stage 3: Large plant, almost ready
    private var largePlantGraphic: some View {
        ZStack {
            // Soil mound
            Ellipse()
                .fill(Color(red: 0.4, green: 0.28, blue: 0.18))
                .frame(width: 40, height: 14)
                .offset(y: 20)
            
            // Main stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.28, green: 0.48, blue: 0.22))
                .frame(width: 6, height: 38)
                .offset(y: -2)
            
            // Many leaves at different heights
            // Bottom leaves
            Ellipse()
                .fill(Color(red: 0.35, green: 0.58, blue: 0.28))
                .frame(width: 18, height: 10)
                .rotationEffect(.degrees(-55))
                .offset(x: -14, y: 10)
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 18, height: 10)
                .rotationEffect(.degrees(55))
                .offset(x: 14, y: 8)
            
            // Middle leaves
            Ellipse()
                .fill(Color(red: 0.38, green: 0.62, blue: 0.3))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(-45))
                .offset(x: -12, y: -4)
            Ellipse()
                .fill(Color(red: 0.42, green: 0.68, blue: 0.34))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(45))
                .offset(x: 12, y: -6)
            
            // Top leaves
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-30))
                .offset(x: -9, y: -16)
            Ellipse()
                .fill(Color(red: 0.45, green: 0.72, blue: 0.36))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(30))
                .offset(x: 9, y: -18)
            
            // Mystery bud at top (what will it be??)
            ZStack {
                Circle()
                    .fill(Color(red: 0.32, green: 0.55, blue: 0.26))
                    .frame(width: 14, height: 14)
                Text("?")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .offset(y: -26)
        }
    }
    
    /// Dead plant - wilted
    private var deadPlantGraphic: some View {
        ZStack {
            // Dried soil
            Ellipse()
                .fill(Color(red: 0.45, green: 0.35, blue: 0.28))
                .frame(width: 38, height: 14)
                .offset(y: 16)
            
            // Wilted stem (bent)
            Path { path in
                path.move(to: CGPoint(x: 35, y: 46))
                path.addQuadCurve(
                    to: CGPoint(x: 28, y: 18),
                    control: CGPoint(x: 42, y: 32)
                )
            }
            .stroke(Color(red: 0.5, green: 0.4, blue: 0.25), lineWidth: 4)
            .frame(width: 70, height: 70)
            .offset(y: -14)
            
            // Wilted brown leaves
            Ellipse()
                .fill(Color(red: 0.55, green: 0.42, blue: 0.28))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(70))
                .offset(x: -6, y: 0)
            
            Ellipse()
                .fill(Color(red: 0.5, green: 0.38, blue: 0.25))
                .frame(width: 10, height: 6)
                .rotationEffect(.degrees(-80))
                .offset(x: 8, y: -4)
            
            // Sad droopy top
            Circle()
                .fill(Color(red: 0.5, green: 0.4, blue: 0.28))
                .frame(width: 10, height: 10)
                .offset(x: -8, y: -10)
        }
    }
    
    /// Ready plant based on type - uses shared ReadyPlantPreview
    private func readyPlantGraphic(plantType: String?, color: String) -> some View {
        ReadyPlantPreview(plantType: plantType, color: color)
    }
    
    
    /// Water droplet indicator
    private var waterDropletIndicator: some View {
        ZStack {
            // Droplet shape
            Circle()
                .fill(KingdomTheme.Colors.royalBlue)
                .frame(width: 14, height: 14)
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 5, height: 5)
                .offset(x: -2, y: -2)
        }
    }
    
    // MARK: - Tips Card
    
    private var gardenTipsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text("How to Garden")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "1.circle.fill", text: "Plant seeds in empty slots")
                tipRow(icon: "2.circle.fill", text: "Tap a plant to check its health")
                tipRow(icon: "3.circle.fill", text: "Water 4 times to grow, then harvest!")
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
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
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
                Task { await loadGardenStatus() }
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Slot Tap Handler
    
    private func handleSlotTap(slot: GardenSlot, seedCount: Int) {
        // For growing, ready, or dead plants, show detail sheet
        if slot.isGrowing || slot.isReady || slot.isDead {
            selectedSlot = slot
            return
        }
        
        Task {
            if slot.isEmpty && seedCount > 0 {
                await plantSeed(slotIndex: slot.slotIndex)
            } else if slot.isEmpty && seedCount == 0 {
                showResult(success: false, message: "No seeds! Find them while foraging.")
            }
        }
    }
    
    private func performWater(slotIndex: Int) {
        Task {
            selectedSlot = nil
            await waterPlant(slotIndex: slotIndex)
        }
    }
    
    private func performReadyAction(slot: GardenSlot) {
        Task {
            selectedSlot = nil
            if slot.plantType == "wheat" {
                await harvestPlant(slotIndex: slot.slotIndex)
            } else {
                // Flower and weed both just get cleared
                await discardPlant(slotIndex: slot.slotIndex)
            }
        }
    }
    
    private func performClear(slotIndex: Int) {
        Task {
            selectedSlot = nil
            await discardPlant(slotIndex: slotIndex)
        }
    }
    
    // MARK: - API Calls
    
    private func loadGardenStatus() async {
        isLoading = true
        errorMessage = nil
        await refreshGardenStatus()
        isLoading = false
    }
    
    private func refreshGardenStatus() async {
        do {
            status = try await gardenAPI.getStatus()
            
            // Schedule notifications for any growing plants that need watering
            if let slots = status?.slots {
                for slot in slots where slot.isGrowing && !slot.canWater {
                    if let seconds = slot.secondsUntilWater, seconds > 0 {
                        await NotificationManager.shared.scheduleGardenWateringNotification(
                            slotIndex: slot.slotIndex,
                            secondsUntilWater: seconds
                        )
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func plantSeed(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await gardenAPI.plantSeed(slotIndex: slotIndex)
            
            // Schedule notification for first watering
            if response.success, let seconds = response.nextWaterInSeconds, seconds > 0 {
                await NotificationManager.shared.scheduleGardenWateringNotification(
                    slotIndex: slotIndex,
                    secondsUntilWater: seconds
                )
            }
            
            await refreshGardenStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func waterPlant(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await gardenAPI.waterPlant(slotIndex: slotIndex)
            
            // Schedule notification for next watering (if not fully grown)
            if response.success && !response.isFullyGrown, let seconds = response.nextWaterInSeconds, seconds > 0 {
                await NotificationManager.shared.scheduleGardenWateringNotification(
                    slotIndex: slotIndex,
                    secondsUntilWater: seconds
                )
            } else if response.isFullyGrown {
                // Plant is done, cancel any pending notification
                NotificationManager.shared.cancelGardenNotification(slotIndex: slotIndex)
            }
            
            await refreshGardenStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func harvestPlant(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            _ = try await gardenAPI.harvestPlant(slotIndex: slotIndex)
            await refreshGardenStatus()
        } catch {
            showResult(success: false, message: error.localizedDescription)
        }
        
        actionInProgress = nil
    }
    
    private func discardPlant(slotIndex: Int) async {
        actionInProgress = slotIndex
        
        do {
            let response = try await gardenAPI.discardPlant(slotIndex: slotIndex)
            
            // Cancel notification for this slot
            if response.success {
                NotificationManager.shared.cancelGardenNotification(slotIndex: slotIndex)
            }
            
            await refreshGardenStatus()
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

struct GardenResultOverlay: View {
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
                Image(systemName: success ? "leaf.fill" : "xmark.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .brutalistBadge(
                        backgroundColor: success ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger,
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

// MARK: - Garden Slot Detail Sheet

struct GardenSlotDetailSheet: View {
    let slot: GardenSlot
    let currentTime: Date
    let onWater: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    // Health status based on water timing
    private var healthStatus: (text: String, color: Color, icon: String) {
        if slot.canWater {
            return ("Thirsty!", KingdomTheme.Colors.buttonWarning, "drop.triangle.fill")
        }
        
        guard let seconds = slot.secondsUntilWater, seconds > 0 else {
            return ("Thirsty!", KingdomTheme.Colors.buttonWarning, "drop.triangle.fill")
        }
        
        let hours = seconds / 3600
        if hours >= 3 {
            return ("Healthy", KingdomTheme.Colors.buttonSuccess, "heart.fill")
        } else if hours >= 1 {
            return ("Good", Color(red: 0.6, green: 0.8, blue: 0.3), "heart.fill")
        } else {
            return ("Needs Water Soon", KingdomTheme.Colors.buttonWarning, "heart.fill")
        }
    }
    
    // Time until can water (simplified)
    private var waterTimerText: String {
        guard let seconds = slot.secondsUntilWater, seconds > 0 else {
            return "Ready to water!"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "Water in \(hours)h \(minutes)m"
        }
        return "Water in \(minutes)m"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Drag handle
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Plant preview in a nice card
                VStack(spacing: 16) {
                    // Growth stage visual
                    ZStack {
                        // Soil background
                        Circle()
                            .fill(Color(red: 0.35, green: 0.25, blue: 0.18))
                            .frame(width: 100, height: 100)
                        
                        // Inner soil highlight
                        Circle()
                            .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                            .frame(width: 80, height: 80)
                        
                        // Plant graphic
                        GrowingPlantPreview(stage: slot.wateringCycles ?? 0)
                            .scaleEffect(1.3)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 3)
                            .frame(width: 100, height: 100)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                    
                    // Growth stage text
                    Text(growthStageText)
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.vertical, 8)
                
                // Health Status Card
                HStack(spacing: 12) {
                    // Health icon
                    ZStack {
                        Circle()
                            .fill(healthStatus.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: healthStatus.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(healthStatus.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text(healthStatus.text)
                            .font(FontStyles.headingMedium)
                            .foregroundColor(healthStatus.color)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(KingdomTheme.Colors.parchmentLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(healthStatus.color.opacity(0.5), lineWidth: 2)
                        )
                )
                .padding(.horizontal)
                
                // Growth Progress
                VStack(spacing: 12) {
                    HStack {
                        Text("Growth Progress")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Spacer()
                        Text("\(slot.wateringCycles ?? 0) / \(slot.wateringCyclesRequired ?? 4)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.disabled.opacity(0.3))
                            
                            // Fill
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KingdomTheme.Colors.buttonSuccess)
                                .frame(width: geo.size.width * progressPercent)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                        )
                    }
                    .frame(height: 20)
                    
                    // Water status
                    HStack(spacing: 6) {
                        Image(systemName: slot.canWater ? "drop.fill" : "clock")
                            .font(.system(size: 14))
                            .foregroundColor(slot.canWater ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.inkMedium)
                        Text(waterTimerText)
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                
                // Water button
                Button {
                    onWater()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(slot.canWater ? "Water Now" : "Check Back Later")
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
                            .fill(slot.canWater ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.disabled)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 2)
                    }
                )
                .foregroundColor(.white)
                .disabled(!slot.canWater)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(KingdomTheme.Colors.parchment)
    }
    
    private var growthStageText: String {
        switch slot.wateringCycles ?? 0 {
        case 0: return "Just Sprouted"
        case 1: return "Growing..."
        case 2: return "Getting Bigger!"
        case 3: return "Almost Ready!"
        default: return "Growing..."
        }
    }
    
    private var progressPercent: CGFloat {
        let cycles = CGFloat(slot.wateringCycles ?? 0)
        let required = CGFloat(slot.wateringCyclesRequired ?? 4)
        return cycles / required
    }
}

// MARK: - Growing Plant Preview (for detail sheet)

struct GrowingPlantPreview: View {
    let stage: Int
    
    var body: some View {
        switch stage {
        case 0:
            seedSprout
        case 1:
            smallSprout
        case 2:
            mediumPlant
        default:
            largePlant
        }
    }
    
    private var seedSprout: some View {
        ZStack {
            // Tiny stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.4, green: 0.6, blue: 0.3))
                .frame(width: 3, height: 12)
                .offset(y: 4)
            
            // Two tiny seed leaves
            HStack(spacing: 0) {
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.65, blue: 0.35))
                    .frame(width: 8, height: 5)
                    .rotationEffect(.degrees(-30))
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.65, blue: 0.35))
                    .frame(width: 8, height: 5)
                    .rotationEffect(.degrees(30))
            }
            .offset(y: -4)
        }
    }
    
    private var smallSprout: some View {
        ZStack {
            // Stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.35, green: 0.55, blue: 0.28))
                .frame(width: 4, height: 22)
                .offset(y: 2)
            
            // Leaves
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-40))
                .offset(x: -10, y: -2)
            Ellipse()
                .fill(Color(red: 0.45, green: 0.7, blue: 0.35))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(40))
                .offset(x: 10, y: -4)
            
            // Top bud
            Circle()
                .fill(Color(red: 0.35, green: 0.6, blue: 0.3))
                .frame(width: 8, height: 8)
                .offset(y: -12)
        }
    }
    
    private var mediumPlant: some View {
        ZStack {
            // Main stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.3, green: 0.5, blue: 0.25))
                .frame(width: 5, height: 32)
                .offset(y: 0)
            
            // Leaves
            Ellipse()
                .fill(Color(red: 0.38, green: 0.62, blue: 0.3))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(-50))
                .offset(x: -12, y: 6)
            Ellipse()
                .fill(Color(red: 0.42, green: 0.68, blue: 0.34))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(50))
                .offset(x: 12, y: 4)
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-35))
                .offset(x: -10, y: -8)
            Ellipse()
                .fill(Color(red: 0.45, green: 0.72, blue: 0.36))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(35))
                .offset(x: 10, y: -10)
            
            // Top growth
            Circle()
                .fill(Color(red: 0.35, green: 0.58, blue: 0.28))
                .frame(width: 10, height: 10)
                .offset(y: -18)
        }
    }
    
    private var largePlant: some View {
        ZStack {
            // Main stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.28, green: 0.48, blue: 0.22))
                .frame(width: 6, height: 38)
                .offset(y: -2)
            
            // Many leaves
            Ellipse()
                .fill(Color(red: 0.35, green: 0.58, blue: 0.28))
                .frame(width: 18, height: 10)
                .rotationEffect(.degrees(-55))
                .offset(x: -14, y: 10)
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 18, height: 10)
                .rotationEffect(.degrees(55))
                .offset(x: 14, y: 8)
            Ellipse()
                .fill(Color(red: 0.38, green: 0.62, blue: 0.3))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(-45))
                .offset(x: -12, y: -4)
            Ellipse()
                .fill(Color(red: 0.42, green: 0.68, blue: 0.34))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(45))
                .offset(x: 12, y: -6)
            Ellipse()
                .fill(Color(red: 0.4, green: 0.65, blue: 0.32))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(-30))
                .offset(x: -9, y: -16)
            Ellipse()
                .fill(Color(red: 0.45, green: 0.72, blue: 0.36))
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(30))
                .offset(x: 9, y: -18)
            
            // Mystery bud
            ZStack {
                Circle()
                    .fill(Color(red: 0.32, green: 0.55, blue: 0.26))
                    .frame(width: 14, height: 14)
                Text("?")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .offset(y: -26)
        }
    }
}

// MARK: - Garden Ready Sheet

struct GardenReadySheet: View {
    let slot: GardenSlot
    let onAction: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    private var plantName: String {
        slot.label
    }
    
    private var plantDescription: String {
        slot.description ?? ""
    }
    
    private var actionText: String {
        slot.canHarvest ? "Harvest" : "Clear"
    }
    
    private var actionColor: Color {
        slot.canHarvest ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.buttonDanger
    }
    
    private var rarityColor: Color {
        guard let colorString = slot.rarityColor else {
            return KingdomTheme.Colors.inkMedium
        }
        return KingdomTheme.Colors.color(fromThemeName: colorString)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Drag handle
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Plant visual
                ZStack {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.25, blue: 0.18))
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                        .frame(width: 80, height: 80)
                    
                    ReadyPlantPreview(plantType: slot.plantType, color: slot.color)
                        .scaleEffect(1.3)
                }
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 100, height: 100)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                
                // Plant name
                Text(plantName)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Rarity badge for flowers
                if let rarity = slot.rarity {
                    Text(rarity.capitalized)
                        .font(FontStyles.labelBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .brutalistBadge(backgroundColor: rarityColor)
                }
                
                // Description
                Text(plantDescription)
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Action button
                Button {
                    onAction()
                } label: {
                    Text(actionText)
                        .font(FontStyles.headingSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(actionColor)
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

// MARK: - Garden Dead Sheet

struct GardenDeadSheet: View {
    let slot: GardenSlot
    let onClear: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Drag handle
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Dead plant visual
                ZStack {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.25, blue: 0.18))
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                        .frame(width: 80, height: 80)
                    
                    // Wilted plant
                    DeadPlantPreview()
                        .scaleEffect(1.3)
                }
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 100, height: 100)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                
                // Title
                Text(slot.label)
                    .font(FontStyles.headingLarge)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                // Description from backend
                Text(slot.description ?? "This plant died from not being watered in time.")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Clear button
                Button {
                    onClear()
                } label: {
                    Text("Clear")
                        .font(FontStyles.headingSmall)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KingdomTheme.Colors.buttonDanger)
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

// MARK: - Dead Plant Preview

struct DeadPlantPreview: View {
    var body: some View {
        ZStack {
            // Wilted stem (bent)
            Path { path in
                path.move(to: CGPoint(x: 25, y: 30))
                path.addQuadCurve(
                    to: CGPoint(x: 18, y: 5),
                    control: CGPoint(x: 32, y: 18)
                )
            }
            .stroke(Color(red: 0.5, green: 0.4, blue: 0.25), lineWidth: 4)
            .frame(width: 50, height: 50)
            
            // Wilted brown leaves
            Ellipse()
                .fill(Color(red: 0.55, green: 0.42, blue: 0.28))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(70))
                .offset(x: -6, y: 0)
            
            Ellipse()
                .fill(Color(red: 0.5, green: 0.38, blue: 0.25))
                .frame(width: 10, height: 6)
                .rotationEffect(.degrees(-80))
                .offset(x: 8, y: -4)
            
            // Sad droopy top
            Circle()
                .fill(Color(red: 0.5, green: 0.4, blue: 0.28))
                .frame(width: 10, height: 10)
                .offset(x: -8, y: -10)
        }
    }
}

// MARK: - Ready Plant Preview

struct ReadyPlantPreview: View {
    let plantType: String?
    let color: String
    
    var body: some View {
        switch plantType {
        case "wheat":
            wheatPreview
        case "flower":
            flowerPreview
        case "weed":
            weedPreview
        default:
            weedPreview
        }
    }
    
    private var wheatPreview: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let xOffset = CGFloat(i - 1) * 16
                let heightVariation = CGFloat([0, -4, -2][i])
                VStack(spacing: 0) {
                    // Wheat head - tall oval with grain details
                    ZStack {
                        Ellipse()
                            .fill(Color(red: 0.9, green: 0.75, blue: 0.4))
                            .frame(width: 10, height: 28)
                        // Grain kernels on sides
                        ForEach(0..<6, id: \.self) { j in
                            Ellipse()
                                .fill(Color(red: 0.95, green: 0.82, blue: 0.5))
                                .frame(width: 5, height: 7)
                                .offset(x: j % 2 == 0 ? -6 : 6, y: CGFloat(j * 5) - 12)
                        }
                    }
                    // Stalk
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.7, green: 0.6, blue: 0.28))
                        .frame(width: 3, height: 22)
                }
                .offset(x: xOffset, y: heightVariation)
            }
        }
    }
    
    private var flowerPreview: some View {
        let flowerColor = colorFromString(color)
        return ZStack {
            // Stem
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.3, green: 0.5, blue: 0.25))
                .frame(width: 4, height: 28)
                .offset(y: 8)
            
            // Leaves
            Ellipse()
                .fill(Color(red: 0.35, green: 0.55, blue: 0.28))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(-45))
                .offset(x: -8, y: 12)
            Ellipse()
                .fill(Color(red: 0.4, green: 0.6, blue: 0.32))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(45))
                .offset(x: 8, y: 14)
            
            // Flower petals
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Ellipse()
                        .fill(flowerColor)
                        .frame(width: 10, height: 16)
                        .offset(y: -10)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 10)
            }
            .offset(y: -14)
        }
    }
    
    private var weedPreview: some View {
        ZStack {
            // Multiple scraggly stems
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.45, green: 0.5, blue: 0.35))
                    .frame(width: 2, height: CGFloat(18 + i * 4))
                    .rotationEffect(.degrees(Double(i * 15) - 22))
                    .offset(x: CGFloat(i * 6) - 9, y: CGFloat(4 - i * 2))
            }
            // Scraggly leaves
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .fill(Color(red: 0.5, green: 0.55, blue: 0.38))
                    .frame(width: 8, height: 5)
                    .rotationEffect(.degrees(Double(i * 40) - 40))
                    .offset(x: CGFloat(i * 8) - 8, y: CGFloat(i * 4) - 8)
            }
        }
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        KingdomTheme.Colors.color(fromThemeName: colorString)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GardenView()
    }
}
