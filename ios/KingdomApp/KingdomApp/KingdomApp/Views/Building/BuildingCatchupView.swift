import SwiftUI

/// View for buildings that need capacity expansion.
/// Player works on normal building contracts to make progress - no separate work button.
struct BuildingCatchupView: View {
    let building: BuildingMetadata
    let kingdom: Kingdom
    let onDismiss: () -> Void
    let onComplete: () -> Void
    
    @State private var isLoading = true
    @State private var actionsCompleted: Int
    @State private var actionsRequired: Int
    @State private var errorMessage: String?
    
    init(building: BuildingMetadata, kingdom: Kingdom, onDismiss: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.building = building
        self.kingdom = kingdom
        self.onDismiss = onDismiss
        self.onComplete = onComplete
        self._actionsCompleted = State(initialValue: building.catchup?.actionsCompleted ?? 0)
        self._actionsRequired = State(initialValue: building.catchup?.actionsRequired ?? 0)
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchmentDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 24) {
                        buildingInfo
                        progressSection
                        instructionsSection
                    }
                    .padding(KingdomTheme.Spacing.large)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startCatchup()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "hammer.fill")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    
                    Text("EXPAND CAPACITY")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .padding(.horizontal, KingdomTheme.Spacing.large)
            .padding(.vertical, KingdomTheme.Spacing.medium)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
        }
        .background(KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Building Info
    
    private var buildingInfo: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: building.colorHex) ?? KingdomTheme.Colors.buttonPrimary)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
                
                Image(systemName: building.icon)
                    .font(FontStyles.resultLarge)
                    .foregroundColor(.white)
            }
            
            Text(building.displayName)
                .font(FontStyles.displaySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Level \(building.level)")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.top, KingdomTheme.Spacing.medium)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack {
                    Text("Your Contributions")
                        .font(FontStyles.labelBlackSerif)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("\(actionsCompleted)/\(actionsRequired)")
                        .font(FontStyles.statMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: max(0, geo.size.width * progressPercent - 4))
                            .padding(2)
                    }
                }
                .frame(height: 24)
            }
            
            let remaining = actionsRequired - actionsCompleted
            if remaining > 0 {
                Text("\(remaining) more contributions needed")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else {
                Text("Expansion complete!")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment)
    }
    
    private var progressPercent: CGFloat {
        guard actionsRequired > 0 else { return 1.0 }
        return CGFloat(actionsCompleted) / CGFloat(actionsRequired)
    }
    
    // MARK: - Instructions
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Expand")
                .font(FontStyles.headingSmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Your kingdom built the \(building.displayName) before you could help. Its capacity isn't great enough to support you yet.")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                Text("Go to Actions → Building to work on contracts")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text("Your work on \(building.displayName) contracts counts toward capacity!")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Actions
    
    /// Called on appear - marks building as "started" so it shows in Actions view
    private func startCatchup() {
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/actions/catchup/\(building.type)/start",
                    method: "POST"
                )
                let response: CatchupStartResponse = try await APIClient.shared.execute(request)
                
                await MainActor.run {
                    actionsRequired = response.actionsRequired
                    actionsCompleted = response.actionsCompleted
                    isLoading = false
                    
                    if response.alreadyComplete == true {
                        onComplete()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Response Model

struct CatchupStartResponse: Codable {
    let success: Bool
    let started: Bool?
    let alreadyStarted: Bool?
    let alreadyComplete: Bool?
    let buildingType: String?
    let buildingDisplayName: String?
    let actionsRequired: Int
    let actionsCompleted: Int
    let actionsRemaining: Int
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success, started, message
        case alreadyStarted = "already_started"
        case alreadyComplete = "already_complete"
        case buildingType = "building_type"
        case buildingDisplayName = "building_display_name"
        case actionsRequired = "actions_required"
        case actionsCompleted = "actions_completed"
        case actionsRemaining = "actions_remaining"
    }
}

#Preview {
    Text("Catchup Preview")
}
