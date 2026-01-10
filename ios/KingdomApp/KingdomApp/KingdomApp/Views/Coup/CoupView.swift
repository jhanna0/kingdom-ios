import SwiftUI
import Combine

/// Main container view for Coup V2
/// Displays appropriate phase view based on coup status
struct CoupView: View {
    let coupId: Int
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = CoupViewModel()
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Coup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                    .buttonStyle(.toolbar)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.toolbar)
                }
            }
            .parchmentNavigationBar()
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
            CoupPledgeView(coup: coup) { side in
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
        let rulerName = coup.defenders.first?.playerName ?? "Current Ruler"
        let challengerStats = coup.initiatorStats.map { FighterStats(from: $0) } ?? .empty
        let rulerStats = coup.defenders.first.map { FighterStats(from: $0) } ?? .empty
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // VS Poster with stats
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
                    rulerStats: rulerStats
                )
                
                // Battle status card
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        
                        Text("BATTLE IN PROGRESS")
                            .font(.system(size: 14, weight: .black, design: .serif))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                    }
                    
                    Text("The battle is underway! Wait for the outcome...")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(KingdomTheme.Colors.buttonDanger.opacity(0.1))
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(KingdomTheme.Colors.buttonDanger, lineWidth: 2)
                    }
                )
            }
            .padding(.horizontal, KingdomTheme.Spacing.medium)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
    }
    
    // MARK: - Resolved View
    
    private func resolvedView(coup: CoupEventResponse) -> some View {
        let rulerName = coup.defenders.first?.playerName ?? "Current Ruler"
        let challengerStats = coup.initiatorStats.map { FighterStats(from: $0) } ?? .empty
        let rulerStats = coup.defenders.first.map { FighterStats(from: $0) } ?? .empty
        let attackerWon = coup.attackerVictory == true
        let userWon: Bool? = {
            guard let side = coup.userSide else { return nil }
            if side == "attackers" { return attackerWon }
            return !attackerWon
        }()
        
        return ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // VS Poster with stats (shows final state)
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
                    rulerStats: rulerStats
                )
                
                // Result card
                VStack(spacing: 16) {
                    // Victory/defeat indicator
                    HStack(spacing: 12) {
                        Image(systemName: attackerWon ? "crown.fill" : "shield.lefthalf.filled")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(attackerWon ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.royalBlue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attackerWon ? "COUP SUCCEEDED" : "COUP FAILED")
                                .font(.system(size: 14, weight: .black, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text(attackerWon ? "\(coup.initiatorName) seized the throne!" : "The crown defended its rule.")
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
                        Spacer()
                    }
                    
                    // User result (if participated)
                    if let won = userWon {
                        HStack(spacing: 10) {
                            Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(won ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                            
                            Text(won ? "Victory! You were on the winning side." : "Defeat. You were on the losing side.")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(won ? KingdomTheme.Colors.buttonSuccess.opacity(0.1) : KingdomTheme.Colors.buttonDanger.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(won ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger, lineWidth: 2)
                        )
                    }
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(KingdomTheme.Colors.parchmentLight)
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black, lineWidth: 2)
                    }
                )
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
            Text("Loading coup details...")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
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
                // Refresh to get updated state
                loadCoup(id: id)
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CoupView(coupId: 1, onDismiss: {})
}
