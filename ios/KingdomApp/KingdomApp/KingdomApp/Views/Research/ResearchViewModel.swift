import SwiftUI
import Combine

@MainActor
class ResearchViewModel: ObservableObject {
    
    enum UIState: Equatable {
        case loading
        case idle
        case preparation      // Phase 1: mixing reagents
        case synthesis        // Phase 2: purifying
        case finalInfusion    // Final dramatic moment
        case result
        case error(String)
    }
    
    // MARK: - Published State
    
    @Published var uiState: UIState = .loading
    @Published var config: ResearchConfig?
    @Published var stats: PlayerResearchStats?
    @Published var experiment: ExperimentResult?
    
    // Phase 1: Preparation
    @Published var currentReagentIndex: Int = 0
    @Published var currentInfusionIndex: Int = -1
    @Published var reagentFills: [CGFloat] = [0, 0, 0]
    @Published var showAmountSelect: Bool = false
    @Published var potential: CGFloat = 0  // Main tube fill (0-1)
    
    // Phase 2: Synthesis
    @Published var currentSynthesisIndex: Int = -1
    @Published var purity: CGFloat = 0  // Current purity level (0-1)
    
    private var api: ResearchAPI?
    
    // MARK: - Config Accessors
    
    var preparationConfig: PreparationConfig? {
        experiment?.phase1Preparation.config
    }
    
    var synthesisConfig: SynthesisConfig? {
        experiment?.phase2Synthesis.config
    }
    
    var reagentNames: [String] {
        preparationConfig?.reagentNames ?? []
    }
    
    var resultTiers: [ResultTier] {
        synthesisConfig?.resultTiers ?? []
    }
    
    var potentialPercent: Int {
        experiment?.phase2Synthesis.potential ?? 0
    }
    
    var finalPurity: Int {
        experiment?.phase2Synthesis.finalPurity ?? 0
    }
    
    func tierForPurity(_ purity: Int) -> ResultTier? {
        resultTiers.first { purity >= $0.minPurity && purity <= $0.maxPurity }
    }
    
    var landedTier: ResultTier? {
        guard let tierId = experiment?.phase2Synthesis.resultTierId else { return nil }
        return resultTiers.first { $0.id == tierId }
    }
    
    // Phase 2 infusions (regular ones, not final)
    var synthesisInfusions: [SynthesisInfusion] {
        experiment?.phase2Synthesis.infusions ?? []
    }
    
    // The special final infusion
    var finalInfusionResult: SynthesisInfusion? {
        experiment?.phase2Synthesis.finalInfusion
    }
    
    var currentSynthesisInfusion: SynthesisInfusion? {
        guard currentSynthesisIndex >= 0,
              currentSynthesisIndex < synthesisInfusions.count else { return nil }
        return synthesisInfusions[currentSynthesisIndex]
    }
    
    var remainingSynthesisInfusions: Int {
        synthesisInfusions.count - (currentSynthesisIndex + 1)
    }
    
    // Current reagent being processed
    var currentReagent: ReagentResult? {
        guard let reagents = experiment?.phase1Preparation.reagents,
              currentReagentIndex < reagents.count else { return nil }
        return reagents[currentReagentIndex]
    }
    
    // Current infusion in phase 1
    var currentInfusion: Infusion? {
        guard let reagent = currentReagent,
              currentInfusionIndex >= 0,
              currentInfusionIndex < reagent.infusions.count else { return nil }
        return reagent.infusions[currentInfusionIndex]
    }
    
    // Progress message based on current purity
    var progressMessage: String {
        guard let messages = synthesisConfig?.progressMessages else { return "" }
        let purityPct = Int(purity * 100)
        let potentialPct = potentialPercent
        
        if purityPct == 0 { return messages.starting }
        if purityPct < 25 { return messages.low }
        if purityPct < 50 { return messages.warming }
        if purityPct >= potentialPct - 10 { return messages.excellent }
        if purityPct >= 50 { return messages.close }
        return messages.warming
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
        
        // Reset all state
        currentReagentIndex = 0
        currentInfusionIndex = -1
        reagentFills = [0, 0, 0]
        showAmountSelect = false
        potential = 0
        currentSynthesisIndex = -1
        purity = 0
        
        do {
            let response = try await api.runExperiment()
            experiment = response.experiment
            self.stats = response.playerStats
            uiState = .preparation
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Phase 1: Preparation
    
    func doNextPreparationInfusion() {
        guard uiState == .preparation,
              let reagents = experiment?.phase1Preparation.reagents,
              currentReagentIndex < reagents.count else { return }
        
        let reagent = reagents[currentReagentIndex]
        
        if !showAmountSelect {
            let nextIdx = currentInfusionIndex + 1
            
            if nextIdx < reagent.infusions.count {
                currentInfusionIndex = nextIdx
                let infusion = reagent.infusions[nextIdx]
                withAnimation(.easeOut(duration: 0.3)) {
                    reagentFills[currentReagentIndex] = CGFloat(infusion.totalFill)
                }
            } else {
                // Done with infusions, show amount selection
                showAmountSelect = true
            }
        } else {
            // Pour reagent into main tube (cap at 1.0)
            withAnimation(.easeOut(duration: 0.5)) {
                potential = min(1.0, potential + CGFloat(reagent.contribution))
            }
            
            let nextReagentIdx = currentReagentIndex + 1
            if nextReagentIdx < reagents.count {
                currentReagentIndex = nextReagentIdx
                currentInfusionIndex = -1
                showAmountSelect = false
            }
            // If last reagent: stays in showAmountSelect state, isPhase1Complete becomes true
        }
    }
    
    func transitionToSynthesis() {
        currentSynthesisIndex = -1
        purity = 0
        uiState = .synthesis
    }
    
    var isPhase1Complete: Bool {
        guard let expectedPotential = experiment?.phase1Preparation.potential else { return false }
        return Int(potential * 100) >= expectedPotential - 1
    }
    
    // MARK: - Phase 2: Synthesis
    
    var isSynthesisComplete: Bool {
        // All regular infusions done
        currentSynthesisIndex >= synthesisInfusions.count - 1
    }
    
    var isExperimentComplete: Bool {
        // All infusions done including final
        uiState == .result || (isSynthesisComplete && uiState != .finalInfusion)
    }
    
    func doNextSynthesisInfusion() {
        guard uiState == .synthesis else { return }
        
        let nextIdx = currentSynthesisIndex + 1
        
        if nextIdx < synthesisInfusions.count {
            currentSynthesisIndex = nextIdx
            let infusion = synthesisInfusions[nextIdx]
            
            // Update purity based on this infusion's result
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                purity = CGFloat(infusion.purityAfter) / 100.0
            }
        }
    }
    
    func transitionToFinalInfusion() {
        uiState = .finalInfusion
    }
    
    func applyFinalInfusion() {
        guard let final = finalInfusionResult else { return }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            purity = CGFloat(final.purityAfter) / 100.0
        }
    }
    
    func transitionToResult() {
        uiState = .result
    }
    
    // MARK: - Reset
    
    func reset() async {
        experiment = nil
        currentReagentIndex = 0
        currentInfusionIndex = -1
        reagentFills = [0, 0, 0]
        showAmountSelect = false
        potential = 0
        currentSynthesisIndex = -1
        purity = 0
        
        if let api = api {
            stats = try? await api.getStats()
        }
        uiState = .idle
    }
}
