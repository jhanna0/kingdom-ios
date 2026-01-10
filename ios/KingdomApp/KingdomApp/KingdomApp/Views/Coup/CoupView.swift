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
            battlePlaceholder(coup: coup)
        case "resolved":
            resolvedView(coup: coup)
        default:
            Text("Unknown coup status")
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Battle Placeholder
    
    private func battlePlaceholder(coup: CoupEventResponse) -> some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            Image(systemName: "sword.fill")
                .font(.system(size: 60))
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
            
            Text("Battle Phase")
                .font(KingdomTheme.Typography.title())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("The battle is underway!")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Timer
            VStack(spacing: 4) {
                Text("Time Remaining")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                
                Text(coup.timeRemainingFormatted)
                    .font(KingdomTheme.Typography.title2())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            
            // Placeholder message
            Text("Battle mechanics coming soon...")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
                .italic()
                .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Resolved View
    
    private func resolvedView(coup: CoupEventResponse) -> some View {
        VStack(spacing: KingdomTheme.Spacing.large) {
            // Result icon
            Image(systemName: coup.attackerVictory == true ? "crown.fill" : "shield.fill")
                .font(.system(size: 60))
                .foregroundColor(coup.attackerVictory == true ? KingdomTheme.Colors.imperialGold : KingdomTheme.Colors.royalBlue)
            
            // Result text
            Text(coup.attackerVictory == true ? "Coup Succeeded!" : "Coup Failed!")
                .font(KingdomTheme.Typography.title())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if coup.attackerVictory == true {
                Text("\(coup.initiatorName) has seized the throne!")
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            } else {
                Text("The crown has defended its rule.")
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            
            // User result
            if let userSide = coup.userSide {
                let userWon = (userSide == "attackers" && coup.attackerVictory == true) ||
                              (userSide == "defenders" && coup.attackerVictory == false)
                
                HStack {
                    Image(systemName: userWon ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(userWon ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                    Text(userWon ? "Victory! You were on the winning side." : "Defeat. You were on the losing side.")
                        .font(KingdomTheme.Typography.subheadline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding()
                .brutalistCard(backgroundColor: userWon ? KingdomTheme.Colors.buttonSuccess.opacity(0.1) : KingdomTheme.Colors.buttonDanger.opacity(0.1))
            }
            
            // Final counts
            HStack(spacing: KingdomTheme.Spacing.xxLarge) {
                VStack {
                    Text("\(coup.attackerCount)")
                        .font(KingdomTheme.Typography.title())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("Attackers")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                VStack {
                    Text("\(coup.defenderCount)")
                        .font(KingdomTheme.Typography.title())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.royalBlue)
                    Text("Defenders")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
        .padding()
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
