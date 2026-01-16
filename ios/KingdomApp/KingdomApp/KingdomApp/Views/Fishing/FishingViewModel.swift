import SwiftUI
import Combine

// MARK: - Fishing View Model
// Handles session state, roll animations, and auto-advancing phases

@MainActor
class FishingViewModel: ObservableObject {
    
    // MARK: - UI State
    
    enum UIState: Equatable {
        case loading
        case idle                    // Ready to cast
        case casting                 // Animating cast rolls
        case fishFound               // Fish on the line! Brief pause
        case reeling                 // Animating reel rolls
        case caught                  // Fish caught! Brief celebration
        case escaped                 // Fish escaped! Brief feedback
        case masterRollAnimation     // Animating the final roll
        case error(String)
    }
    
    @Published var uiState: UIState = .loading
    @Published var session: FishingSession?
    @Published var config: FishingSessionConfig?
    @Published var playerStats: FishingPlayerStats?
    
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
    
    // Base slots for each phase (for resetting)
    private var baseCastSlots: [String: Int] = [:]
    private var baseReelSlots: [String: Int] = [:]
    
    // Animation timing - frontend controls this for chill experience
    private let rollAnimationDelay: UInt64 = 1_200_000_000  // 1.2 seconds per roll
    private let masterRollDelay: UInt64 = 800_000_000       // 0.8 seconds before master roll
    private let feedbackDelay: UInt64 = 2_000_000_000       // 2 seconds to show outcome
    
    // API
    private var fishingAPI: FishingAPI?
    
    // MARK: - Computed Properties
    
    var totalMeat: Int { session?.total_meat ?? 0 }
    var fishCaught: Int { session?.fish_caught ?? 0 }
    var petFishDropped: Bool { session?.pet_fish_dropped ?? false }
    var currentFish: String? { session?.current_fish }
    var currentFishData: FishData? { session?.current_fish_data }
    
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
    
    // MARK: - Initialization
    
    func configure(with client: APIClient) {
        self.fishingAPI = FishingAPI(client: client)
    }
    
    // MARK: - Session Management
    
    func startSession() async {
        guard let api = fishingAPI else { return }
        
        uiState = .loading
        
        do {
            // Load config first
            let fishingConfig = try await api.getConfig()
            castDropTableDisplay = fishingConfig.phases["cast"]?.drop_table_display ?? []
            reelDropTableDisplay = fishingConfig.phases["reel"]?.drop_table_display ?? []
            
            // Store base slots for each phase (for smooth transitions)
            baseCastSlots = fishingConfig.phases["cast"]?.drop_table ?? [:]
            baseReelSlots = fishingConfig.phases["reel"]?.drop_table ?? [:]
            
            // Start session
            let response = try await api.startFishing()
            session = response.session
            config = response.config
            playerStats = response.player_stats
            
            // Check if resuming with a fish already hooked
            if response.session.current_fish != nil {
                currentSlots = baseReelSlots
                uiState = .fishFound
            } else {
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
            // Could show rewards summary here
            print("Fishing complete! Meat: \(response.rewards.total_meat), Fish: \(response.rewards.fish_caught)")
            
            // Reset state
            session = nil
            uiState = .idle
        } catch {
            uiState = .error("Failed to end session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fishing Actions
    
    func cast() async {
        guard let api = fishingAPI, canCast else { return }
        
        // Reset animation state for new cast
        masterRollValue = 0
        shouldAnimateMasterRoll = false
        
        do {
            let response = try await api.cast()
            session = response.session
            currentPhaseResult = response.result
            
            // Setup roll animation - start with BASE slots, no roll visible yet
            currentRolls = response.result.rolls
            currentRollIndex = -1  // No roll shown yet
            currentSlots = response.result.base_slots ?? response.result.final_slots
            
            // Start animating rolls
            uiState = .casting
            await animateRolls(phase: .casting)
            
        } catch {
            uiState = .error("Cast failed: \(error.localizedDescription)")
        }
    }
    
    func reel() async {
        guard let api = fishingAPI, canReel else { return }
        
        // Reset animation state for new reel
        masterRollValue = 0
        shouldAnimateMasterRoll = false
        
        do {
            let response = try await api.reel()
            session = response.session
            currentPhaseResult = response.result
            
            // Setup roll animation - start with BASE slots, no roll visible yet
            currentRolls = response.result.rolls
            currentRollIndex = -1  // No roll shown yet
            currentSlots = response.result.base_slots ?? response.result.final_slots
            
            // Start animating rolls
            uiState = .reeling
            await animateRolls(phase: .reeling)
            
        } catch {
            uiState = .error("Reel failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Roll Animation
    
    private func animateRolls(phase: FishingPhase) async {
        guard let result = currentPhaseResult else { return }
        
        // Start with base slots (before any rolls) and no roll shown yet
        if let baseSlots = result.base_slots {
            currentSlots = baseSlots
        }
        currentRollIndex = -1  // No roll shown yet
        
        // Animate through each roll with delays
        for (index, roll) in currentRolls.enumerated() {
            // Wait first (let user see current state)
            try? await Task.sleep(nanoseconds: rollAnimationDelay)
            
            // NOW show this roll
            currentRollIndex = index
            
            // Update slots if this roll shifted them (bar animates smoothly)
            if let slotsAfter = roll.slots_after {
                currentSlots = slotsAfter
            }
        }
        
        // Brief pause to see final roll before master roll
        try? await Task.sleep(nanoseconds: masterRollDelay)
        
        // Now do master roll animation
        uiState = .masterRollAnimation
        masterRollValue = result.master_roll
        shouldAnimateMasterRoll = true
    }
    
    func onMasterRollAnimationComplete() {
        shouldAnimateMasterRoll = false
        
        guard let result = currentPhaseResult else {
            uiState = .idle
            return
        }
        
        // Handle outcome
        if result.phase == "cast" {
            if result.outcome == "no_bite" {
                // No fish - back to idle, can cast again
                // Reset to cast slots for next attempt
                currentSlots = baseCastSlots
                showBriefFeedback(state: .idle)
            } else {
                // Fish found! Switch to reel phase slots BEFORE showing fishFound
                currentSlots = baseReelSlots
                showBriefFeedback(state: .fishFound)
            }
        } else if result.phase == "reel" {
            if result.outcome == "caught" {
                // Caught! Show celebration briefly
                showBriefFeedback(state: .caught)
            } else {
                // Escaped - show briefly
                showBriefFeedback(state: .escaped)
            }
        }
    }
    
    private func showBriefFeedback(state: UIState) {
        uiState = state
        
        // Brief pause then transition
        Task {
            try? await Task.sleep(nanoseconds: feedbackDelay)
            
            // After caught/escaped/idle, reset to cast phase for next attempt
            if state == .caught || state == .escaped || state == .idle {
                currentSlots = baseCastSlots
                uiState = .idle
            }
            // fishFound state stays until user taps reel (slots already set to reel)
        }
    }
    
    // MARK: - Helpers
    
    var currentDropTableDisplay: [FishingDropTableItem] {
        switch uiState {
        case .casting, .masterRollAnimation:
            if currentPhaseResult?.phase == "reel" {
                return reelDropTableDisplay
            }
            return castDropTableDisplay
        case .reeling:
            return reelDropTableDisplay
        case .fishFound:
            return reelDropTableDisplay
        default:
            return castDropTableDisplay
        }
    }
    
    var phaseColor: Color {
        switch uiState {
        case .reeling, .fishFound:
            return KingdomTheme.Colors.buttonSuccess
        case .caught:
            return KingdomTheme.Colors.gold
        case .escaped:
            return KingdomTheme.Colors.buttonDanger
        default:
            return KingdomTheme.Colors.royalBlue
        }
    }
    
    var statusMessage: String {
        switch uiState {
        case .loading:
            return "Preparing..."
        case .idle:
            return "Cast your line"
        case .casting:
            return currentRoll?.message ?? "Waiting..."
        case .fishFound:
            if let fish = currentFishData {
                return "\(fish.icon ?? "🐟") \(fish.name ?? "Fish") on the line!"
            }
            return "Fish on the line!"
        case .reeling:
            return currentRoll?.message ?? "Reeling..."
        case .caught:
            return "Caught it!"
        case .escaped:
            return "It got away..."
        case .masterRollAnimation:
            return "..."
        case .error(let msg):
            return msg
        }
    }
}
