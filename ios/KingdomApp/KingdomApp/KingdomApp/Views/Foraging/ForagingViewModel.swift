import SwiftUI
import Combine

// MARK: - Foraging View Model
// Two-round system with bonus round!
// Everything pre-calculated, frontend just reveals + animates transitions

@MainActor
class ForagingViewModel: ObservableObject {
    
    // MARK: - State
    
    enum UIState: Equatable {
        case loading
        case playing           // Normal play in current round
        case won               // Won current round
        case lost              // Lost current round
        case seedTrailFound    // Found seed trail! About to transition
        case transitioning     // Animating to bonus round
        case bonusRound        // Playing bonus round
        case bonusWon          // Won bonus round
        case bonusLost         // Lost bonus round
        case error(String)
    }
    
    @Published var uiState: UIState = .loading
    @Published var session: ForagingSession?
    
    // Current round tracking
    @Published var currentRound: Int = 1
    
    // Local reveal state - NO API calls!
    @Published var revealedBushes: [Int: Int] = [:]  // position -> arrayIndex
    @Published var nextArrayIndex: Int = 0
    
    // Seed trail discovery
    @Published var foundSeedTrail: Bool = false
    
    // API
    private var api: ForagingAPI?
    
    // MARK: - Computed (current round)
    
    var currentRoundData: ForagingRoundData? {
        guard let session = session else { return nil }
        return currentRound == 1 ? session.round1 : session.round2
    }
    
    var grid: [ForagingBushCell] { currentRoundData?.grid ?? [] }
    var maxReveals: Int { currentRoundData?.max_reveals ?? 5 }
    var matchesToWin: Int { currentRoundData?.matches_to_win ?? 3 }
    var hiddenIcon: String { currentRoundData?.hidden_icon ?? "questionmark" }
    var hiddenColor: String { currentRoundData?.hidden_color ?? "buttonSuccess" }
    var rewardConfig: ForagingRewardConfig? { currentRoundData?.reward_config }
    
    var revealedCount: Int { revealedBushes.count }
    var canReveal: Bool { 
        (uiState == .playing || uiState == .bonusRound) && revealedCount < maxReveals 
    }
    
    /// How many targets revealed in current round
    var revealedTargetCount: Int {
        (0..<nextArrayIndex).filter { i in
            i < grid.count && grid[i].is_seed
        }.count
    }
    
    /// Did we reveal the seed trail?
    var revealedSeedTrail: Bool {
        guard currentRound == 1 else { return false }
        return (0..<nextArrayIndex).contains { i in
            i < grid.count && grid[i].isSeedTrail
        }
    }
    
    var hasWon: Bool { revealedTargetCount >= matchesToWin }
    var isWarming: Bool { revealedTargetCount >= 1 }
    var hasBonusRound: Bool { session?.has_bonus_round ?? false }
    var isBonusRound: Bool { currentRound == 2 }
    
    // Combined rewards for display - backend determines what's winnable
    var allRewards: [(round: Int, config: ForagingRewardConfig, amount: Int)] {
        var rewards: [(Int, ForagingRewardConfig, Int)] = []
        
        if let r1 = session?.round1, r1.is_winner {
            rewards.append((1, r1.reward_config, r1.reward_amount))
        }
        if let r2 = session?.round2, r2.is_winner {
            rewards.append((2, r2.reward_config, r2.reward_amount))
        }
        
        return rewards
    }
    
    // MARK: - Init
    
    func configure(with client: APIClient) {
        self.api = ForagingAPI(client: client)
    }
    
    // MARK: - Actions
    
    func startSession() async {
        guard let api = api else { return }
        
        uiState = .loading
        currentRound = 1
        revealedBushes = [:]
        nextArrayIndex = 0
        foundSeedTrail = false
        session = nil
        
        do {
            let response = try await api.startForaging()
            session = response.session
            uiState = .playing
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    func reveal(position: Int) {
        guard canReveal else { return }
        guard revealedBushes[position] == nil else { return }
        
        // Assign next array item to this position
        revealedBushes[position] = nextArrayIndex
        let revealedIndex = nextArrayIndex
        nextArrayIndex += 1
        
        // Check what we revealed
        if revealedIndex < grid.count {
            let cell = grid[revealedIndex]
            
            // Check for seed trail (Round 1 only)
            if currentRound == 1 && cell.isSeedTrail && hasBonusRound {
                foundSeedTrail = true
                // Don't immediately transition - let player see the trail
                // View will show transition prompt after a moment
            }
        }
        
        // Check for win (matching targets)
        if hasWon {
            uiState = isBonusRound ? .bonusWon : .won
            return
        }
        
        // Check if out of reveals
        if revealedCount >= maxReveals {
            // If we found seed trail but didn't win berries, still trigger bonus
            if currentRound == 1 && foundSeedTrail {
                uiState = .seedTrailFound
            } else {
                uiState = isBonusRound ? .bonusLost : .lost
            }
        }
    }
    
    /// Called when user taps "Follow Trail" to start bonus round
    func startBonusRound() {
        guard hasBonusRound, session?.round2 != nil else { return }
        
        uiState = .transitioning
        
        // After animation delay, switch to bonus round
        // The view handles the actual timing
    }
    
    /// Called by view after transition animation completes
    func enterBonusRound() {
        currentRound = 2
        revealedBushes = [:]
        nextArrayIndex = 0
        uiState = .bonusRound
    }
    
    func collect() async {
        guard let api = api else { return }
        
        do {
            _ = try await api.collectRewards()
            // Reset for next game
            session = nil
            currentRound = 1
            revealedBushes = [:]
            nextArrayIndex = 0
            foundSeedTrail = false
            uiState = .loading
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    func playAgain() async {
        guard let api = api else { return }
        
        _ = try? await api.endForaging()
        await startSession()
    }
    
    func endSession() async {
        guard let api = api else { return }
        _ = try? await api.endForaging()
        session = nil
    }
    
    // MARK: - Display Helpers
    
    func isRevealed(_ position: Int) -> Bool {
        revealedBushes[position] != nil
    }
    
    func revealedCell(at position: Int) -> ForagingBushCell? {
        guard let arrayIndex = revealedBushes[position], arrayIndex < grid.count else { return nil }
        return grid[arrayIndex]
    }
}
