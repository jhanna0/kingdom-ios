import SwiftUI

struct ContractCreationView: View {
    let kingdom: Kingdom
    let buildingType: String  // FULLY DYNAMIC - just a string from backend
    @ObservedObject var viewModel: MapViewModel
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreating = false
    @State private var actionReward: Int = 5  // Gold per action (ruler sets this)
    
    private var buildingName: String {
        // FULLY DYNAMIC - Get from kingdom metadata
        if let meta = kingdom.getBuildingMetadata(buildingType) {
            return meta.displayName
        }
        return buildingType.capitalized
    }
    
    private var currentLevel: Int {
        // BACKEND IS SOURCE OF TRUTH - dynamic dictionary
        return kingdom.buildingLevel(buildingType)
    }
    
    private var upgradeCost: BuildingUpgradeCost? {
        // BACKEND IS SOURCE OF TRUTH - dynamic dictionary
        return kingdom.upgradeCost(buildingType)
    }
    
    private var nextLevel: Int {
        currentLevel + 1
    }
    
    private var actionsRequired: Int {
        return upgradeCost?.actionsRequired ?? 0
    }
    
    // Upfront cost = actions_required × action_reward (ruler pays this)
    private var upfrontCost: Int {
        return actionsRequired * actionReward
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    // Building info
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        HStack {
                            Text(buildingName)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            // Level badge
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("→ LVL \(nextLevel)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.buttonPrimary,
                                cornerRadius: 6,
                                shadowOffset: 2,
                                borderWidth: 2
                            )
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text("\(actionsRequired) actions needed")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    .padding(.horizontal)
                    
                    // Worker pay setter
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        Text("Gold per action")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        
                        HStack(spacing: 12) {
                            Button(action: { if actionReward > 1 { actionReward -= 1 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(actionReward > 1 ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled)
                            }
                            .disabled(actionReward <= 1)
                            
                            HStack(spacing: 4) {
                                Text("\(actionReward)")
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Text("g")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    .offset(y: 4)
                            }
                            .frame(minWidth: 80)
                            
                            Button(action: { actionReward += 1 }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                            }
                        }
                        
                        Text("You will pay citizens \(actionReward)g per action")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentHighlight)
                    .padding(.horizontal)
                    
                    // Cost summary
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        // Calculation
                        HStack(spacing: 6) {
                            Text("\(actionsRequired)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("×")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Text("\(actionReward)g")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("=")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Text("\(upfrontCost)g")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.imperialGold)
                        }
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Divider()
                        
                        // Treasury comparison
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Cost")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                Text("\(upfrontCost)g")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Treasury")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                Text("\(kingdom.treasuryGold)g")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                        }
                        
                        // Warning
                        if upfrontCost > kingdom.treasuryGold {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Insufficient treasury funds")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    .padding(.horizontal)
                    
                    // Create button
                    Button(action: createContract) {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Posting...")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            } else {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Post Contract")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .brutalistBadge(
                        backgroundColor: upfrontCost <= kingdom.treasuryGold ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled,
                        cornerRadius: 12,
                        shadowOffset: upfrontCost <= kingdom.treasuryGold ? 3 : 0,
                        borderWidth: 2
                    )
                    .disabled(upfrontCost > kingdom.treasuryGold || isCreating)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Post Contract")
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
        if upfrontCost > kingdom.treasuryGold {
            errorMessage = "Insufficient treasury funds. Have: \(kingdom.treasuryGold)g, Need: \(upfrontCost)g"
            showError = true
            return
        }
        
        isCreating = true
        
        // Call the create contract method asynchronously
        Task {
            do {
                // FULLY DYNAMIC - pass string directly with ruler-set action_reward
                _ = try await viewModel.createContract(kingdom: kingdom, buildingType: buildingType, actionReward: actionReward)
                
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

// MARK: - Brutalist Benefit Row Component
struct BrutalistBenefitRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon badge
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        Circle()
                            .fill(color)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
        }
    }
}
