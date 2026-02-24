import SwiftUI
import Combine

// MARK: - Fishing View Model
// Simple state machine for fishing minigame
// 3 bars: Cast (fish odds) → Reel (catch odds) → Loot (rewards)

@MainActor
class FishingViewModel: ObservableObject {
    
    // MARK: - UI State
    
    enum UIState: Equatable {
        case loading
        case idle                    // Ready to cast
        case casting                 // Animating cast rolls
        case fishFound               // Fish on the line! Waiting for reel
        case reeling                 // Animating reel rolls
        case caught                  // Fish caught! Press Loot to roll
        case looting                 // Animating loot roll
        case lootResult              // Loot done - press Collect
        case escaped                 // Fish escaped! Brief feedback
        case masterRollAnimation     // Animating the final roll
        case error(String)
    }
    
    // Which bar are we showing?
    enum BarType: Equatable { case cast, reel, loot }
    
    // MARK: - Published State
    
    @Published var uiState: UIState = .loading
    @Published var session: FishingSession?
    @Published var config: FishingSessionConfig?
    @Published var playerStats: FishingPlayerStats?
    
    // Current bar - set in cast(), reel(), and after catch
    @Published var currentBarType: BarType = .cast
    
    // Loot result (after successful catch) - from backend
    @Published var currentLootResult: FishingLootResult?
    
    // Roll animation state
    @Published var currentRolls: [FishingRollResult] = []
    @Published var currentRollIndex: Int = 0
    @Published var currentSlots: [String: Int] = [:]
    @Published var masterRollValue: Int = 0
    @Published var shouldAnimateMasterRoll: Bool = false
    
    // Current phase result (after API call)
    @Published var currentPhaseResult: FishingPhaseResult?
    
    // Drop table display configs (from backend)
    @Published var castDropTableDisplay: [FishingDropTableItem] = []
    @Published var reelDropTableDisplay: [FishingDropTableItem] = []
    
    // Phase configs (from backend)
    @Published var castPhaseConfig: FishingPhaseConfig?
    @Published var reelPhaseConfig: FishingPhaseConfig?
    @Published var lootPhaseConfig: FishingPhaseConfig?
    
    // Base slots for each phase
    private var baseCastSlots: [String: Int] = [:]
    private var baseReelSlots: [String: Int] = [:]
    
    // Pending session update (deferred until animation completes to avoid spoilers)
    private var pendingSession: FishingSession?
    
    // Animation timing
    private let rollAnimationDelay: Double = 1.2   // Time between rolls
    private let firstRollDelay: Double = 0.75      // Shorter delay before first roll
    private let masterRollDelay: Double = 0.3      // Pause before master roll
    private let feedbackDelay: Double = 0.6        // Time on escaped/idle before resetting
    private let lootPause: Double = 0.55           // Brief pause before loot animation
    
    // API
    private var fishingAPI: FishingAPI?
    
    // MARK: - Simple Computed Properties
    
    var totalMeat: Int { session?.total_meat ?? 0 }
    var fishCaught: Int { session?.fish_caught ?? 0 }
    var petFishDropped: Bool { session?.pet_fish_dropped ?? false }
    var currentFish: String? { session?.current_fish }
    var currentFishData: FishData? { session?.current_fish_data }
    var currentStreakInfo: FishingStreakInfo? { currentPhaseResult?.outcome_display.streak_info }
    var shouldShowStreakPopup: Bool { currentPhaseResult?.outcome_display.shouldShowStreakPopup ?? false }
    
    var castRolls: Int { config?.cast_rolls ?? 1 }
    var reelRolls: Int { config?.reel_rolls ?? 1 }
    var hitChance: Int { config?.hit_chance ?? 15 }
    
    var currentRoll: FishingRollResult? {
        guard currentRollIndex >= 0, currentRollIndex < currentRolls.count else { return nil }
        return currentRolls[currentRollIndex]
    }
    
    var isAnimatingRolls: Bool {
        uiState == .casting || uiState == .reeling
    }
    
    var canCast: Bool {
        uiState == .idle && currentFish == nil
    }
    
    var canReel: Bool {
        uiState == .fishFound && currentFish != nil
    }
    
    // Bar-related properties based on currentBarType
    
    var currentDropTableDisplay: [FishingDropTableItem] {
        switch currentBarType {
        case .cast: return castDropTableDisplay
        case .reel: return reelDropTableDisplay
        case .loot: return currentLootResult?.drop_table_display ?? []
        }
    }
    
    var currentPhaseConfig: FishingPhaseConfig? {
        switch currentBarType {
        case .cast: return castPhaseConfig
        case .reel: return reelPhaseConfig
        case .loot: return lootPhaseConfig
        }
    }
    
    var currentRollCount: Int {
        switch currentBarType {
        case .cast: return castRolls
        case .reel: return reelRolls
        case .loot: return 0  // No rolls in loot phase
        }
    }
    
    var currentStatName: String {
        currentPhaseConfig?.stat_display_name ?? "Skill"
    }
    
    var currentStatIcon: String {
        currentPhaseConfig?.stat_icon ?? "star.fill"
    }
    
    var mainOutcomePercentage: Int {
        // For loot phase, don't show percentage
        if currentBarType == .loot { return 0 }
        
        let total = currentSlots.values.reduce(0, +)
        guard total > 0 else { return 0 }
        
        let display = currentDropTableDisplay
        if currentBarType == .reel {
            if let goodKey = display.last?.key {
                let good = currentSlots[goodKey] ?? 0
                return Int((Double(good) / Double(total)) * 100)
            }
        } else {
            if let badKey = display.first?.key {
                let bad = currentSlots[badKey] ?? 0
                let good = total - bad
                return Int((Double(good) / Double(total)) * 100)
            }
        }
        return 0
    }
    
    var phaseColor: Color {
        switch uiState {
        case .fishFound: return KingdomTheme.Colors.gold
        case .caught, .looting, .lootResult: return KingdomTheme.Colors.gold
        case .escaped: return KingdomTheme.Colors.inkMedium
        default:
            if let colorName = currentPhaseConfig?.phase_color {
                return KingdomTheme.Colors.color(fromThemeName: colorName)
            }
            return KingdomTheme.Colors.royalBlue
        }
    }
    
    var currentBarTitle: String {
        // For loot phase: use bar_title from backend
        if currentBarType == .loot {
            return currentLootResult?.bar_title ?? "LOOT"
        }
        return currentPhaseConfig?.drop_table_title ?? "ODDS"
    }
    
    var currentMarkerIcon: String {
        currentPhaseConfig?.roll_button_icon ?? "scope"
    }
    
    var statusMessage: String {
        switch uiState {
        case .loading: return "Wading in..."
        case .idle: return "Cast your line."
        case .casting: return currentRoll?.message ?? "Line's out..."
        case .fishFound:
            if let fish = currentFishData {
                return "\(fish.icon ?? "🐟") \(fish.name ?? "Fish") on the line!"
            }
            return "A bite!"
        case .reeling: return currentRoll?.message ?? "Hold steady..."
        case .caught:
            return "Landed! Time to claim your spoils."
        case .looting:
            return "Checking the creel..."
        case .lootResult:
            if let loot = currentLootResult {
                if loot.rare_loot_dropped, let rareName = loot.rare_loot_name {
                    return "🎉 \(rareName) + \(loot.meat_earned) meat!"
                }
                return "+\(loot.meat_earned) meat!"
            }
            return "Collect your loot!"
        case .escaped: return "It slipped the hook..."
        case .masterRollAnimation: return "..."
        case .error(let msg): return msg
        }
    }
    
    // MARK: - Initialization
    
    func configure(with client: APIClient) {
        self.fishingAPI = FishingAPI(client: client)
    }
    
    // MARK: - Session Management
    
    func startSession() async {
        guard let api = fishingAPI else { return }
        
        uiState = .loading
        
        do {
            let fishingConfig = try await api.getConfig()
            castDropTableDisplay = fishingConfig.phases["cast"]?.drop_table_display ?? []
            reelDropTableDisplay = fishingConfig.phases["reel"]?.drop_table_display ?? []
            castPhaseConfig = fishingConfig.phases["cast"]
            reelPhaseConfig = fishingConfig.phases["reel"]
            lootPhaseConfig = fishingConfig.phases["loot"]
            baseCastSlots = fishingConfig.phases["cast"]?.drop_table ?? [:]
            baseReelSlots = fishingConfig.phases["reel"]?.drop_table ?? [:]
            
            let response = try await api.startFishing()
            session = response.session
            config = response.config
            playerStats = response.player_stats
            
            if response.session.current_fish != nil {
                currentBarType = .reel
                currentSlots = baseReelSlots
                uiState = .fishFound
            } else {
                currentBarType = .cast
                currentSlots = baseCastSlots
                uiState = .idle
            }
        } catch {
            uiState = .error("Failed to start fishing: \(error.localizedDescription)")
        }
    }
    
    func endSession() async {
        guard let api = fishingAPI else { return }
        
        do {
            let response = try await api.endFishing()
            print("Fishing complete! Meat: \(response.rewards.total_meat), Fish: \(response.rewards.fish_caught)")
            session = nil
            uiState = .idle
        } catch {
            uiState = .error("Failed to end session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fishing Actions
    
    func cast() async {
        guard let api = fishingAPI, canCast else { return }
        
        // Set casting state immediately to prevent double-taps
        uiState = .casting
        
        currentBarType = .cast
        currentSlots = baseCastSlots
        
        // Reset animation state cleanly - order matters for onChange handlers
        shouldAnimateMasterRoll = false
        masterRollValue = 0
        
        currentPhaseResult = nil
        currentLootResult = nil
        
        do {
            let response = try await api.cast()
            session = response.session
            currentPhaseResult = response.result
            currentRolls = response.result.rolls
            currentRollIndex = -1
            currentSlots = response.result.base_slots ?? response.result.final_slots
            
            animateRolls()
        } catch {
            uiState = .error("Cast failed: \(error.localizedDescription)")
        }
    }
    
    func reel() async {
        guard let api = fishingAPI, canReel else { return }
        
        // Set reeling state immediately to prevent double-taps
        uiState = .reeling
        
        currentBarType = .reel
        currentSlots = baseReelSlots
        
        // Reset animation state cleanly - order matters for onChange handlers
        shouldAnimateMasterRoll = false
        masterRollValue = 0
        
        currentPhaseResult = nil
        
        do {
            let response = try await api.reel()
            // Defer session update until animation completes (prevents fish count spoiler)
            pendingSession = response.session
            currentPhaseResult = response.result
            currentRolls = response.result.rolls
            currentRollIndex = -1
            currentSlots = response.result.base_slots ?? response.result.final_slots
            
            animateRolls()
        } catch {
            uiState = .error("Reel failed: \(error.localizedDescription)")
        }
    }
    
    /// User presses Loot button - animate the loot roll
    func loot() {
        guard uiState == .caught, let lootResult = currentLootResult else { return }
        
        // Switch to loot bar
        currentBarType = .loot
        currentSlots = lootResult.drop_table
        
        // Reset animation state BEFORE setting new values
        // This ensures onChange handlers see a clean transition
        shouldAnimateMasterRoll = false
        masterRollValue = 0
        
        // Start loot animation
        uiState = .looting
        
        // Animate to result (uses wall-clock time, runs in background)
        DispatchQueue.main.asyncAfter(deadline: .now() + lootPause) { [weak self] in
            guard let self = self else { return }
            self.masterRollValue = lootResult.master_roll
            self.shouldAnimateMasterRoll = true
        }
    }
    
    /// Called when loot roll animation completes (legacy - now handled in onMasterRollAnimationComplete)
    func onLootAnimationComplete() {
        shouldAnimateMasterRoll = false
        uiState = .lootResult
    }
    
    /// Collect loot and go back to idle
    func collect() {
        currentLootResult = nil
        
        // Reset animation state cleanly
        shouldAnimateMasterRoll = false
        masterRollValue = 0
        
        currentRolls = []
        currentRollIndex = -1
        currentBarType = .cast
        currentSlots = baseCastSlots
        uiState = .idle
    }
    
    // MARK: - Roll Animation (uses DispatchQueue for background execution)
    
    private func animateRolls() {
        guard let result = currentPhaseResult else { return }
        
        if let baseSlots = result.base_slots {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentSlots = baseSlots
            }
        }
        currentRollIndex = -1
        
        // Schedule each roll at absolute times from now
        var delay: Double = 0
        for (index, roll) in currentRolls.enumerated() {
            delay += (index == 0) ? firstRollDelay : rollAnimationDelay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.currentRollIndex = index
                
                if let slotsAfter = roll.slots_after, roll.is_success {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        self.currentSlots = slotsAfter
                    }
                }
            }
        }
        
        // Schedule master roll after all individual rolls
        delay += masterRollDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.uiState = .masterRollAnimation
            self.masterRollValue = result.master_roll
            self.shouldAnimateMasterRoll = true
        }
    }
    
    func onMasterRollAnimationComplete() {
        shouldAnimateMasterRoll = false
        
        // If animating loot roll, go to loot result
        if uiState == .looting {
            // NOW apply the pending session - meat/fish counts update after the loot reveal
            if let pending = pendingSession {
                session = pending
                pendingSession = nil
            }
            uiState = .lootResult
            return
        }
        
        guard let result = currentPhaseResult else {
            uiState = .idle
            return
        }
        
        if result.phase == "cast" {
            if result.outcome == "no_bite" {
                showFeedback(state: .idle)
            } else {
                showFeedback(state: .fishFound)
            }
        } else {
            // Reel phase
            if result.outcome == "caught" {
                // Store loot result from backend
                // DON'T apply pending session yet - wait until loot animation completes
                // so meat count doesn't spoil the reveal
                currentLootResult = result.outcome_display.loot
                showFeedback(state: .caught)
            } else {
                // Escaped - apply session now (no loot animation coming)
                if let pending = pendingSession {
                    session = pending
                    pendingSession = nil
                }
                showFeedback(state: .escaped)
            }
        }
    }
    
    private func showFeedback(state: UIState) {
        uiState = state
        
        if state == .idle {
            // Reset animation state when returning to idle
            shouldAnimateMasterRoll = false
            masterRollValue = 0
            currentRolls = []
            currentRollIndex = -1
        } else if state == .escaped {
            DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDelay) { [weak self] in
                guard let self = self else { return }
                // Reset animation state when returning to idle after escape
                self.shouldAnimateMasterRoll = false
                self.masterRollValue = 0
                self.currentRolls = []
                self.currentRollIndex = -1
                self.uiState = .idle
            }
        }
        // caught stays until user presses Loot
        // fishFound stays until user presses Reel
    }
}
