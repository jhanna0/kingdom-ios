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
    
    // Phase 2
    @Published var currentLandingIndex: Int = -1
    @Published var bestLandingSoFar: Int = 0
    
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
    
    var maxLanding: Int {
        experiment?.phase2Cooking.maxLanding ?? 0
    }
    
    func tierForLanding(_ landing: Int) -> RewardTier? {
        rewardTiers.first { landing >= $0.minPercent && landing <= $0.maxPercent }
    }
    
    var landedTier: RewardTier? {
        guard let tierId = experiment?.phase2Cooking.landedTierId else { return nil }
        return rewardTiers.first { $0.id == tierId }
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
    
    var currentLanding: CookingLanding? {
        guard let landings = experiment?.phase2Cooking.landings,
              currentLandingIndex >= 0,
              currentLandingIndex < landings.count else { return nil }
        return landings[currentLandingIndex]
    }
    
    var remainingAttempts: Int {
        guard let cooking = experiment?.phase2Cooking else { return 0 }
        return cooking.totalAttempts - (currentLandingIndex + 1)
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
        currentLandingIndex = -1
        bestLandingSoFar = 0
        
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
            } else {
                currentLandingIndex = -1
                bestLandingSoFar = 0
                uiState = .cooking
            }
        }
    }
    
    // MARK: - Phase 2
    
    var isExperimentComplete: Bool {
        guard let landings = experiment?.phase2Cooking.landings else { return false }
        return currentLandingIndex >= landings.count - 1
    }
    
    func doNextLanding() {
        guard uiState == .cooking,
              let landings = experiment?.phase2Cooking.landings else { return }
        
        let nextIdx = currentLandingIndex + 1
        
        if nextIdx < landings.count {
            currentLandingIndex = nextIdx
            let landing = landings[nextIdx]
            
            if landing.isBest {
                withAnimation(.spring()) {
                    bestLandingSoFar = landing.landingPosition
                }
            }
        }
        // Don't switch to result screen - show results inline in cooking phase
    }
    
    // MARK: - Reset
    
    func reset() async {
        experiment = nil
        currentBarIndex = 0
        currentRollIndex = -1
        miniBarFills = [0, 0, 0]
        showReagentSelect = false
        mainTubeFill = 0
        currentLandingIndex = -1
        bestLandingSoFar = 0
        
        if let api = api {
            stats = try? await api.getStats()
        }
        uiState = .idle
    }
}
