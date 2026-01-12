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
    case masterRollComplete(HuntPhase)        // Animation done, show Continue button
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
    
    // Master roll state
    @Published var masterRollFinalValue: Int = 0
    @Published var shouldAnimateMasterRoll: Bool = false
    
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
            // If we're in an ANIMATION or TRANSITION state, don't override
            switch uiState {
            case .rolling, .rollRevealing, .resolving, .masterRollAnimation, .masterRollComplete, .creatureReveal, .phaseComplete, .phaseActive:
                return
            default:
                break
            }
            
            // Determine current state from phase_state (only on initial load)
            if let phaseState = hunt.phase_state {
                if phaseState.is_resolved {
                    // Phase resolved - if there's a next phase, show its intro
                    if let next = nextPhase {
                        uiState = .phaseIntro(next)
                    } else {
                        uiState = .results
                    }
                } else if phaseState.rounds_completed > 0 {
                    // Already started rolling - active phase
                    uiState = .phaseActive(phaseState.huntPhase)
                } else {
                    // Fresh phase - show intro
                    uiState = .phaseIntro(phaseState.huntPhase)
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
        masterRollFinalValue = 0  // Reset for new phase
        shouldAnimateMasterRoll = false
        
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
    /// Immediately executes the roll - NO intermediate tap screen
    func userTappedResolve() async {
        guard let currentPhase = hunt?.phase_state?.huntPhase else { return }
        
        // Go straight to resolving and execute
        uiState = .resolving(currentPhase)
        await resolveCurrentPhase()
    }
    
    /// User taps "Continue" after master roll animation completes
    /// Goes directly to next phase or results - NO intermediate screens
    func userTappedNextAfterMasterRoll() async {
        guard let currentPhase = hunt?.phase_state?.huntPhase else { return }
        
        // If hunt is already completed (blessing auto-finalizes), go straight to results
        if hunt?.isComplete == true {
            currentPhaseResult = nil
            roundResults = []
            lastRollResult = nil
            uiState = .results
            return
        }
        
        // Check if we should show creature reveal (Track phase found animal)
        if currentPhase == .track,
           let result = currentPhaseResult,
           let effects = result.effects,
           effects["animal_found"]?.boolValue == true {
            uiState = .creatureReveal
        } else {
            // Skip PhaseCompleteOverlay - go directly to next phase or results
            currentPhaseResult = nil
            roundResults = []
            lastRollResult = nil
            await advanceToNextPhase()
        }
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
                
                // Stay in active phase state - user must manually tap resolve
                // DO NOT auto-trigger master roll - let user see their results first!
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
    
    /// Resolve/finalize the current phase (called after user taps roll button)
    private func resolveCurrentPhase() async {
        guard let huntId = hunt?.hunt_id,
              let currentPhase = hunt?.phase_state?.huntPhase else { return }
        
        do {
            let response = try await KingdomAPIService.shared.hunts.resolvePhase(huntId: huntId)
            
            if response.success {
                currentPhaseResult = response.phase_result
                hunt = response.hunt
                
                // ALL phases get master roll animation - user already tapped, now animate!
                if let effects = response.phase_result?.effects,
                   let rollValue = effects["master_roll"]?.intValue {
                    showMasterRollAnimation(value: rollValue, phase: currentPhase)
                }
                
                // Animation done - stay on this screen!
                // User must tap "Next" to proceed (no auto-transition BS)
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
    
    /// Trigger master roll animation - sets state and returns immediately
    private func showMasterRollAnimation(value: Int, phase: HuntPhase? = nil) {
        let targetPhase = phase ?? hunt?.phase_state?.huntPhase ?? .track
        uiState = .masterRollAnimation(targetPhase)
        masterRollFinalValue = value
        shouldAnimateMasterRoll = true
    }
    
    /// Called by HuntPhaseView when master roll animation completes
    func finishMasterRollAnimation() {
        shouldAnimateMasterRoll = false  // Animation is done
        
        // Get the phase from current state - works for both resolving and masterRollAnimation
        let phase: HuntPhase
        switch uiState {
        case .masterRollAnimation(let p), .resolving(let p):
            phase = p
        default:
            // Fallback to current hunt phase
            phase = hunt?.phase_state?.huntPhase ?? .track
        }
        
        uiState = .masterRollComplete(phase)
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
                // Creator is auto-ready, just start immediately
                await startHunt()
            } else {
                // If API returns existing hunt, use it so user can abandon/resume
                if let existingHunt = response.hunt {
                    hunt = existingHunt
                    syncUIState()
                } else {
                    error = response.message
                    showError = true
                    uiState = .noHunt
                }
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
        guard let huntId = hunt?.hunt_id else {
            uiState = .noHunt
            return
        }
        
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
                syncUIState()  // Reset to correct state on failure
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
            syncUIState()  // Reset to correct state on failure
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
        masterRollFinalValue = 0
        shouldAnimateMasterRoll = false
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
