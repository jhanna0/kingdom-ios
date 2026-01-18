import SwiftUI
import Combine

// MARK: - Foraging View Model
// Everything pre-calculated, frontend just reveals locally

@MainActor
class ForagingViewModel: ObservableObject {
    
    // MARK: - State
    
    enum UIState: Equatable {
        case loading
        case playing
        case won
        case lost
        case error(String)
    }
    
    @Published var uiState: UIState = .loading
    @Published var session: ForagingSession?
    
    // Local reveal state - NO API calls!
    // Key = grid position user tapped, Value = index in backend array
    @Published var revealedBushes: [Int: Int] = [:]  // position -> arrayIndex
    @Published var nextArrayIndex: Int = 0
    
    // API
    private var api: ForagingAPI?
    
    // MARK: - Computed
    
    var grid: [ForagingBushCell] { session?.grid ?? [] }
    var maxReveals: Int { session?.max_reveals ?? 5 }
    var matchesToWin: Int { session?.matches_to_win ?? 3 }
    var isWinner: Bool { session?.is_winner ?? false }
    var winningPositions: Set<Int> { Set(session?.winning_positions ?? []) }
    var rewardAmount: Int { session?.reward_amount ?? 0 }
    var hiddenIcon: String { session?.hidden_icon ?? "questionmark" }
    var hiddenColor: String { session?.hidden_color ?? "buttonSuccess" }
    var rewardConfig: ForagingRewardConfig? { session?.reward_config }
    
    var revealedCount: Int { revealedBushes.count }
    var canReveal: Bool { uiState == .playing && revealedCount < maxReveals }
    
    /// How many targets revealed - just count seeds in the revealed portion of array
    var revealedTargetCount: Int {
        (0..<nextArrayIndex).filter { i in
            i < grid.count && grid[i].is_seed
        }.count
    }
    
    var hasWon: Bool { revealedTargetCount >= matchesToWin }
    var isWarming: Bool { revealedTargetCount >= 1 && revealedTargetCount < matchesToWin }
    
    // MARK: - Init
    
    func configure(with client: APIClient) {
        self.api = ForagingAPI(client: client)
    }
    
    // MARK: - Actions
    
    func startSession() async {
        guard let api = api else { return }
        
        uiState = .loading
        revealedBushes = [:]
        nextArrayIndex = 0
        
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
        guard revealedBushes[position] == nil else { return }  // Already revealed
        
        // Assign next array item to this position
        revealedBushes[position] = nextArrayIndex
        nextArrayIndex += 1
        
        // Check for win
        if hasWon {
            uiState = .won
            return
        }
        
        // Check if out of reveals
        if revealedCount >= maxReveals {
            uiState = .lost
        }
    }
    
    func collect() async {
        guard let api = api else { return }
        
        do {
            _ = try await api.collectRewards()
            // Reset for next game
            session = nil
            revealedBushes = [:]
            nextArrayIndex = 0
            uiState = .loading
        } catch {
            uiState = .error(error.localizedDescription)
        }
    }
    
    func playAgain() async {
        guard let api = api else { return }
        
        // End current session
        _ = try? await api.endForaging()
        
        // Start fresh
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
    
    /// Get the array item revealed at this bush position
    func revealedCell(at position: Int) -> ForagingBushCell? {
        guard let arrayIndex = revealedBushes[position], arrayIndex < grid.count else { return nil }
        return grid[arrayIndex]
    }
}
