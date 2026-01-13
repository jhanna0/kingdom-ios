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
    
    // MARK: - Loading
    
    func load(kingdomId: String) async {
        isLoading = true
        defer { isLoading = false }
        
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
    
    func createDuel(kingdomId: String, wagerGold: Int = 0) async -> DuelMatch? {
        do {
            let response = try await api.createDuel(kingdomId: kingdomId, wagerGold: wagerGold)
            if response.success, let match = response.match {
                activeMatch = match
                return match
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to create duel: \(error.localizedDescription)"
        }
        return nil
    }
    
    func joinByCode(_ code: String, playerId: Int) async -> DuelMatch? {
        do {
            let response = try await api.joinByCode(code)
            if response.success, let match = response.match {
                activeMatch = match
                return match
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to join: \(error.localizedDescription)"
        }
        return nil
    }
    
    func acceptInvitation(_ invitationId: Int, playerId: Int) async {
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
    
    func declineInvitation(_ invitationId: Int) async {
        do {
            _ = try await api.declineInvitation(invitationId: invitationId)
            invitations.removeAll { $0.invitationId == invitationId }
        } catch {
            errorMessage = "Failed to decline: \(error.localizedDescription)"
        }
    }
    
    func inviteFriend(matchId: Int, friendUserId: Int) async -> Bool {
        do {
            let response = try await api.inviteFriend(matchId: matchId, friendUserId: friendUserId)
            return response.success
        } catch {
            errorMessage = "Failed to invite: \(error.localizedDescription)"
            return false
        }
    }
    
    func cancelMatch(matchId: Int) async {
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
