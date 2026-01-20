import SwiftUI

// MARK: - Alliance Actions

extension ActionsView {
    
    // MARK: - Propose Alliance (shows confirmation popup)
    
    func proposeAlliance(action: ActionStatus) {
        // Show confirmation popup before proposing
        pendingAllianceAction = action
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showAllianceConfirmation = true
        }
    }
    
    // MARK: - Execute Alliance Proposal (after confirmation)
    
    func executeAllianceProposal(action: ActionStatus) {
        guard let kingdomId = action.kingdomId ?? currentKingdom?.id else {
            errorMessage = "No kingdom selected"
            showError = true
            return
        }
        
        Task {
            do {
                let response = try await APIClient.shared.proposeAlliance(targetEmpireId: kingdomId)
                
                await MainActor.run {
                    // Show success popup
                    actionResultSuccess = response.success
                    actionResultTitle = response.success ? "Alliance Proposed!" : "Failed"
                    actionResultMessage = response.message
                    showActionResult = true
                    
                    // Refresh to update UI
                    Task {
                        await loadActionStatus(force: true)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Accept Alliance Request
    
    func acceptAllianceRequest(_ request: PendingAllianceRequest) {
        Task {
            do {
                let response = try await APIClient.shared.acceptAlliance(allianceId: request.id)
                
                await loadActionStatus(force: true)
                
                await MainActor.run {
                    actionResultSuccess = response.success
                    actionResultTitle = "Alliance Accepted!"
                    actionResultMessage = response.message
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showActionResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Decline Alliance Request
    
    func declineAllianceRequest(_ request: PendingAllianceRequest) {
        Task {
            do {
                let response = try await APIClient.shared.declineAlliance(allianceId: request.id)
                
                await loadActionStatus(force: true)
                
                await MainActor.run {
                    actionResultSuccess = response.success
                    actionResultTitle = "Alliance Declined"
                    actionResultMessage = response.message
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showActionResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
