import SwiftUI


/// Character progression and training view
struct CharacterSheetView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var trainingContracts: [TrainingContract] = []
    @State private var craftingQueue: [CraftingContract] = []
    @State private var craftingCosts: CraftingCosts?
    @State private var isLoadingContracts = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with level and XP
                levelCard
                
                // Reputation section
                reputationCard
                
                // Combined combat stats and training
                combatAndTrainingCard
                
                // Crafting section
                craftingInfoCard
            }
            .padding()
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
    }
    
    // MARK: - Level Card
    
    private var levelCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(player.name)
                    .font(.title2.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Level \(player.level)")
                        .font(.headline)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
            
            // XP Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Experience")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(player.experience) / \(player.getXPForNextLevel()) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        // Progress
                        Rectangle()
                            .fill(KingdomTheme.Colors.gold)
                            .frame(width: geometry.size.width * player.getXPProgress(), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Reputation Card
    
    private var reputationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reputation")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.getReputationTier().rawValue)
                        .font(.title3.bold())
                        .foregroundColor(tierColor(player.getReputationTier()))
                    
                    Text("\(player.reputation) reputation")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: tierIcon(player.getReputationTier()))
                    .font(.system(size: 40))
                    .foregroundColor(tierColor(player.getReputationTier()))
            }
            
            Divider()
            
            // Abilities unlocked
            VStack(alignment: .leading, spacing: 6) {
                Text("Abilities:")
                    .font(.caption.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                abilityRow(
                    icon: "checkmark.circle.fill",
                    text: "Accept contracts",
                    unlocked: true
                )
                
                abilityRow(
                    icon: "house.fill",
                    text: "Buy property",
                    unlocked: player.reputation >= 50
                )
                
                abilityRow(
                    icon: "hand.raised.fill",
                    text: "Vote on coups",
                    unlocked: player.reputation >= 150
                )
                
                abilityRow(
                    icon: "flag.fill",
                    text: "Propose coups",
                    unlocked: player.reputation >= 300
                )
                
                abilityRow(
                    icon: "star.fill",
                    text: "Vote counts 2x",
                    unlocked: player.reputation >= 500
                )
                
                abilityRow(
                    icon: "crown.fill",
                    text: "Vote counts 3x",
                    unlocked: player.reputation >= 1000
                )
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Combined Combat & Training Card
    
    private var combatAndTrainingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Combat & Skills")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(player.gold)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
            
            // Show active training contract if exists
            if let activeContract = trainingContracts.first(where: { $0.status != "completed" }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        
                        Text("Training In Progress: \(activeContract.type.capitalized)")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    
                    Text("Complete your current training (\(activeContract.actionsCompleted)/\(activeContract.actionsRequired)) before starting a new one")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
                .cornerRadius(8)
            }
            
            Text("Purchase training sessions, then perform them in the Actions page (2 hour cooldown)")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Divider()
            
            // Attack Power
            statRowWithTraining(
                iconName: "bolt.fill",
                name: "Attack Power",
                value: player.attackPower,
                description: "Offensive strength in coups",
                cost: player.attackTrainingCost,
                trainingType: "attack"
            )
            
            Divider()
            
            // Defense Power
            statRowWithTraining(
                iconName: "shield.fill",
                name: "Defense Power",
                value: player.defensePower,
                description: "Defend against coups",
                cost: player.defenseTrainingCost,
                trainingType: "defense"
            )
            
            Divider()
            
            // Leadership
            statRowWithTraining(
                iconName: "crown.fill",
                name: "Leadership",
                value: player.leadership,
                description: "Bonus to vote weight",
                cost: player.leadershipTrainingCost,
                trainingType: "leadership"
            )
            
            Divider()
            
            // Building Skill
            statRowWithTraining(
                iconName: "hammer.fill",
                name: "Building Skill",
                value: player.buildingSkill,
                description: "\(Int(player.getBuildingCostDiscount() * 100))% cost reduction",
                cost: player.buildingTrainingCost,
                trainingType: "building"
            )
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
        .task {
            await loadTrainingContracts()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadTrainingContracts() async {
        do {
            let status = try await KingdomAPIService.shared.actions.getActionStatus()
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
    
    // MARK: - Helper Views
    
    private func abilityRow(icon: String, text: String, unlocked: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(unlocked ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(unlocked ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkDark.opacity(0.5))
            
            if !unlocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
            }
        }
    }
    
    private func statRowWithTraining(
        iconName: String,
        name: String,
        value: Int,
        description: String,
        cost: Int,
        trainingType: String
    ) -> some View {
        let hasActiveTraining = trainingContracts.contains { $0.status != "completed" }
        let canAfford = player.gold >= cost
        let isEnabled = canAfford && !hasActiveTraining && !isLoadingContracts
        
        return VStack(spacing: 8) {
            // Main stat row
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                Text("\(value)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            
            // Training purchase button
            Button(action: {
                purchaseTraining(type: trainingType)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(isEnabled ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled)
                    
                    if hasActiveTraining {
                        Text("Complete current training first")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    } else if !canAfford {
                        Text("Insufficient gold")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Train for")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(cost)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(isEnabled ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                        
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundColor(isEnabled ? KingdomTheme.Colors.gold : KingdomTheme.Colors.disabled)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isEnabled ? KingdomTheme.Colors.buttonPrimary.opacity(0.1) : KingdomTheme.Colors.inkDark.opacity(0.05))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isEnabled ? KingdomTheme.Colors.buttonPrimary.opacity(0.3) : KingdomTheme.Colors.disabled.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(!isEnabled)
        }
    }
    
    private func purchaseTraining(type: String) {
        Task {
            do {
                let api = KingdomAPIService.shared.actions
                
                // Purchase the training contract
                let response = try await api.purchaseTraining(type: type)
                
                // Refresh player state from backend to get updated gold
                let playerState = try await KingdomAPIService.shared.player.loadState()
                
                // Reload training contracts to show the new one
                await loadTrainingContracts()
                
                await MainActor.run {
                    player.updateFromAPIState(playerState)
                    
                    // Haptic feedback for success
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Purchased \(type) training contract: \(response.actionsRequired) actions required")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    // Haptic feedback for error
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Crafting Info Card
    
    private var craftingInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Equipment Crafting")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            // Resources row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(player.iron)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(player.steel)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("\(player.gold)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
            
            // Show active crafting contract if exists
            if let activeContract = craftingQueue.first(where: { $0.status != "completed" }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        
                        Text("Crafting In Progress: Tier \(activeContract.tier) \(activeContract.equipmentType.capitalized)")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    
                    Text("Complete your current craft (\(activeContract.actionsCompleted)/\(activeContract.actionsRequired)) before starting a new one")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
                .cornerRadius(8)
            }
            
            Text("Purchase crafting sessions here, then work on them in the Actions page")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Divider()
            
            VStack(spacing: 8) {
                // Weapon
                NavigationLink(destination: CraftingDetailView(
                    player: player,
                    equipmentType: "weapon",
                    craftingCosts: craftingCosts,
                    craftingQueue: craftingQueue,
                    onPurchase: { tier in
                        purchaseCraft(equipmentType: "weapon", tier: tier)
                    }
                )) {
                    craftNavButton(
                        iconName: "bolt.fill",
                        displayName: "Weapon",
                        equipped: player.equippedWeapon,
                        isWeapon: true
                    )
                }
                
                // Armor
                NavigationLink(destination: CraftingDetailView(
                    player: player,
                    equipmentType: "armor",
                    craftingCosts: craftingCosts,
                    craftingQueue: craftingQueue,
                    onPurchase: { tier in
                        purchaseCraft(equipmentType: "armor", tier: tier)
                    }
                )) {
                    craftNavButton(
                        iconName: "shield.fill",
                        displayName: "Armor",
                        equipped: player.equippedArmor,
                        isWeapon: false
                    )
                }
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func craftNavButton(
        iconName: String,
        displayName: String,
        equipped: Player.EquipmentData?,
        isWeapon: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(displayName) Crafting")
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                if let item = equipped {
                    Text("Equipped: Tier \(item.tier) (+\(isWeapon ? item.attackBonus : item.defenseBonus))")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.gold)
                } else {
                    Text("No \(displayName.lowercased()) equipped")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
        }
        .padding()
        .background(KingdomTheme.Colors.inkDark.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 1)
        )
    }
    
    
    private func purchaseCraft(equipmentType: String, tier: Int) {
        Task {
            do {
                let api = KingdomAPIService.shared.actions
                
                // Purchase the crafting contract
                let response = try await api.purchaseCraft(equipmentType: equipmentType, tier: tier)
                
                // Refresh player state from backend to get updated resources
                let playerState = try await KingdomAPIService.shared.player.loadState()
                
                // Reload crafting queue to show the new one
                await loadTrainingContracts()
                
                await MainActor.run {
                    player.updateFromAPIState(playerState)
                    
                    // Haptic feedback for success
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Purchased tier \(tier) \(equipmentType) craft: \(response.actionsRequired) actions required")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    // Haptic feedback for error
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func tierColor(_ tier: Player.ReputationTier) -> Color {
        switch tier {
        case .stranger: return .gray
        case .resident: return KingdomTheme.Colors.inkDark.opacity(0.7)
        case .citizen: return .blue
        case .notable: return .purple
        case .champion: return KingdomTheme.Colors.gold
        case .legendary: return .orange
        }
    }
    
    private func tierIcon(_ tier: Player.ReputationTier) -> String {
        switch tier {
        case .stranger: return "person.fill"
        case .resident: return "house.fill"
        case .citizen: return "person.2.fill"
        case .notable: return "star.fill"
        case .champion: return "crown.fill"
        case .legendary: return "sparkles"
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

