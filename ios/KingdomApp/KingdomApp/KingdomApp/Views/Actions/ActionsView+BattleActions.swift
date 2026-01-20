import SwiftUI

// MARK: - Battle Actions

extension ActionsView {
    
    // MARK: - Open Existing Battle
    
    func openBattle(battleId: Int?) {
        guard let id = battleId else {
            errorMessage = "Battle not found"
            showError = true
            return
        }
        initiatedBattleId = id
        showBattleView = true
    }
    
    // MARK: - Initiate Battle (with confirmation)
    
    /// Show confirmation before initiating a battle (coup or invasion)
    func initiateBattle(action: ActionStatus) {
        pendingBattleAction = action
        showBattleConfirmation = true
    }
    
    /// Actually execute the battle initiation after confirmation
    func executeBattleInitiation(action: ActionStatus) {
        guard let endpoint = action.endpoint else {
            errorMessage = "No endpoint provided"
            showError = true
            return
        }
        
        guard let kingdomId = action.kingdomId ?? currentKingdom?.id else {
            errorMessage = "No kingdom selected"
            showError = true
            return
        }
        
        isInitiatingBattle = true
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: endpoint,
                    method: "POST",
                    body: ["target_kingdom_id": kingdomId]
                )
                let response: BattleInitiateResponse = try await APIClient.shared.execute(request)
                
                await MainActor.run {
                    initiatedBattleId = response.battleId
                    showBattleView = true
                    isInitiatingBattle = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isInitiatingBattle = false
                }
            }
        }
    }
}
