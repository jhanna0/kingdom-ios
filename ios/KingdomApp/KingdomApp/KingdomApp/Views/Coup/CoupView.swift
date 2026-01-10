import SwiftUI
import Combine

/// Main container view for Coup V2
/// Full-screen game modal - no nav bar
struct CoupView: View {
    let coupId: Int
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = CoupViewModel()
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment.ignoresSafeArea()
            
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let coup = viewModel.coup {
                phaseContent(coup: coup)
            }
        }
        .onAppear {
            viewModel.loadCoup(id: coupId)
        }
    }
    
    // MARK: - Phase Content
    
    @ViewBuilder
    private func phaseContent(coup: CoupEventResponse) -> some View {
        switch coup.status {
        case "pledge":
            CoupPledgeView(coup: coup, onDismiss: onDismiss) { side in
                viewModel.pledge(side: side)
            }
        case "battle":
            battleView(coup: coup)
        case "resolved":
            resolvedView(coup: coup)
        default:
            Text("Unknown coup status")
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Battle View
    
    private func battleView(coup: CoupEventResponse) -> some View {
        let rulerName = coup.rulerName ?? "The Crown"
        let challengerStats = coup.initiatorStats.map { FighterStats(from: $0) } ?? .empty
        let rulerStats = coup.rulerStats.map { FighterStats(from: $0) } ?? .empty
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                CoupVsPosterView(
                    kingdomName: coup.kingdomName ?? "Kingdom",
                    challengerName: coup.initiatorName,
                    rulerName: rulerName,
                    attackerCount: coup.attackerCount,
                    defenderCount: coup.defenderCount,
                    timeRemaining: coup.timeRemainingFormatted,
                    status: coup.status,
                    userSide: coup.userSide,
                    challengerStats: challengerStats,
                    rulerStats: rulerStats,
                    onDismiss: onDismiss
                )
                
                // Battle status
                HStack(spacing: 12) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 12, shadowOffset: 2, borderWidth: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BATTLE IN PROGRESS")
                            .font(.system(size: 14, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Text("Wait for the outcome...")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            }
            .padding(.horizontal, KingdomTheme.Spacing.medium)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
    }
    
    // MARK: - Resolved View
    
    private func resolvedView(coup: CoupEventResponse) -> some View {
        let rulerName = coup.rulerName ?? "The Crown"
        let challengerStats = coup.initiatorStats.map { FighterStats(from: $0) } ?? .empty
        let rulerStats = coup.rulerStats.map { FighterStats(from: $0) } ?? .empty
        let attackerWon = coup.attackerVictory == true
        let userWon: Bool? = {
            guard let side = coup.userSide else { return nil }
            if side == "attackers" { return attackerWon }
            return !attackerWon
        }()
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                CoupVsPosterView(
                    kingdomName: coup.kingdomName ?? "Kingdom",
                    challengerName: coup.initiatorName,
                    rulerName: rulerName,
                    attackerCount: coup.attackerCount,
                    defenderCount: coup.defenderCount,
                    timeRemaining: "FINISHED",
                    status: coup.status,
                    userSide: coup.userSide,
                    challengerStats: challengerStats,
                    rulerStats: rulerStats,
                    onDismiss: onDismiss
                )
                
                // Result card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: attackerWon ? "crown.fill" : "shield.lefthalf.filled")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .brutalistBadge(
                                backgroundColor: attackerWon ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.royalBlue,
                                cornerRadius: 12,
                                shadowOffset: 2,
                                borderWidth: 2
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attackerWon ? "COUP SUCCEEDED" : "COUP FAILED")
                                .font(.system(size: 16, weight: .black, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Text(attackerWon ? "\(coup.initiatorName) seized the throne!" : "The crown defended its rule.")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        Spacer()
                    }
                    
                    if let won = userWon {
                        let tint = won ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger
                        HStack(spacing: 10) {
                            Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(tint)
                            
                            Text(won ? "Victory! You won." : "Defeat. You lost.")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                        }
                        .padding(12)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
                    }
                }
                .padding(16)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            }
            .padding(.horizontal, KingdomTheme.Spacing.medium)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
    }
    
    // MARK: - Loading & Error
    
    private var loadingView: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            ProgressView()
                .tint(KingdomTheme.Colors.loadingTint)
            Text("Loading...")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.error)
            
            Text("Error")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(error)
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                viewModel.loadCoup(id: coupId)
            }
            .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - ViewModel

@MainActor
class CoupViewModel: ObservableObject {
    @Published var coup: CoupEventResponse?
    @Published var isLoading = false
    @Published var error: String?
    
    private var coupId: Int?
    
    func loadCoup(id: Int) {
        self.coupId = id
        isLoading = true
        error = nil
        
        Task {
            do {
                let request = APIClient.shared.request(
                    endpoint: "/coups/\(id)",
                    method: "GET"
                )
                let response: CoupEventResponse = try await APIClient.shared.execute(request)
                self.coup = response
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func refresh() {
        guard let id = coupId else { return }
        loadCoup(id: id)
    }
    
    func pledge(side: String) {
        guard let id = coupId else { return }
        isLoading = true
        
        Task {
            do {
                let request = try APIClient.shared.request(
                    endpoint: "/coups/\(id)/join",
                    method: "POST",
                    body: ["side": side]
                )
                let _: CoupJoinResponse = try await APIClient.shared.execute(request)
                loadCoup(id: id)
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

#Preview {
    CoupView(coupId: 1, onDismiss: {})
}
