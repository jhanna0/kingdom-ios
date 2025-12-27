import SwiftUI

// MARK: - Contracts List View
// Browse and contribute to kingdom contracts

struct ContractsListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var contracts: [Contract] = Contract.samples
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        ForEach(contracts) { contract in
                            NavigationLink(value: contract) {
                                ContractCard(contract: contract)
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
                ContractDetailView(contract: contract)
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
    }
}

// MARK: - Contract Detail View
// View and contribute to a specific contract

struct ContractDetailView: View {
    let contract: Contract
    @State private var workToContribute: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.large) {
                    // Building info
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
                    
                    // Progress section
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        Text("Progress")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack {
                            Text("\(contract.workCompleted)")
                                .font(KingdomTheme.Typography.title3())
                                .foregroundColor(KingdomTheme.Colors.gold)
                            
                            Text("/ \(contract.totalWorkRequired) work points")
                                .font(KingdomTheme.Typography.body())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        
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
                    .padding(KingdomTheme.Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .parchmentCard()
                    
                    // Rewards section
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        Text("Rewards")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                            
                            Text("\(contract.rewardPool) gold total")
                                .font(KingdomTheme.Typography.body())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Text("≈ \(String(format: "%.2f", contract.goldPerWorkPoint)) gold per work point")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(KingdomTheme.Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .parchmentCard()
                    
                    // Contributors
                    if !contract.contributors.isEmpty {
                        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                            Text("Contributors (\(contract.contributors.count))")
                                .font(KingdomTheme.Typography.headline())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            ForEach(Array(contract.contributors.keys.sorted()), id: \.self) { playerId in
                                if let contribution = contract.contributors[playerId] {
                                    HStack {
                                        Text(playerId)
                                            .font(KingdomTheme.Typography.body())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        
                                        Spacer()
                                        
                                        Text("\(contribution) points")
                                            .font(KingdomTheme.Typography.caption())
                                            .foregroundColor(KingdomTheme.Colors.inkLight)
                                    }
                                    
                                    if playerId != contract.contributors.keys.sorted().last {
                                        Divider()
                                            .background(KingdomTheme.Colors.divider)
                                    }
                                }
                            }
                        }
                        .padding(KingdomTheme.Spacing.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .parchmentCard()
                    }
                    
                    // Contribute section (only if not complete)
                    if !contract.isComplete && contract.status == .open || contract.status == .inProgress {
                        VStack(spacing: KingdomTheme.Spacing.medium) {
                            Text("Contribute Work")
                                .font(KingdomTheme.Typography.headline())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Work points", text: $workToContribute)
                                .keyboardType(.numberPad)
                                .font(KingdomTheme.Typography.body())
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .padding(KingdomTheme.Spacing.medium)
                                .background(KingdomTheme.Colors.parchmentLight)
                                .cornerRadius(KingdomTheme.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.medium)
                                        .stroke(KingdomTheme.Colors.border, lineWidth: 1)
                                )
                            
                            Button("Contribute to Contract") {
                                // TODO: Submit contribution
                            }
                            .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonSuccess, fullWidth: true))
                            .disabled(workToContribute.isEmpty)
                        }
                        .padding(KingdomTheme.Spacing.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationTitle(contract.buildingType)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("List") {
    ContractsListView()
}

#Preview("Detail") {
    ContractDetailView(contract: Contract.sample)
}

