import SwiftUI

struct ContractCreationView: View {
    let kingdom: Kingdom
    let buildingType: BuildingType
    @ObservedObject var viewModel: MapViewModel
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreating = false
    
    private var buildingName: String {
        switch buildingType {
        case .walls: return "Walls"
        case .vault: return "Vault"
        case .mine: return "Mine"
        case .market: return "Market"
        }
    }
    
    private var currentLevel: Int {
        switch buildingType {
        case .walls: return kingdom.wallLevel
        case .vault: return kingdom.vaultLevel
        case .mine: return kingdom.mineLevel
        case .market: return kingdom.marketLevel
        }
    }
    
    private var nextLevel: Int {
        currentLevel + 1
    }
    
    private var estimatedHours: Double {
        // Estimate based on the contract creation formula
        let baseHours = 2.0 * pow(2.0, Double(nextLevel - 1))
        let populationMultiplier = 1.0 + (Double(kingdom.checkedInPlayers) / 30.0)
        return baseHours * populationMultiplier
    }
    
    private var autoReward: Int {
        // Auto-calculate based on time and level
        // Higher level = higher reward
        let baseReward = 100 * nextLevel
        let timeBonus = Int(estimatedHours * 10.0)
        return baseReward + timeBonus
    }
    
    private func formatTime(_ hours: Double) -> String {
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(minutes) minutes"
        } else if hours < 24 {
            return String(format: "%.1f hours", hours)
        } else {
            let days = Int(hours / 24)
            let remainingHours = Int(hours.truncatingRemainder(dividingBy: 24))
            return "\(days)d \(remainingHours)h"
        }
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.large) {
                    // Header
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                        Text("Create Contract")
                            .font(KingdomTheme.Typography.title2())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("Post a contract for workers to complete")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.horizontal)
                    
                    // Building info
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        Text("Building")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack {
                            Text("\(buildingName) → Level \(nextLevel)")
                                .font(KingdomTheme.Typography.title3())
                                .foregroundColor(KingdomTheme.Colors.gold)
                            
                            Spacer()
                        }
                        
                        Text("Estimated time: ~\(formatTime(estimatedHours)) with 3 workers")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Time scales with population (\(kingdom.checkedInPlayers) in city)")
                            .font(KingdomTheme.Typography.caption2())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding()
                    .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    .padding(.horizontal)
                    
                    // Cost summary
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        Text("Contract Cost")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reward Pool")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(KingdomTheme.Colors.goldLight)
                                    Text("\(autoReward)g")
                                        .font(KingdomTheme.Typography.title2())
                                        .fontWeight(.bold)
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Treasury")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .foregroundColor(autoReward <= kingdom.treasuryGold ? KingdomTheme.Colors.gold : .red)
                                    Text("\(kingdom.treasuryGold)g")
                                        .font(KingdomTheme.Typography.title3())
                                        .fontWeight(.semibold)
                                        .foregroundColor(autoReward <= kingdom.treasuryGold ? KingdomTheme.Colors.inkDark : .red)
                                }
                            }
                        }
                        
                        if autoReward > kingdom.treasuryGold {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Insufficient treasury funds")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .parchmentCard()
                    .padding(.horizontal)
                    
                    // How it works
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                        Text("How Contracts Work")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        BenefitRow(icon: "doc.text.fill", text: "Workers accept and it completes automatically")
                        BenefitRow(icon: "person.2.fill", text: "More workers = faster completion")
                        BenefitRow(icon: "crown.fill", text: "Rewards split equally among all workers")
                        BenefitRow(icon: "building.2.fill", text: "Building upgrades when timer finishes")
                    }
                    .padding()
                    .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentRich)
                    .padding(.horizontal)
                    
                    // Create button
                    Button(action: createContract) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Posting...")
                            } else {
                                Image(systemName: "doc.badge.plus")
                                Text("Post Contract for \(autoReward)g")
                            }
                        }
                    }
                    .buttonStyle(.medieval(color: autoReward <= kingdom.treasuryGold ? KingdomTheme.Colors.buttonSuccess : .gray, fullWidth: true))
                    .disabled(autoReward > kingdom.treasuryGold || isCreating)
                    .padding(.horizontal)
                    .padding(.bottom, KingdomTheme.Spacing.xLarge)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Create Contract")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createContract() {
        let reward = autoReward
        
        if reward > kingdom.treasuryGold {
            errorMessage = "Insufficient treasury funds. Have: \(kingdom.treasuryGold)g, Need: \(reward)g"
            showError = true
            return
        }
        
        isCreating = true
        
        // Call the create contract method asynchronously
        Task {
            do {
                _ = try await viewModel.createContract(kingdom: kingdom, buildingType: buildingType, rewardPool: reward)
                
                // Success! Dismiss and call success handler
                await MainActor.run {
                    dismiss()
                    onSuccess(buildingName)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}


