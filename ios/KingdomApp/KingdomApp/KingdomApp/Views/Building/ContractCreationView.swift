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
    
    private var buildingName: String {
        // FULLY DYNAMIC - Get from kingdom metadata
        if let meta = kingdom.buildingMetadata(buildingType) {
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
    
    private var constructionCost: Int {
        return upgradeCost?.constructionCost ?? 0
    }
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.xLarge) {
                    // Header - Bold title
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.royalPurple)
                            
                            Text("Create Contract")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Text("Post a contract for workers to complete")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding()
                    
                    // Building info - Brutalist card
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        HStack {
                            Text("BUILDING")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                                .tracking(1)
                            
                            Spacer()
                            
                            // Level badge
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("LVL \(nextLevel)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.royalPurple,
                                cornerRadius: 6,
                                shadowOffset: 2,
                                borderWidth: 2
                            )
                        }
                        
                        Text(buildingName)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        // Actions required badge
                        HStack(spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            
                            Text("\(actionsRequired) ACTIONS REQUIRED")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        // Population info
                        HStack(spacing: 6) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 12))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            
                            Text("Scales with \(kingdom.checkedInPlayers) citizens")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                        }
                    }
                    .padding(KingdomTheme.Spacing.large)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    .padding(.horizontal)
                    
                    // Cost summary - Brutalist card with gold accent
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        Text("CONSTRUCTION COST")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                            .tracking(1)
                        
                        HStack(alignment: .top, spacing: KingdomTheme.Spacing.medium) {
                            // Cost
                            VStack(alignment: .leading, spacing: 6) {
                                Text("COST")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                    .tracking(0.5)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "hammer.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(KingdomTheme.Colors.imperialGold)
                                    
                                    Text("\(constructionCost)")
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    
                                    Text("g")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        .offset(y: 4)
                                }
                            }
                            
                            Spacer()
                            
                            // Treasury status
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("TREASURY")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                    .tracking(0.5)
                                
                                HStack(spacing: 6) {
                                    Text("\(kingdom.treasuryGold)")
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundColor(constructionCost <= kingdom.treasuryGold ? KingdomTheme.Colors.inkDark : .red)
                                    
                                    Text("g")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(constructionCost <= kingdom.treasuryGold ? KingdomTheme.Colors.inkMedium : .red)
                                        .offset(y: 2)
                                    
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(constructionCost <= kingdom.treasuryGold ? KingdomTheme.Colors.imperialGold : .red)
                                }
                            }
                        }
                        
                        // Insufficient funds warning
                        if constructionCost > kingdom.treasuryGold {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text("INSUFFICIENT FUNDS")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.red)
                                    .tracking(0.5)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .brutalistBadge(
                                backgroundColor: Color.red.opacity(0.1),
                                cornerRadius: 8,
                                shadowOffset: 2,
                                borderWidth: 2
                            )
                        }
                    }
                    .padding(KingdomTheme.Spacing.large)
                    .brutalistCard(
                        backgroundColor: constructionCost <= kingdom.treasuryGold ? KingdomTheme.Colors.parchmentHighlight : KingdomTheme.Colors.parchmentMuted
                    )
                    .padding(.horizontal)
                    
                    // How it works - Brutalist info box
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        Text("HOW IT WORKS")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                            .tracking(1)
                        
                        VStack(spacing: KingdomTheme.Spacing.small) {
                            BrutalistBenefitRow(icon: "doc.text.fill", text: "Workers contribute actions", color: KingdomTheme.Colors.buttonPrimary)
                            BrutalistBenefitRow(icon: "person.2.fill", text: "More workers = faster build", color: KingdomTheme.Colors.buttonSuccess)
                            BrutalistBenefitRow(icon: "crown.fill", text: "Workers earn rewards", color: KingdomTheme.Colors.imperialGold)
                            BrutalistBenefitRow(icon: "building.2.fill", text: "Building upgrades on complete", color: KingdomTheme.Colors.royalPurple)
                        }
                    }
                    .padding(KingdomTheme.Spacing.large)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentDark)
                    .padding(.horizontal)
                    
                    // Create button - Big brutalist button
                    Button(action: createContract) {
                        HStack(spacing: 10) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                
                                Text("POSTING...")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .tracking(1)
                            } else {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 22, weight: .bold))
                                
                                Text("POST CONTRACT")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .tracking(1)
                            }
                        }
                    }
                    .buttonStyle(
                        .brutalist(
                            backgroundColor: constructionCost <= kingdom.treasuryGold ? KingdomTheme.Colors.royalPurple : KingdomTheme.Colors.disabled,
                            foregroundColor: .white,
                            fullWidth: true
                        )
                    )
                    .disabled(constructionCost > kingdom.treasuryGold || isCreating)
                    .padding(.horizontal)
                    .padding(.bottom, KingdomTheme.Spacing.xLarge)
                }
                .padding(.top, KingdomTheme.Spacing.medium)
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
        if constructionCost > kingdom.treasuryGold {
            errorMessage = "Insufficient treasury funds. Have: \(kingdom.treasuryGold)g, Need: \(constructionCost)g"
            showError = true
            return
        }
        
        isCreating = true
        
        // Call the create contract method asynchronously
        Task {
            do {
                // FULLY DYNAMIC - pass string directly
                _ = try await viewModel.createContract(kingdom: kingdom, buildingType: buildingType, rewardPool: 0)  // Reward pool deprecated
                
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
