import SwiftUI

/// Character progression and training view
struct CharacterSheetView: View {
    @ObservedObject var player: Player
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var alertTitle = "Error"
    @State private var trainingContracts: [TrainingContract] = []
    @State private var craftingQueue: [CraftingContract] = []
    @State private var craftingCosts: CraftingCosts?
    @State private var isLoadingContracts = true
    @State private var myActivities: [ActivityLogEntry] = []
    @State private var isLoadingActivities = true
    @State private var relocationStatus: RelocationStatusResponse?
    @State private var isLoadingRelocationStatus = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with level and gold
                ProfileHeaderCard(
                    displayName: player.name,
                    level: player.level,
                    gold: player.gold,
                    rulerOf: player.isRuler ? player.currentKingdomName : nil
                )
                
                // Combined combat stats and training
                CombatTrainingCard(
                    player: player,
                    trainingContracts: trainingContracts,
                    isLoadingContracts: isLoadingContracts,
                    onPurchaseTraining: purchaseTraining
                )
                
                // Inventory section
                InventoryCardView(player: player)
                
                // Pets section
                PetsCard(pets: player.pets, showEmpty: true)
                
                // Crafting section
                CraftingInfoCard(
                    player: player,
                    craftingQueue: craftingQueue,
                    craftingCosts: craftingCosts,
                    onPurchaseCraft: purchaseCraft
                )
                
                // Active Perks section
                if player.activePerks != nil {
                    ActivePerksCard(player: player)
                }
                
                // My Activity section
                MyActivitySection(
                    activities: myActivities,
                    isLoading: isLoadingActivities
                )
                
                // Hometown section (only show if not in hometown)
                if player.currentKingdom != player.hometownKingdomId {
                    HometownCard(
                        player: player,
                        relocationStatus: relocationStatus,
                        isLoadingRelocationStatus: isLoadingRelocationStatus,
                        onRelocate: relocateHometown
                    )
                }
                
                // Settings button
                NavigationLink(destination: SettingsView()) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(FontStyles.iconSmall)
                        Text("Settings")
                    }
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonPrimary,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            }
            .padding()
        }
        .task {
            await refreshPlayerState()
            await loadTrainingContracts()
            await loadMyActivities()
            await loadRelocationStatus()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Character Sheet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
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
        .alert(alertTitle, isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Data Loading
    
    private func refreshPlayerState() async {
        do {
            let playerState = try await KingdomAPIService.shared.player.loadState()
            await MainActor.run {
                player.updateFromAPIState(playerState)
            }
        } catch {
            print("❌ Failed to refresh player state: \(error)")
        }
    }
    
    private func loadTrainingContracts() async {
        print("🔍 CharacterSheetView: loadTrainingContracts() CALLED")
        do {
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
            print("✅ CharacterSheetView: Got action status response")
            await MainActor.run {
                trainingContracts = status.trainingContracts
                craftingQueue = status.craftingQueue
                craftingCosts = status.craftingCosts
                isLoadingContracts = false
            }
        } catch {
            await MainActor.run {
                isLoadingContracts = false
            }
        }
    }
    
    private func loadMyActivities() async {
        do {
            let response = try await KingdomAPIService.shared.friends.getMyActivities(limit: 20, days: 7)
            await MainActor.run {
                myActivities = response.activities
                isLoadingActivities = false
            }
        } catch {
            await MainActor.run {
                isLoadingActivities = false
            }
        }
    }
    
    private func loadRelocationStatus() async {
        isLoadingRelocationStatus = true
        do {
            let status = try await KingdomAPIService.shared.player.getRelocationStatus()
            await MainActor.run {
                relocationStatus = status
                isLoadingRelocationStatus = false
            }
        } catch {
            await MainActor.run {
                isLoadingRelocationStatus = false
            }
            print("❌ Failed to load relocation status: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func relocateHometown() async {
        do {
            let response = try await KingdomAPIService.shared.player.relocateHometown()
            let playerState = try await KingdomAPIService.shared.player.loadState()
            
            await MainActor.run {
                player.updateFromAPIState(playerState)
                
                alertTitle = "Success"
                if response.lost_ruler_status {
                    errorMessage = "Relocated to \(response.new_hometown_name). You lost ruler status in \(response.old_hometown_name)."
                } else {
                    errorMessage = "Successfully relocated to \(response.new_hometown_name)!"
                }
                showError = true
                
                Task {
                    await loadRelocationStatus()
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                errorMessage = error.localizedDescription
                showError = true
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
    
    private func purchaseTraining(type: String) {
        Task {
            do {
                let api = KingdomAPIService.shared.actions
                let response = try await api.purchaseTraining(type: type)
                let playerState = try await KingdomAPIService.shared.player.loadState()
                
                await loadTrainingContracts()
                
                await MainActor.run {
                    player.updateFromAPIState(playerState)
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Purchased \(type) training contract: \(response.actionsRequired) actions required")
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func purchaseCraft(equipmentType: String, tier: Int) {
        Task {
            do {
                let api = KingdomAPIService.shared.actions
                let response = try await api.purchaseCraft(equipmentType: equipmentType, tier: tier)
                let playerState = try await KingdomAPIService.shared.player.loadState()
                
                await loadTrainingContracts()
                
                await MainActor.run {
                    player.updateFromAPIState(playerState)
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Purchased tier \(tier) \(equipmentType) craft: \(response.actionsRequired) actions required")
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Preview

struct CharacterSheetView_Previews: PreviewProvider {
    static var previews: some View {
        CharacterSheetView(player: {
            let p = Player(name: "Test Player")
            p.level = 5
            p.experience = 150
            p.reputation = 250
            p.gold = 500
            p.attackPower = 3
            p.defensePower = 4
            p.leadership = 2
            p.buildingSkill = 5
            p.skillPoints = 2
            return p
        }())
    }
}

