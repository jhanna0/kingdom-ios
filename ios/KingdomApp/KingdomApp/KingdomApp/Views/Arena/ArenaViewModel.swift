import Foundation
import SwiftUI
import Combine

/// ViewModel for the PvP Arena
@MainActor
class ArenaViewModel: ObservableObject {
    @Published var activeMatch: DuelMatch?
    @Published var invitations: [DuelInvitation] = []
    @Published var myStats: DuelStats?
    @Published var leaderboard: [DuelLeaderboardEntry] = []
    @Published var recentMatches: [DuelMatch] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = DuelsAPI()
    private var cancellables = Set<AnyCancellable>()
    private var currentKingdomId: String?
    
    init() {
        subscribeToEvents()
    }
    
    // MARK: - WebSocket Events
    
    /// Subscribe to duel events for real-time updates
    private func subscribeToEvents() {
        GameEventManager.shared.duelEventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDuelEvent(event)
            }
            .store(in: &cancellables)
    }
    
    /// Handle incoming duel events
    private func handleDuelEvent(_ event: DuelEvent) {
        switch event.eventType {
        case .invitation:
            // New challenge received - refresh invitations
            Task { await loadInvitations() }
            
        case .opponentJoined:
            // Our challenge was accepted - update active match
            if let match = event.match {
                activeMatch = match
            }
            
        case .cancelled:
            // Match was cancelled
            if event.matchId == activeMatch?.id {
                activeMatch = nil
            }
            // Also refresh invitations in case it was an incoming invite
            Task { await loadInvitations() }
            
        case .ended, .timeout:
            // Match ended - clear active match and refresh stats
            if event.matchId == activeMatch?.id {
                activeMatch = nil
            }
            Task {
                await loadMyStats()
                if let kingdomId = currentKingdomId {
                    await loadRecentMatches(kingdomId: kingdomId)
                }
            }
            
        case .started, .swing, .turnComplete:
            // Combat events - update active match if it's ours
            if event.matchId == activeMatch?.id, let match = event.match {
                activeMatch = match
            }
        }
    }
    
    // MARK: - Loading
    
    func load(kingdomId: String) async {
        isLoading = true
        defer { isLoading = false }
        currentKingdomId = kingdomId
        
        await refresh(kingdomId: kingdomId)
    }
    
    func refresh(kingdomId: String) async {
        // Load all data in parallel
        async let activeTask: () = loadActiveMatch()
        async let invitationsTask: () = loadInvitations()
        async let statsTask: () = loadMyStats()
        async let leaderboardTask: () = loadLeaderboard()
        async let recentTask: () = loadRecentMatches(kingdomId: kingdomId)
        
        _ = await (activeTask, invitationsTask, statsTask, leaderboardTask, recentTask)
    }
    
    private func loadActiveMatch() async {
        do {
            let response = try await api.getActiveMatch()
            activeMatch = response.match
        } catch {
            print("Failed to load active match: \(error)")
        }
    }
    
    private func loadInvitations() async {
        do {
            let response = try await api.getInvitations()
            invitations = response.invitations
        } catch {
            print("Failed to load invitations: \(error)")
        }
    }
    
    private func loadMyStats() async {
        do {
            let response = try await api.getMyStats()
            myStats = response.stats
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
    
    private func loadLeaderboard() async {
        do {
            let response = try await api.getLeaderboard(limit: 10)
            leaderboard = response.leaderboard
        } catch {
            print("Failed to load leaderboard: \(error)")
        }
    }
    
    private func loadRecentMatches(kingdomId: String) async {
        do {
            let response = try await api.getRecentMatches(kingdomId: kingdomId, limit: 10)
            recentMatches = response.matches
        } catch {
            print("Failed to load recent matches: \(error)")
        }
    }
    
    // MARK: - Actions
    
    /// Challenge a friend to a duel
    func createDuel(kingdomId: String, opponentId: Int, wagerGold: Int = 0) async -> DuelMatch? {
        errorMessage = nil
        do {
            let response = try await api.createDuel(kingdomId: kingdomId, opponentId: opponentId, wagerGold: wagerGold)
            if response.success, let match = response.match {
                activeMatch = match
                return match
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to send challenge: \(error.localizedDescription)"
        }
        return nil
    }
    
    /// Accept a duel challenge
    func acceptInvitation(_ invitationId: Int, playerId: Int) async {
        errorMessage = nil
        do {
            let response = try await api.acceptInvitation(invitationId: invitationId)
            if response.success, let match = response.match {
                activeMatch = match
                invitations.removeAll { $0.invitationId == invitationId }
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to accept: \(error.localizedDescription)"
        }
    }
    
    /// Decline a duel challenge
    func declineInvitation(_ invitationId: Int) async {
        errorMessage = nil
        do {
            _ = try await api.declineInvitation(invitationId: invitationId)
            invitations.removeAll { $0.invitationId == invitationId }
        } catch {
            errorMessage = "Failed to decline: \(error.localizedDescription)"
        }
    }
    
    /// Cancel a pending match (challenger only)
    func cancelMatch(matchId: Int) async {
        errorMessage = nil
        do {
            let response = try await api.cancel(matchId: matchId)
            if response.success {
                activeMatch = nil
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to cancel: \(error.localizedDescription)"
        }
    }
}
