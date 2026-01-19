import SwiftUI
import Combine

// MARK: - Science View Model
// High/Low guessing game - test your scientific intuition!
// Backend PRE-CALCULATES all answers. We just send guesses!

@MainActor
class ScienceViewModel: ObservableObject {
    
    // MARK: - State
    
    enum UIState: Equatable {
        case loading
        case ready           // Waiting for first guess
        case guessing        // Processing a guess
        case correct         // Just got it right!
        case wrong           // Just got it wrong
        case wonMax          // Got all 3 right - EUREKA!
        case collecting      // Collecting rewards
        case collected       // Rewards collected successfully
        case error(String)
    }
    
    @Published var uiState: UIState = .loading
    @Published var session: ScienceSession?
    @Published var skillInfo: ScienceSkillInfo?
    @Published var stats: SciencePlayerStats?
    @Published var collectResponse: ScienceCollectResponse?
    @Published var entryCost: Int = 10  // Default, updated from backend
    
    // Last guess result (for animation)
    @Published var lastGuessResult: ScienceGuessResponse?
    
    // API
    private var api: ScienceAPI?
    
    // MARK: - Computed
    
    var currentNumber: Int { session?.current_number ?? 5 }
    var streak: Int { session?.streak ?? 0 }
    var maxStreak: Int { session?.max_streak ?? 3 }
    var canGuess: Bool { session?.can_guess ?? false }
    var canCollect: Bool { session?.can_collect ?? false }
    var isGameOver: Bool { session?.is_game_over ?? false }
    var hasWonMax: Bool { session?.has_won_max ?? false }
    
    var potentialRewards: SciencePotentialRewards? { session?.potential_rewards }
    var potentialGold: Int { potentialRewards?.gold ?? 0 }
    var potentialBlueprint: Int { potentialRewards?.blueprint ?? 0 }
    
    var playedRounds: [ScienceRound] { session?.rounds ?? [] }
    
    var minNumber: Int { session?.min_number ?? 1 }
    var maxNumber: Int { session?.max_number ?? 100 }
    
    // MARK: - Init
    
    func configure(with client: APIClient) {
        self.api = ScienceAPI(client: client)
    }
    
    // MARK: - Actions
    
    func startExperiment() async {
        guard let api = api else { return }
        
        uiState = .loading
        lastGuessResult = nil
        collectResponse = nil
        
        do {
            let response = try await api.startExperiment()
            session = response.session
            skillInfo = response.skill_info
            entryCost = response.cost ?? 10
            uiState = .ready
            
            // Non-blocking: stats are nice-to-have in the bottom bar.
            Task { [weak self] in
                guard let self else { return }
                await self.loadStats()
            }
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    func guess(_ direction: String) async {
        guard let api = api, canGuess else { return }
        
        uiState = .guessing
        
        do {
            let response = try await api.makeGuess(direction)
            lastGuessResult = response
            session = response.session
            
            // Determine UI state based on result
            if response.is_correct {
                if response.has_won_max {
                    uiState = .wonMax
                } else {
                    uiState = .correct
                    // Stay in .correct state - user must tap NEXT to continue
                }
            } else {
                uiState = .wrong
            }
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    func guessHigh() async {
        await guess("high")
    }
    
    func guessLow() async {
        await guess("low")
    }
    
    func collect() async {
        guard let api = api else { return }
        
        uiState = .collecting
        
        do {
            let response = try await api.collectRewards()
            stats = response.stats
            collectResponse = response
            uiState = .collected
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    func continueToNextTrial() {
        // Clear last result and go back to ready for next guess
        lastGuessResult = nil
        uiState = .ready
    }
    
    func playAgain() async {
        await startExperiment()
    }
    
    func endExperiment() async {
        guard let api = api else { return }
        _ = try? await api.endExperiment()
        session = nil
    }
    
    func loadStats() async {
        guard let api = api else { return }
        stats = try? await api.getStats()
    }
}
