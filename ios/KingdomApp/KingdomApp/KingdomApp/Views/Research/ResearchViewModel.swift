import SwiftUI
import Combine

@MainActor
class ResearchViewModel: ObservableObject {
    
    enum UIState: Equatable {
        case loading
        case idle
        case filling
        case cooking
        case result
        case error(String)
    }
    
    // MARK: - Published State
    
    @Published var uiState: UIState = .loading
    @Published var config: ResearchConfig?
    @Published var stats: PlayerResearchStats?
    @Published var experiment: ExperimentResult?
    
    // Phase 1
    @Published var currentBarIndex: Int = 0
    @Published var currentRollIndex: Int = -1
    @Published var miniBarFills: [CGFloat] = [0, 0, 0]
    @Published var showReagentSelect: Bool = false
    @Published var mainTubeFill: CGFloat = 0
    
    // Phase 2 (Crystallization)
    @Published var currentCrystalRollIndex: Int = -1
    @Published var crystalFloor: CGFloat = 0  // Current floor level (0-1)
    
    private var api: ResearchAPI?
    
    // MARK: - Config from backend
    
    var fillConfig: FillConfig? {
        experiment?.phase1Fill.config
    }
    
    var cookingConfig: CookingConfig? {
        experiment?.phase2Cooking.config
    }
    
    var miniBarNames: [String] {
        fillConfig?.miniBarNames ?? []
    }
    
    var rewardTiers: [RewardTier] {
        cookingConfig?.rewardTiers ?? []
    }
    
    var ceiling: Int {
        experiment?.phase2Cooking.ceiling ?? 0
    }
    
    var finalFloor: Int {
        experiment?.phase2Cooking.finalFloor ?? 0
    }
    
    func tierForFloor(_ floor: Int) -> RewardTier? {
        rewardTiers.first { floor >= $0.minPercent && floor <= $0.maxPercent }
    }
    
    var landedTier: RewardTier? {
        guard let tierId = experiment?.phase2Cooking.landedTierId else { return nil }
        return rewardTiers.first { $0.id == tierId }
    }
    
    var crystalRolls: [CrystallizationRoll] {
        experiment?.phase2Cooking.crystallizationRolls ?? []
    }
    
    var currentCrystalRoll: CrystallizationRoll? {
        guard currentCrystalRollIndex >= 0,
              currentCrystalRollIndex < crystalRolls.count else { return nil }
        return crystalRolls[currentCrystalRollIndex]
    }
    
    var remainingCrystalRolls: Int {
        guard let cooking = experiment?.phase2Cooking else { return 0 }
        return cooking.totalRolls - (currentCrystalRollIndex + 1)
    }
    
    var currentMiniBar: MiniBarResult? {
        guard let bars = experiment?.phase1Fill.miniBars,
              currentBarIndex < bars.count else { return nil }
        return bars[currentBarIndex]
    }
    
    var currentRoll: MiniRoll? {
        guard let bar = currentMiniBar,
              currentRollIndex >= 0,
              currentRollIndex < bar.rolls.count else { return nil }
        return bar.rolls[currentRollIndex]
    }
    
    
    // MARK: - Init
    
    func configure(with client: APIClient) {
        self.api = ResearchAPI(client: client)
    }
    
    func loadInitialData() async {
        guard let api = api else { return }
        uiState = .loading
        
        do {
            config = try await api.getConfig()
            stats = try await api.getStats()
            uiState = .idle
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Start Experiment
    
    func startExperiment() async {
        guard let api = api, let config = config, let stats = stats else { return }
        guard stats.gold >= config.goldCost else {
            uiState = .error("Need \(config.goldCost) gold")
            return
        }
        
        currentBarIndex = 0
        currentRollIndex = -1
        miniBarFills = [0, 0, 0]
        showReagentSelect = false
        mainTubeFill = 0
        currentCrystalRollIndex = -1
        crystalFloor = 0
        
        do {
            let response = try await api.runExperiment()
            experiment = response.experiment
            self.stats = response.playerStats
            uiState = .filling
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Phase 1
    
    func doNextFillRoll() {
        guard uiState == .filling,
              let miniBars = experiment?.phase1Fill.miniBars,
              currentBarIndex < miniBars.count else { return }
        
        let bar = miniBars[currentBarIndex]
        
        if !showReagentSelect {
            let nextRollIdx = currentRollIndex + 1
            
            if nextRollIdx < bar.rolls.count {
                currentRollIndex = nextRollIdx
                let roll = bar.rolls[nextRollIdx]
                withAnimation(.easeOut(duration: 0.3)) {
                    miniBarFills[currentBarIndex] = CGFloat(roll.totalFill)
                }
            } else {
                showReagentSelect = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.5)) {
                mainTubeFill += CGFloat(bar.contribution)
            }
            
            let nextBarIdx = currentBarIndex + 1
            if nextBarIdx < miniBars.count {
                currentBarIndex = nextBarIdx
                currentRollIndex = -1
                showReagentSelect = false
            }
            // Last bar: don't change anything else, currentRollIndex stays >= 0
        }
    }
    
    // Called by View when user taps CRYSTALLIZE
    func transitionToCrystallization() {
        currentCrystalRollIndex = -1
        crystalFloor = 0
        uiState = .cooking
    }
    
    var isPhase1Complete: Bool {
        guard let expected = experiment?.phase1Fill.mainTubeFill else { return false }
        return mainTubeFill >= CGFloat(expected) - 0.001
    }
    
    // MARK: - Phase 2 (Crystallization)
    
    var isExperimentComplete: Bool {
        // Done if all rolls completed OR floor reached ceiling
        currentCrystalRollIndex >= crystalRolls.count - 1 || crystalFloor >= mainTubeFill - 0.001
    }
    
    func doNextCrystalRoll() {
        guard uiState == .cooking else { return }
        
        let nextIdx = currentCrystalRollIndex + 1
        
        if nextIdx < crystalRolls.count {
            currentCrystalRollIndex = nextIdx
            let roll = crystalRolls[nextIdx]
            
            // Update crystal floor based on this roll's result
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                crystalFloor = CGFloat(roll.floorAfter) / 100.0
            }
        }
        // Results shown inline in cooking phase
    }
    
    // MARK: - Reset
    
    func reset() async {
        experiment = nil
        currentBarIndex = 0
        currentRollIndex = -1
        miniBarFills = [0, 0, 0]
        showReagentSelect = false
        mainTubeFill = 0
        currentCrystalRollIndex = -1
        crystalFloor = 0
        
        if let api = api {
            stats = try? await api.getStats()
        }
        uiState = .idle
    }
}
