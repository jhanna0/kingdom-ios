import Foundation
import SwiftUI
import Combine

// MARK: - Hunt UI State Machine
// Single source of truth for hunt UI state - supports multi-roll system

enum HuntUIState: Equatable {
    case loading
    case noHunt                               // No active hunt - show create screen
    case lobby                                // In lobby waiting for players
    case phaseIntro(HuntPhase)                // Showing phase intro, waiting for user to tap first Roll
    case phaseActive(HuntPhase)               // In phase - can roll or resolve (multi-roll mode)
    case rolling(HuntPhase)                   // Currently executing a single roll
    case rollRevealing(HuntPhase)             // Revealing the result of a single roll
    case resolving(HuntPhase)                 // Executing the "Master Roll" / phase resolution
    case masterRollAnimation(HuntPhase)       // Showing master roll sliding animation
    case phaseComplete(HuntPhase)             // Showing phase result, waiting for user to Continue
    case creatureReveal                       // Special reveal for when creature is found
    case results                              // Final hunt results
}

// MARK: - Hunt View Model

@MainActor
class HuntViewModel: ObservableObject {
    // MARK: - Single State
    
    @Published var uiState: HuntUIState = .loading
    
    // MARK: - Data
    
    @Published var hunt: HuntSession?
    @Published var config: HuntConfigResponse?
    @Published var preview: HuntPreviewResponse?
    @Published var currentPhaseResult: PhaseResultData?
    
    @Published var error: String?
    @Published var showError = false
    
    // Roll reveal tracking (legacy)
    @Published var rollsRevealed: Set<Int> = []
    
    // Multi-roll tracking
    @Published var roundResults: [PhaseRoundResult] = []
    @Published var lastRollResult: PhaseRoundResult?
    @Published var lastPhaseUpdate: PhaseUpdate?
    
    // Probability display tracking
    @Published var currentTrackScore: Double = 0
    @Published var currentDamageDealt: Int = 0
    @Published var currentAnimalHP: Int = 1
    @Published var currentEscapeRisk: Double = 0
    @Published var currentBlessingBonus: Double = 0
    
    // DROP TABLE - Same system for ALL phases!
    // Track: creature odds, Attack: damage odds, Blessing: loot bonus odds
    @Published var dropTableSlots: [String: Int] = [:]
    @Published var dropTableOdds: [String: Double] = [:]  // Derived probabilities
    
    // Legacy (for backwards compat)
    @Published var creatureProbabilities: [String: Double] = [:]
    
    // Master roll animation
    @Published var masterRollValue: Int = 0
    @Published var masterRollAnimating = false
    @Published var selectedCreatureId: String?
    @Published var selectedOutcome: String?  // For attack/blessing resolution
    
    // MARK: - Computed Properties
    
    var currentUserId: Int?
    
    var isLeader: Bool {
        guard let hunt = hunt, let userId = currentUserId else { return false }
        return hunt.created_by == userId
    }
    
    var canStartHunt: Bool {
        guard let hunt = hunt else { return false }
        return isLeader && hunt.allReady && hunt.currentHuntPhase == .lobby
    }
    
    var allRollsRevealed: Bool {
        guard let result = currentPhaseResult else { return false }
        return rollsRevealed.count >= result.group_roll.rolls.count
    }
    
    /// Can perform another roll in current phase
    var canRoll: Bool {
        hunt?.phase_state?.can_roll ?? false
    }
    
    /// Can resolve/finalize current phase
    var canResolve: Bool {
        hunt?.phase_state?.can_resolve ?? false
    }
    
    /// Rolls completed in current phase
    var rollsCompleted: Int {
        hunt?.phase_state?.rounds_completed ?? 0
    }
    
    /// Max rolls allowed in current phase
    var maxRolls: Int {
        hunt?.phase_state?.max_rolls ?? 1
    }
    
    // MARK: - Phase Order
    // Simplified: Track → Strike → Blessing
    
    let phaseOrder: [HuntPhase] = [.track, .strike, .blessing]
    
    var nextPhase: HuntPhase? {
        guard let hunt = hunt else { return nil }
        let completedPhases = Set(hunt.phase_results.map { $0.huntPhase })
        return phaseOrder.first { !completedPhases.contains($0) }
    }
    
    // MARK: - State Transitions
    
    /// Called when the hunt data changes to determine the correct UI state
    func syncUIState() {
        guard let hunt = hunt else {
            uiState = .noHunt
            return
        }
        
        switch hunt.status {
        case .lobby:
            uiState = .lobby
        case .completed, .failed:
            uiState = .results
        case .cancelled:
            uiState = .noHunt
        case .inProgress:
            // If we're in an ANIMATION state, don't override
            // But DO override phaseActive if phase is resolved!
            switch uiState {
            case .rolling, .rollRevealing, .resolving, .masterRollAnimation, .creatureReveal:
                return
            case .phaseComplete:
                // Already showing complete, don't re-trigger
                return
            case .phaseActive(let currentPhase):
                // Check if phase was resolved externally (e.g., page reload)
                if let phaseState = hunt.phase_state, phaseState.is_resolved {
                    uiState = .phaseComplete(currentPhase)
                    return
                }
                // Otherwise stay in active state
                return
            default:
                break
            }
            
            // Determine current state from phase_state
            if let phaseState = hunt.phase_state {
                let phase = phaseState.huntPhase
                if phaseState.is_resolved {
                    // Phase completed - show result
                    uiState = .phaseComplete(phase)
                } else if phaseState.rounds_completed > 0 {
                    // Already started rolling - active phase
                    uiState = .phaseActive(phase)
                } else {
                    // Fresh phase - show intro
                    uiState = .phaseIntro(phase)
                }
            } else if let nextPhase = nextPhase {
                uiState = .phaseIntro(nextPhase)
            } else {
                uiState = .results
            }
        }
    }
    
    // MARK: - User Actions
    
    /// User taps "Begin" on phase intro - enters the phase (NO ROLL yet)
    func userTappedBeginPhase() async {
        guard case .phaseIntro(let phase) = uiState else { return }
        
        // Initialize tracking for this phase
        roundResults = []
        lastRollResult = nil
        lastPhaseUpdate = nil
        
        // ALL phases use the same drop table system!
        dropTableSlots = hunt?.phase_state?.drop_table_slots ?? [:]
        dropTableOdds = hunt?.phase_state?.dropTableOdds ?? [:]
        creatureProbabilities = dropTableOdds  // For backwards compat
        
        // Phase-specific initial values
        if phase == .track {
            currentTrackScore = 0
        } else if phase == .strike {
            currentDamageDealt = 0
            currentAnimalHP = hunt?.animal?.hp ?? 1
        } else if phase == .blessing {
            currentBlessingBonus = 0
        }
        
        // Just enter the phase - don't roll yet!
        uiState = .phaseActive(phase)
    }
    
    /// User taps roll button during active phase (additional rolls)
    func userTappedRollAgain() async {
        await executeRoll()
    }
    
    /// User taps "Master Roll" / "Resolve" button
    func userTappedResolve() async {
        await resolveCurrentPhase()
    }
    
    /// User taps "Continue" after seeing phase result
    func userTappedContinue() async {
        // Clear phase result
        currentPhaseResult = nil
        rollsRevealed = []
        roundResults = []
        lastRollResult = nil
        
        // Advance to next phase
        await advanceToNextPhase()
    }
    
    /// User taps "Continue" after creature reveal
    func userTappedContinueAfterCreatureReveal() async {
        currentPhaseResult = nil
        rollsRevealed = []
        roundResults = []
        
        await advanceToNextPhase()
    }
    
    // MARK: - Multi-Roll Phase Execution
    
    /// Execute a single roll within the current phase
    private func executeRoll() async {
        guard let huntId = hunt?.hunt_id,
              let currentPhase = hunt?.phase_state?.huntPhase else { return }
        
        uiState = .rolling(currentPhase)
        
        do {
            let response = try await KingdomAPIService.shared.hunts.executeRoll(huntId: huntId)
            
            if response.success {
                hunt = response.hunt
                lastRollResult = response.roll_result
                lastPhaseUpdate = response.phase_update
                
                if let rollResult = response.roll_result {
                    roundResults.append(rollResult)
                }
                
                // Transition to revealing state for dramatic effect
                uiState = .rollRevealing(currentPhase)
                
                // Animate the roll reveal
                try? await Task.sleep(nanoseconds: 600_000_000)
                
                // Update displays based on phase
                await updateDisplays(for: currentPhase, update: response.phase_update)
                
                try? await Task.sleep(nanoseconds: 400_000_000)
                
                // Check for phase auto-completion (Strike phase ends on kill)
                if let update = response.phase_update {
                    if update.killed == true {
                        // Animal killed - auto-resolve combat
                        await resolveCurrentPhase()
                        return
                    }
                }
                
                // Check if we've run out of rolls - must resolve
                if !(hunt?.canRoll ?? false) && (hunt?.canResolve ?? false) {
                    await resolveCurrentPhase()
                    return
                }
                
                // Back to active phase state
                uiState = .phaseActive(currentPhase)
                
            } else {
                error = response.message
                showError = true
                syncUIState()
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
            syncUIState()
        }
    }
    
    /// Resolve/finalize the current phase
    private func resolveCurrentPhase() async {
        guard let huntId = hunt?.hunt_id,
              let currentPhase = hunt?.phase_state?.huntPhase else { return }
        
        uiState = .resolving(currentPhase)
        
        do {
            let response = try await KingdomAPIService.shared.hunts.resolvePhase(huntId: huntId)
            
            if response.success {
                currentPhaseResult = response.phase_result
                hunt = response.hunt
                
                // ALL phases get master roll animation!
                if let effects = response.phase_result?.effects,
                   let rollValue = effects["master_roll"]?.intValue {
                    await showMasterRollAnimation(value: rollValue, phase: currentPhase)
                }
                
                // Special handling for Track phase - show creature reveal after animation
                if currentPhase == .track,
                   let effects = response.phase_result?.effects,
                   effects["animal_found"]?.boolValue == true {
                    uiState = .creatureReveal
                } else {
                    uiState = .phaseComplete(currentPhase)
                }
            } else {
                error = response.message
                showError = true
                syncUIState()
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
            syncUIState()
        }
    }
    
    /// Advance to the next phase after resolution
    private func advanceToNextPhase() async {
        guard let huntId = hunt?.hunt_id else {
            uiState = .results
            return
        }
        
        do {
            let response = try await KingdomAPIService.shared.hunts.nextPhase(huntId: huntId)
            
            if response.success {
                hunt = response.hunt
                
                if hunt?.isComplete == true {
                    uiState = .results
                } else if let phase = hunt?.phase_state?.huntPhase {
                    uiState = .phaseIntro(phase)
                } else {
                    uiState = .results
                }
            } else {
                error = response.message
                showError = true
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }
    
    /// Show the master roll sliding animation for ANY phase
    private func showMasterRollAnimation(value: Int, phase: HuntPhase? = nil) async {
        let targetPhase = phase ?? hunt?.phase_state?.huntPhase ?? .track
        
        uiState = .masterRollAnimation(targetPhase)
        masterRollAnimating = true
        
        // Animate the marker bouncing across the probability bar
        // Start from 0 and quickly bounce around before landing on final value
        for i in stride(from: 0, through: 100, by: 5) {
            masterRollValue = (i + Int.random(in: -10...10)).clamped(to: 0...100)
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        
        // Slow down and approach final value
        for i in 0..<10 {
            let progress = Double(i) / 10.0
            let targetValue = Int(Double(masterRollValue) * (1.0 - progress) + Double(value) * progress)
            masterRollValue = targetValue
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Land on final value
        masterRollValue = value
        masterRollAnimating = false
        
        // Brief pause to show result
        try? await Task.sleep(nanoseconds: 800_000_000)
    }
    
    /// Update drop table displays based on phase update
    /// ALL phases use the same drop table system!
    @MainActor
    private func updateDisplays(for phase: HuntPhase, update: PhaseUpdate?) async {
        guard let update = update else { return }
        
        // UNIVERSAL: Update drop table for ANY phase (track, strike, blessing)
        if let newSlots = update.drop_table_slots {
            let total = Double(newSlots.values.reduce(0, +))
            let newOdds = total > 0 ? newSlots.mapValues { Double($0) / total } : [:]
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                dropTableSlots = newSlots
                dropTableOdds = newOdds
                creatureProbabilities = newOdds  // For backwards compat
            }
        } else if let newProbs = update.new_probabilities {
            // Fallback to old format
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                dropTableOdds = newProbs
                creatureProbabilities = newProbs
            }
        }
        
        // Phase-specific visual updates (legacy HP bar etc)
        switch phase {
        case .track:
            if let tierShift = update.tier_shift {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    currentTrackScore += tierShift
                }
            }
            
        case .strike:
            // HP bar visual update
            if let remainingHP = update.remaining_hp {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    currentAnimalHP = max(0, remainingHP)
                }
            }
            
        case .blessing:
            // Nothing extra needed - drop table shows it all!
            break
            
        default:
            break
        }
    }
    
    private func getAnimalHP() -> Int {
        hunt?.animal?.hp ?? 1
    }
    
    // MARK: - API Methods
    
    func loadConfig() async {
        do {
            config = try await KingdomAPIService.shared.hunts.getHuntConfig()
        } catch {
            self.error = "Failed to load hunt config: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func loadPreview() async {
        do {
            preview = try await KingdomAPIService.shared.hunts.getHuntPreview()
        } catch {
            self.error = "Failed to load preview: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func checkForActiveHunt(kingdomId: String) async {
        uiState = .loading
        do {
            let response = try await KingdomAPIService.shared.hunts.getActiveHunt(kingdomId: kingdomId)
            hunt = response.active_hunt
            syncUIState()
        } catch {
            hunt = nil
            uiState = .noHunt
        }
    }
    
    func createHunt(kingdomId: String) async {
        uiState = .loading
        
        do {
            let response = try await KingdomAPIService.shared.hunts.createHunt(kingdomId: kingdomId)
            if response.success {
                hunt = response.hunt
                syncUIState()
            } else {
                error = response.message
                showError = true
                uiState = .noHunt
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
            uiState = .noHunt
        }
    }
    
    func joinHunt() async {
        guard let huntId = hunt?.hunt_id else { return }
        
        do {
            let response = try await KingdomAPIService.shared.hunts.joinHunt(huntId: huntId)
            if response.success {
                hunt = response.hunt
                syncUIState()
            } else {
                error = response.message
                showError = true
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }
    
    func leaveHunt() async {
        guard let huntId = hunt?.hunt_id else { return }
        
        do {
            let response = try await KingdomAPIService.shared.hunts.leaveHunt(huntId: huntId)
            if response.success {
                if response.hunt?.status == .cancelled {
                    hunt = nil
                } else {
                    hunt = response.hunt
                }
                syncUIState()
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }
    
    func toggleReady() async {
        guard let huntId = hunt?.hunt_id else { return }
        
        do {
            let response = try await KingdomAPIService.shared.hunts.toggleReady(huntId: huntId)
            if response.success {
                hunt = response.hunt
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }
    
    func startHunt() async {
        guard let huntId = hunt?.hunt_id else { return }
        
        do {
            let response = try await KingdomAPIService.shared.hunts.startHunt(huntId: huntId)
            if response.success {
                hunt = response.hunt
                currentTrackScore = 0
                currentDamageDealt = 0
                // Transition to first phase intro
                if let firstPhase = phaseOrder.first {
                    uiState = .phaseIntro(firstPhase)
                }
            } else {
                error = response.message
                showError = true
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }
    
    func resetForNewHunt() {
        hunt = nil
        currentPhaseResult = nil
        rollsRevealed = []
        roundResults = []
        lastRollResult = nil
        lastPhaseUpdate = nil
        currentTrackScore = 0
        currentDamageDealt = 0
        currentAnimalHP = 1
        currentEscapeRisk = 0
        currentBlessingBonus = 0
        creatureProbabilities = [:]
        masterRollValue = 0
        masterRollAnimating = false
        selectedCreatureId = nil
        uiState = .noHunt
    }
}

// MARK: - Int Extension

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
