import SwiftUI

// MARK: - War Actions (Coup & Invasion)

extension KingdomInfoSheetView {
    
    // MARK: - War Actions Section
    
    @ViewBuilder
    var warActionsSection: some View {
        if kingdom.canDeclareWar || kingdom.canStageCoup || kingdom.coupIneligibilityReason != nil {
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
                .padding(.horizontal)
            
            VStack(spacing: KingdomTheme.Spacing.small) {
                // Stage Coup button - only show if can stage or has reason
                coupButton
                
                // Declare Invasion button - only for rulers at enemy kingdoms
                invasionButton
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Coup Button
    
    @ViewBuilder
    private var coupButton: some View {
        if kingdom.canStageCoup {
            Button(action: {
                initiateCoup(kingdomId: kingdom.id)
            }) {
                HStack(spacing: 8) {
                    if isInitiatingCoup {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(.white)
                    }
                    Text(isInitiatingCoup ? "Starting Coup..." : "Stage Coup")
                        .font(FontStyles.bodyMediumBold)
                }
                .frame(maxWidth: .infinity)
                .padding(KingdomTheme.Spacing.medium)
                .foregroundColor(.white)
            }
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSpecial, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
            .disabled(isInitiatingCoup)
        } else if let reason = kingdom.coupIneligibilityReason {
            // Show disabled button with reason
            disabledCoupButton(reason: reason)
        }
    }
    
    // MARK: - Disabled Coup Button
    
    private func disabledCoupButton(reason: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("Stage Coup")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            Text(reason)
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(KingdomTheme.Spacing.medium)
        .background(KingdomTheme.Colors.parchmentMuted)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(KingdomTheme.Colors.inkLight, lineWidth: 2))
    }
    
    // MARK: - Invasion Button
    
    @ViewBuilder
    private var invasionButton: some View {
        if kingdom.canDeclareWar && kingdom.rulerId != nil && kingdom.rulerId != player.playerId {
            Button(action: {
                declareInvasion(kingdomId: kingdom.id)
            }) {
                HStack(spacing: 8) {
                    if isDeclaringInvasion {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "flag.2.crossed.fill")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(.white)
                    }
                    Text(isDeclaringInvasion ? "Declaring..." : "Declare Invasion")
                        .font(FontStyles.bodyMediumBold)
                }
                .frame(maxWidth: .infinity)
                .padding(KingdomTheme.Spacing.medium)
                .foregroundColor(.white)
            }
            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
            .disabled(isDeclaringInvasion)
        }
    }
    
    // MARK: - Battle Actions
    
    func initiateCoup(kingdomId: String) {
        isInitiatingCoup = true
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/battles/coup/initiate",
                    method: "POST",
                    body: ["kingdom_id": kingdomId]
                )
                let response: BattleInitiateResponse = try await APIClient.shared.execute(request)
                await MainActor.run {
                    initiatedBattleId = response.battleId
                    showBattleView = true
                    isInitiatingCoup = false
                }
            } catch {
                await MainActor.run {
                    battleError = error.localizedDescription
                    showBattleError = true
                    isInitiatingCoup = false
                }
            }
        }
    }
    
    func declareInvasion(kingdomId: String) {
        isDeclaringInvasion = true
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/battles/invasion/declare",
                    method: "POST",
                    body: ["target_kingdom_id": kingdomId]
                )
                let response: BattleInitiateResponse = try await APIClient.shared.execute(request)
                await MainActor.run {
                    initiatedBattleId = response.battleId
                    showBattleView = true
                    isDeclaringInvasion = false
                }
            } catch {
                await MainActor.run {
                    battleError = error.localizedDescription
                    showBattleError = true
                    isDeclaringInvasion = false
                }
            }
        }
    }
}
