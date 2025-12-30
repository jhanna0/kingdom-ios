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
                ProfileHeaderCard(
                    displayName: player.name,
                    level: player.level,
                    experience: player.experience,
                    maxExperience: player.getXPForNextLevel(),
                    showsXPBar: true
                )
                
                // Reputation section
                ReputationStatsCard(
                    reputation: player.reputation,
                    showAbilities: true
                )
                
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
            
            Text("Tap a skill to view all tiers and purchase training")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Divider()
            
            // Skills grid - 3 rows for all skills
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    skillGridButton(
                        iconName: "bolt.fill",
                        displayName: "Attack",
                        tier: player.attackPower,
                        skillType: "attack"
                    )
                    
                    skillGridButton(
                        iconName: "shield.fill",
                        displayName: "Defense",
                        tier: player.defensePower,
                        skillType: "defense"
                    )
                }
                
                HStack(spacing: 10) {
                    skillGridButton(
                        iconName: "crown.fill",
                        displayName: "Leadership",
                        tier: player.leadership,
                        skillType: "leadership"
                    )
                    
                    skillGridButton(
                        iconName: "hammer.fill",
                        displayName: "Building",
                        tier: player.buildingSkill,
                        skillType: "building"
                    )
                }
                
                HStack(spacing: 10) {
                    skillGridButton(
                        iconName: "eye.fill",
                        displayName: "Intelligence",
                        tier: player.intelligence,
                        skillType: "intelligence"
                    )
                    
                    // Empty space for symmetry
                    Color.clear
                        .frame(maxWidth: .infinity)
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
    
    private func getSkillDescription(type: String, tier: Int) -> String {
        switch type {
        case "attack":
            return "Tier \(tier) - Increases coup damage"
        case "defense":
            return "Tier \(tier) - Increases coup resistance"
        case "leadership":
            switch tier {
            case 1:
                return "Vote weight: 1.0"
            case 2:
                return "Vote weight: 1.2 • +50% ruler rewards"
            case 3:
                return "Vote weight: 1.5 • Can propose coups"
            case 4:
                return "Vote weight: 1.8 • +100% ruler rewards"
            case 5:
                return "Vote weight: 2.0 • -50% coup cost"
            default:
                return "Vote weight: \(1.0 + (Double(tier - 1) * 0.2)) • Enhanced influence"
            }
        case "building":
            let discount = Int(player.getBuildingCostDiscount() * 100)
            switch tier {
            case 1:
                return "\(discount)% cost reduction"
            case 2:
                return "\(discount)% cost reduction • +10% coin rewards"
            case 3:
                return "\(discount)% cost reduction • +20% coins • +1 daily Assist"
            case 4:
                return "\(discount)% cost reduction • +30% coins • 10% cooldown refund"
            case 5:
                return "\(discount)% cost reduction • +40% coins • 25% double progress"
            default:
                return "\(discount)% cost reduction"
            }
        default:
            return "Combat skill"
        }
    }
    
    private func skillGridButton(
        iconName: String,
        displayName: String,
        tier: Int,
        skillType: String
    ) -> some View {
        NavigationLink(destination: SkillDetailView(
            player: player,
            skillType: skillType,
            trainingContracts: trainingContracts,
            onPurchase: {
                purchaseTraining(type: skillType)
            }
        )) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // Icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [KingdomTheme.Colors.gold.opacity(0.3), KingdomTheme.Colors.gold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .frame(width: 60, height: 60)
                    
                    // Tier badge
                    Text("\(tier)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(KingdomTheme.Colors.buttonPrimary)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
                
                VStack(spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Tier \(tier)/5")
                        .font(.caption2)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KingdomTheme.Colors.inkDark.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            
            Text("Tap equipment to view all tiers and start crafting")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Divider()
            
            // Equipment grid
            HStack(spacing: 10) {
                craftGridButton(
                    iconName: "bolt.fill",
                    displayName: "Weapon",
                    equipmentType: "weapon",
                    equipped: player.equippedWeapon,
                    bonus: player.equippedWeapon?.attackBonus ?? 0
                )
                
                craftGridButton(
                    iconName: "shield.fill",
                    displayName: "Armor",
                    equipmentType: "armor",
                    equipped: player.equippedArmor,
                    bonus: player.equippedArmor?.defenseBonus ?? 0
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
    
    private func craftGridButton(
        iconName: String,
        displayName: String,
        equipmentType: String,
        equipped: Player.EquipmentData?,
        bonus: Int
    ) -> some View {
        NavigationLink(destination: CraftingDetailView(
            player: player,
            equipmentType: equipmentType,
            craftingCosts: craftingCosts,
            craftingQueue: craftingQueue,
            onPurchase: { tier in
                purchaseCraft(equipmentType: equipmentType, tier: tier)
            }
        )) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // Icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [KingdomTheme.Colors.gold.opacity(0.3), KingdomTheme.Colors.gold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .frame(width: 60, height: 60)
                    
                    // Tier badge
                    if let item = equipped {
                        Text("\(item.tier)")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(KingdomTheme.Colors.buttonPrimary)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                
                VStack(spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if equipped != nil {
                        Text("+\(bonus)")
                            .font(.caption.bold())
                            .foregroundColor(KingdomTheme.Colors.gold)
                    } else {
                        Text("Not equipped")
                            .font(.caption2)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KingdomTheme.Colors.inkDark.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

