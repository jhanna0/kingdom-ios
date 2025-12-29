import SwiftUI

struct ActionsView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var actionStatus: AllActionStatus?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var refreshTimer: Timer?
    
    var currentKingdom: Kingdom? {
        guard let currentKingdomName = viewModel.player.currentKingdom else { return nil }
        return viewModel.kingdoms.first { $0.name == currentKingdomName }
    }
    
    var activeContract: Contract? {
        guard let contractId = viewModel.player.activeContractId else { return nil }
        return viewModel.availableContracts.first { $0.id == contractId }
    }
    
    var isInHomeKingdom: Bool {
        guard let kingdom = currentKingdom else { return false }
        return viewModel.isHomeKingdom(kingdom)
    }
    
    var isInEnemyKingdom: Bool {
        guard let kingdom = currentKingdom else { return false }
        return !viewModel.isHomeKingdom(kingdom)
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            if isLoading && actionStatus == nil {
                MedievalLoadingView(status: "Loading actions...")
            } else {
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Header
                        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                            Text("Available Actions")
                                .font(KingdomTheme.Typography.title2())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            if let kingdom = currentKingdom {
                                HStack(spacing: 8) {
                                    Text("In \(kingdom.name)")
                                        .font(KingdomTheme.Typography.body())
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    
                                    // Show context badge
                                    if isInHomeKingdom {
                                        Text("🏠 HOME")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(KingdomTheme.Colors.buttonSuccess)
                                            .cornerRadius(4)
                                    } else {
                                        Text("⚔️ ENEMY")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.red)
                                            .cornerRadius(4)
                                    }
                                }
                            } else {
                                Text("Enter a kingdom to perform actions")
                                    .font(KingdomTheme.Typography.body())
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Actions List
                        if let status = actionStatus {
                            if isInHomeKingdom {
                                // === BENEFICIAL ACTIONS (Home Kingdom) ===
                                
                                Text("🏠 Beneficial Actions")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, KingdomTheme.Spacing.small)
                                
                                // Work on Contract
                                if let contract = activeContract {
                                    ActionCard(
                                        title: "Work on Contract",
                                        icon: "hammer.fill",
                                        description: "Contribute to \(contract.buildingType) construction",
                                        status: status.work,
                                        actionType: .work,
                                        isEnabled: true,
                                        onAction: { performWork() }
                                    )
                                } else {
                                    InfoCard(
                                        title: "No Active Contract",
                                        icon: "hammer.fill",
                                        description: "Join a contract to start working",
                                        color: .gray
                                    )
                                }
                                
                                // Patrol
                                ActionCard(
                                    title: "Patrol",
                                    icon: "eye.fill",
                                    description: "Guard against saboteurs for 10 minutes",
                                    status: status.patrol,
                                    actionType: .patrol,
                                    isEnabled: true,
                                    onAction: { performPatrol() }
                                )
                                
                                // Mine Resources
                                ActionCard(
                                    title: "Mine Resources",
                                    icon: "pickaxe",
                                    description: "Collect iron from the kingdom mine",
                                    status: status.mine,
                                    actionType: .mine,
                                    isEnabled: true,
                                    onAction: { performMine() }
                                )
                                
                            } else if isInEnemyKingdom {
                                // === MALICIOUS ACTIONS (Enemy Kingdom) ===
                                
                                Text("⚔️ Hostile Actions")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, KingdomTheme.Spacing.small)
                                
                                // Scout
                                ActionCard(
                                    title: "Scout Kingdom",
                                    icon: "magnifyingglass",
                                    description: "Gather intelligence on this enemy kingdom",
                                    status: status.scout,
                                    actionType: .scout,
                                    isEnabled: true,
                                    onAction: { performScout() }
                                )
                                
                                // Sabotage (coming soon)
                                ActionCard(
                                    title: "Sabotage (Coming Soon)",
                                    icon: "flame.fill",
                                    description: "Damage enemy buildings and infrastructure",
                                    status: status.sabotage,
                                    actionType: .sabotage,
                                    isEnabled: false,
                                    onAction: { /* Not implemented yet */ }
                                )
                            } else {
                                // Not in any kingdom
                                InfoCard(
                                    title: "Enter a Kingdom",
                                    icon: "location.fill",
                                    description: "Move to a kingdom to perform actions",
                                    color: .orange
                                )
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadActionStatus()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay(alignment: .top) {
            if showSuccess {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(successMessage)
                            .foregroundColor(.white)
                            .font(KingdomTheme.Typography.body())
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSuccess = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func isHomeKingdom(_ kingdom: Kingdom) -> Bool {
        return kingdom.rulerId == viewModel.player.playerId
    }
    
    // MARK: - API Calls
    
    private func loadActionStatus() async {
        isLoading = true
        do {
            actionStatus = try await KingdomAPIService.shared.actions.getActionStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func performWork() {
        guard let contractId = activeContract?.id else { return }
        
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.workOnContract(contractId: contractId)
                await MainActor.run {
                    successMessage = response.message
                    showSuccess = true
                }
                await loadActionStatus()
                await viewModel.loadContracts()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performPatrol() {
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.startPatrol()
                await MainActor.run {
                    successMessage = response.message
                    showSuccess = true
                }
                await loadActionStatus()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performMine() {
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.mineResources()
                await MainActor.run {
                    successMessage = response.message
                    showSuccess = true
                }
                await loadActionStatus()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func performScout() {
        guard let kingdomId = currentKingdom?.id else { return }
        
        Task {
            do {
                let response = try await KingdomAPIService.shared.actions.scoutKingdom(kingdomId: kingdomId)
                await MainActor.run {
                    successMessage = response.message
                    showSuccess = true
                }
                await loadActionStatus()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Timer
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                await loadActionStatus()
            }
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Action Card

enum ActionType {
    case work, patrol, mine, scout, sabotage
}

struct ActionCard: View {
    let title: String
    let icon: String
    let description: String
    let status: ActionStatus
    let actionType: ActionType
    let isEnabled: Bool
    let onAction: () -> Void
    
    @State private var timeRemaining: TimeInterval = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(description)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
            
            if status.ready && isEnabled {
                Button(action: onAction) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Perform Action")
                    }
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
            } else if !isEnabled {
                Text("Check in to a kingdom first")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            } else {
                CooldownTimer(secondsRemaining: status.secondsRemaining)
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
    
    private var iconColor: Color {
        if status.ready && isEnabled {
            return KingdomTheme.Colors.gold
        } else {
            return .gray
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let icon: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(description)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
}

// MARK: - Cooldown Timer

struct CooldownTimer: View {
    let secondsRemaining: Int
    
    var formattedTime: String {
        let hours = secondsRemaining / 3600
        let minutes = (secondsRemaining % 3600) / 60
        let seconds = secondsRemaining % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.gray)
            
            Text("Available in \(formattedTime)")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        ActionsView(viewModel: MapViewModel())
    }
}

