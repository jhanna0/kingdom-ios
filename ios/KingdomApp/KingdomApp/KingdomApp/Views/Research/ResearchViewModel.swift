import SwiftUI
import Combine

// MARK: - Research View Model

@MainActor
class ResearchViewModel: ObservableObject {
    
    enum UIState: Equatable {
        case loading
        case idle
        case filling           // Phase 1: animating 3 mini bars
        case fillResult        // Phase 1 done, show result
        case stabilizing       // Phase 2
        case stabilizeResult
        case building          // Phase 3
        case result
        case error(String)
    }
    
    // MARK: - Published State
    
    @Published var uiState: UIState = .loading
    @Published var config: ResearchConfig?
    @Published var stats: PlayerResearchStats?
    @Published var experiment: ExperimentResult?
    
    // Phase 1: Mini bars
    @Published var currentBarIndex: Int = 0        // Which mini bar (0, 1, 2)
    @Published var currentRollIndex: Int = -1      // Which roll on current bar
    @Published var miniBarFills: [CGFloat] = [0, 0, 0]  // Fill level of each mini bar
    @Published var showMasterRoll: Bool = false
    @Published var masterRollValue: Int = 0
    @Published var mainTubeFill: CGFloat = 0
    
    // Phase 2: Stabilize
    @Published var stabilizeRollIndex: Int = -1
    @Published var stabilizeHits: Int = 0
    
    // Phase 3: Build
    @Published var currentTapIndex: Int = 0
    @Published var buildProgress: Int = 0
    
    // Timing
    private let rollDelay: UInt64 = 1_000_000_000      // 1 sec per roll
    private let masterRollDelay: UInt64 = 1_500_000_000 // 1.5 sec for master roll
    private let phaseDelay: UInt64 = 1_000_000_000      // 1 sec between phases
    
    private var api: ResearchAPI?
    
    // MARK: - Computed
    
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
    
    var currentStabilizeRoll: StabilizeRoll? {
        guard let rolls = experiment?.phase2Stabilize.rolls,
              stabilizeRollIndex >= 0,
              stabilizeRollIndex < rolls.count else { return nil }
        return rolls[stabilizeRollIndex]
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
        
        // Reset
        currentBarIndex = 0
        currentRollIndex = -1
        miniBarFills = [0, 0, 0]
        showMasterRoll = false
        masterRollValue = 0
        mainTubeFill = 0
        stabilizeRollIndex = -1
        stabilizeHits = 0
        currentTapIndex = 0
        buildProgress = 0
        
        do {
            let response = try await api.runExperiment()
            experiment = response.experiment
            self.stats = response.playerStats
            
            // Ready for user to click through rolls
            uiState = .filling
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Phase 1: Fill - User clicks each roll
    
    func doNextFillRoll() {
        guard uiState == .filling,
              let miniBars = experiment?.phase1Fill.miniBars,
              currentBarIndex < miniBars.count else { return }
        
        let bar = miniBars[currentBarIndex]
        
        // If we haven't shown master roll yet
        if !showMasterRoll {
            let nextRollIdx = currentRollIndex + 1
            
            if nextRollIdx < bar.rolls.count {
                // Show next roll
                currentRollIndex = nextRollIdx
                let roll = bar.rolls[nextRollIdx]
                withAnimation(.easeOut(duration: 0.3)) {
                    miniBarFills[currentBarIndex] = CGFloat(roll.totalFill)
                }
            } else {
                // All rolls done, show master roll
                showMasterRoll = true
                masterRollValue = bar.masterRoll
            }
        } else {
            // Master roll shown, add contribution and move to next bar
            withAnimation(.easeOut(duration: 0.5)) {
                mainTubeFill += CGFloat(bar.contribution)
            }
            
            // Move to next bar or finish
            let nextBarIdx = currentBarIndex + 1
            if nextBarIdx < miniBars.count {
                currentBarIndex = nextBarIdx
                currentRollIndex = -1
                showMasterRoll = false
            } else {
                // All bars done
                uiState = .fillResult
            }
        }
    }
    
    // MARK: - Phase 2: Stabilize
    
    func startStabilize() async {
        guard let exp = experiment else { return }
        
        if !exp.phase1Fill.success {
            uiState = .result
            return
        }
        
        stabilizeRollIndex = -1
        stabilizeHits = 0
        uiState = .stabilizing
    }
    
    func doNextStabilizeRoll() {
        guard uiState == .stabilizing,
              let rolls = experiment?.phase2Stabilize.rolls else { return }
        
        let nextIdx = stabilizeRollIndex + 1
        
        if nextIdx < rolls.count {
            stabilizeRollIndex = nextIdx
            let roll = rolls[nextIdx]
            
            if roll.hit {
                withAnimation(.spring()) {
                    stabilizeHits += 1
                }
            }
        } else {
            // Done with stabilize
            uiState = .stabilizeResult
        }
    }
    
    // MARK: - Phase 3: Build
    
    func startBuild() async {
        guard let exp = experiment else { return }
        
        if !exp.phase2Stabilize.success {
            uiState = .result
            return
        }
        
        currentTapIndex = 0
        buildProgress = 0
        uiState = .building
    }
    
    func handleTap() {
        guard uiState == .building,
              let taps = experiment?.phase3Build.taps,
              currentTapIndex < taps.count else { return }
        
        let tap = taps[currentTapIndex]
        
        withAnimation(.spring()) {
            buildProgress = tap.totalProgress
        }
        
        currentTapIndex += 1
        
        if currentTapIndex >= taps.count || tap.totalProgress >= (experiment?.phase3Build.progressNeeded ?? 100) {
            Task {
                try? await Task.sleep(nanoseconds: phaseDelay)
                uiState = .result
            }
        }
    }
    
    // MARK: - Reset
    
    func reset() async {
        experiment = nil
        currentBarIndex = 0
        currentRollIndex = -1
        miniBarFills = [0, 0, 0]
        showMasterRoll = false
        masterRollValue = 0
        mainTubeFill = 0
        stabilizeRollIndex = -1
        stabilizeHits = 0
        currentTapIndex = 0
        buildProgress = 0
        
        if let api = api {
            stats = try? await api.getStats()
        }
        uiState = .idle
    }
}
