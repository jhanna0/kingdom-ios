import SwiftUI

// MARK: - Contracts List View
// Browse and contribute to kingdom contracts

struct ContractsListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MapViewModel
    
    var availableContracts: [Contract] {
        viewModel.availableContracts
    }
    
    var playerActiveContract: Contract? {
        viewModel.getPlayerActiveContract()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        // Player's active contract (if any)
                        if let activeContract = playerActiveContract {
                            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                                Text("Your Active Contract")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                    .padding(.horizontal)
                                
                                NavigationLink(value: activeContract) {
                                    ContractCard(contract: activeContract, isPlayerWorking: true)
                                }
                            }
                        }
                        
                        // All available contracts
                        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                            Text(playerActiveContract != nil ? "Other Contracts" : "Available Contracts")
                                .font(KingdomTheme.Typography.headline())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .padding(.horizontal)
                            
                            if availableContracts.isEmpty {
                                VStack(spacing: KingdomTheme.Spacing.medium) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 40))
                                        .foregroundColor(KingdomTheme.Colors.inkLight)
                                    
                                    Text("No contracts available")
                                        .font(KingdomTheme.Typography.body())
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    
                                    Text("Rulers can create contracts for building upgrades")
                                        .font(KingdomTheme.Typography.caption())
                                        .foregroundColor(KingdomTheme.Colors.inkLight)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.xxLarge)
                            } else {
                                ForEach(availableContracts) { contract in
                                NavigationLink(value: contract) {
                                    ContractCard(
                                        contract: contract,
                                        isPlayerWorking: contract.workers.contains(viewModel.player.playerId)
                                    )
                                }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Contracts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationDestination(for: Contract.self) { contract in
                ContractDetailView(contract: contract, viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
        }
        .task {
            // Load contracts from API when view appears
            await viewModel.loadContracts()
        }
    }
}

// MARK: - Contract Detail View
// View and contribute to a specific contract

struct ContractDetailView: View {
    let contract: Contract
    @ObservedObject var viewModel: MapViewModel
    @State private var workToContribute: String = ""
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    
    var isPlayerWorking: Bool {
        contract.workers.contains(viewModel.player.playerId)
    }
    
    var canAccept: Bool {
        !isPlayerWorking && 
        !contract.isComplete && 
        viewModel.player.activeContractId == nil
        // Removed ruler check - dev mode allows it
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.large) {
                buildingInfoSection
                progressSection
                rewardsSection
                timeEstimateSection
                workersListSection
                actionButtonsSection
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationTitle(contract.buildingType)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
    }
    
    // MARK: - View Components
    
    private var buildingInfoSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            Text(contract.kingdomName)
                .font(KingdomTheme.Typography.title2())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("\(contract.buildingType) - Level \(contract.buildingLevel)")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(KingdomTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Progress")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            progressStatusText
            progressBar
        }
        .padding(KingdomTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard()
    }
    
    private var progressStatusText: some View {
        HStack {
            if let remaining = contract.hoursRemaining {
                Text(formatTime(remaining))
                    .font(KingdomTheme.Typography.title3())
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("remaining")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else if contract.status == .open {
                Text("Waiting for workers")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else {
                Text("Complete")
                    .font(KingdomTheme.Typography.title3())
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(KingdomTheme.Colors.parchmentDark)
                    .frame(height: 12)
                
                Rectangle()
                    .fill(KingdomTheme.Colors.gold)
                    .frame(width: geometry.size.width * contract.progress, height: 12)
            }
            .cornerRadius(6)
        }
        .frame(height: 12)
    }
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Rewards")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(KingdomTheme.Colors.goldLight)
                
                Text("\(contract.rewardPool)g total pool")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            rewardsDescription
        }
        .padding(KingdomTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard()
    }
    
    private var rewardsDescription: some View {
        Group {
            if contract.workerCount > 0 {
                Text("Currently \(contract.rewardPerWorker)g per worker (\(contract.workerCount) workers)")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            } else {
                Text("Split equally among all workers when complete")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
    }
    
    private var timeEstimateSection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            Text("Time Estimate")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                
                VStack(alignment: .leading, spacing: 4) {
                    timeEstimateText
                    
                    Text("More workers = faster completion")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
        }
        .padding(KingdomTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard()
    }
    
    private var timeEstimateText: some View {
        Group {
            if contract.workerCount > 0 {
                Text("~\(formatTime(contract.hoursToComplete)) with \(contract.workerCount) workers")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            } else {
                Text("~\(formatTime(contract.baseHoursRequired)) with 3 workers")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
        }
    }
    
    @ViewBuilder
    private var workersListSection: some View {
        if !contract.workers.isEmpty {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                Text("Workers (\(contract.workerCount))")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                ForEach(Array(contract.workers.sorted()), id: \.self) { workerId in
                    workerRow(workerId: workerId)
                    
                    if workerId != contract.workers.sorted().last {
                        Divider()
                            .background(KingdomTheme.Colors.divider)
                    }
                }
            }
            .padding(KingdomTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentCard()
        }
    }
    
    private func workerRow(workerId: Int) -> some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(workerId == viewModel.player.playerId ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkLight)
            
            Text(workerId == viewModel.player.playerId ? "You" : String(workerId))
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Spacer()
            
            Text("\(contract.rewardPerWorker)g")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.gold)
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        if !contract.isComplete {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                if canAccept {
                    acceptContractButton
                    acceptContractInfo
                } else if isPlayerWorking {
                    workingOnContractView
                } else if viewModel.player.activeContractId != nil {
                    alreadyWorkingMessage
                } else if contract.createdBy == viewModel.player.playerId {
                    creatorMessage
                }
            }
            .padding(KingdomTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        } else {
            completedMessage
        }
    }
    
    private var acceptContractButton: some View {
        Button(action: {
            Task {
                do {
                    let _ = try await viewModel.contractAPI.joinContract(contractId: contract.id)
                    successMessage = "Signed up! Contract will complete automatically."
                    showSuccessMessage = true
                    
                    // Reload contracts
                    await viewModel.loadContracts()
                } catch {
                    successMessage = "Failed to join: \(error.localizedDescription)"
                    showSuccessMessage = true
                }
            }
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Accept Contract")
            }
        }
        .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
    }
    
    private var acceptContractInfo: some View {
        VStack(spacing: 4) {
            Text("Rewards split equally among all workers")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text("You can only work on one contract at a time")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var workingOnContractView: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're working on this contract")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let remaining = contract.hoursRemaining {
                        Text("~\(formatTime(remaining)) remaining")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
            }
            
            leaveContractButton
        }
    }
    
    private var leaveContractButton: some View {
        Button(action: {
            if viewModel.leaveContract() {
                successMessage = "Left contract"
                showSuccessMessage = true
            }
        }) {
            HStack {
                Image(systemName: "xmark.circle")
                Text("Leave Contract")
            }
        }
        .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSecondary, fullWidth: true))
    }
    
    private var alreadyWorkingMessage: some View {
        Text("You're already working on another contract")
            .font(KingdomTheme.Typography.body())
            .foregroundColor(KingdomTheme.Colors.inkMedium)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
    
    private var creatorMessage: some View {
        Text("You created this contract - you cannot work on it")
            .font(KingdomTheme.Typography.body())
            .foregroundColor(KingdomTheme.Colors.inkMedium)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
    
    private var completedMessage: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            
            Text("Contract Complete!")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            if isPlayerWorking {
                Text("You earned \(contract.rewardPerWorker) gold!")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(KingdomTheme.Spacing.xxLarge)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func formatTime(_ hours: Double) -> String {
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(minutes)m"
        } else if hours < 24 {
            return String(format: "%.1fh", hours)
        } else {
            let days = Int(hours / 24)
            let remainingHours = Int(hours.truncatingRemainder(dividingBy: 24))
            return "\(days)d \(remainingHours)h"
        }
    }
}

//#Preview("List") {
//    ContractsListView()
//}
//
//#Preview("Detail") {
//    ContractDetailView(contract: Contract.sample)
//}

