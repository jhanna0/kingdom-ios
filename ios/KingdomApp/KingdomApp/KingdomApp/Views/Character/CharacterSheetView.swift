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
    @State private var myActivities: [ActivityLogEntry] = []
    @State private var isLoadingActivities = true
    
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
                
                // Combined combat stats and training
                combatAndTrainingCard
                
                // Crafting section
                craftingInfoCard
                
                // My Activity section
                myActivitySection
            }
            .padding()
        }
        .task {
            await loadMyActivities()
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
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "figure.fencing")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Combat & Skills")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(player.gold)")
                        .font(FontStyles.bodyLargeBold)
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
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        
                        Text("Training In Progress: \(activeContract.type.capitalized)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    
                    Text("Complete your current training (\(activeContract.actionsCompleted)/\(activeContract.actionsRequired)) before starting a new one")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
            }
            
            Text("Tap a skill to view all tiers and purchase training")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Skills grid - 3 rows for all skills + reputation
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
                    
                    // Reputation button
                    reputationGridButton
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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
    
    // MARK: - Helper Views
    
    private var reputationGridButton: some View {
        let reputationTier = ReputationTier.from(reputation: player.reputation)
        
        return NavigationLink(destination: ReputationDetailView(player: player)) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // Icon background with brutalist style
                    Image(systemName: reputationTier.icon)
                        .font(FontStyles.iconLarge)
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .brutalistBadge(
                            backgroundColor: reputationTier.color,
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                }
                
                VStack(spacing: 2) {
                    Text("Reputation")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("\(player.reputation) rep")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
    
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
            // TODO: Backend should provide skill benefit descriptions
            // For now, just show benefits without hardcoded percentages
            switch tier {
            case 1:
                return "Reduced building costs"
            case 2:
                return "Reduced costs • +10% coin rewards"
            case 3:
                return "Reduced costs • +20% coins • +1 daily Assist"
            case 4:
                return "Reduced costs • +30% coins • 10% cooldown refund"
            case 5:
                return "Reduced costs • +40% coins • 25% double progress"
            default:
                return "Reduced building costs"
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
                    // Icon background with brutalist style
                    Image(systemName: iconName)
                        .font(FontStyles.iconLarge)
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.gold,
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    
                    // Tier badge
                    Text("\(tier)")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.buttonPrimary,
                            cornerRadius: 11,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                        .offset(x: 6, y: -6)
                }
                
                VStack(spacing: 2) {
                    Text(displayName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Tier \(tier)/5")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
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
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("Equipment Crafting")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            // Resources row with brutalist badges
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(.gray)
                    Text("\(player.iron)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(.blue)
                    Text("\(player.steel)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("\(player.gold)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
            }
            
            // Show active crafting contract if exists
            if let activeContract = craftingQueue.first(where: { $0.status != "completed" }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        
                        Text("Crafting In Progress: Tier \(activeContract.tier) \(activeContract.equipmentType.capitalized)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    
                    Text("Complete your current craft (\(activeContract.actionsCompleted)/\(activeContract.actionsRequired)) before starting a new one")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning.opacity(0.15), cornerRadius: 8)
            }
            
            Text("Tap equipment to view all tiers and start crafting")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
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
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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
                    // Icon background with brutalist style
                    Image(systemName: iconName)
                        .font(FontStyles.iconLarge)
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .brutalistBadge(
                            backgroundColor: equipped != nil ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium,
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    
                    // Tier badge
                    if let item = equipped {
                        Text("\(item.tier)")
                            .font(FontStyles.labelBadge)
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .brutalistBadge(
                                backgroundColor: KingdomTheme.Colors.buttonPrimary,
                                cornerRadius: 11,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                            .offset(x: 6, y: -6)
                    }
                }
                
                VStack(spacing: 2) {
                    Text(displayName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if equipped != nil {
                        Text("+\(bonus)")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    } else {
                        Text("Not equipped")
                            .font(FontStyles.labelTiny)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - My Activity Section
    
    private var myActivitySection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.gold)
                
                Text("My Activity")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("Last 7 days")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if isLoadingActivities {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(KingdomTheme.Colors.inkMedium)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if myActivities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    
                    Text("No Recent Activity")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Your actions will appear here")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 10) {
                    ForEach(myActivities.prefix(5)) { activity in
                        MyActivityRow(activity: activity)
                    }
                    
                    if myActivities.count > 5 {
                        Text("+ \(myActivities.count - 5) more activities")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
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

// MARK: - My Activity Row

struct MyActivityRow: View {
    let activity: ActivityLogEntry
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: activity.icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .brutalistBadge(backgroundColor: activityColor(activity.color), cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(ActionIconHelper.activityDescription(for: activity.actionType))
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 6) {
                    Text(activity.timeAgo)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    if let kingdomName = activity.kingdomName {
                        Text("•")
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text(kingdomName)
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            
            Spacer()
            
            // Amount if present
            if let amount = activity.amount {
                HStack(spacing: 3) {
                    Text("+\(amount)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.gold)
                    Image(systemName: "g.circle.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
            }
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    private func activityColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return KingdomTheme.Colors.buttonSuccess
        case "blue": return KingdomTheme.Colors.buttonPrimary
        case "orange": return KingdomTheme.Colors.buttonWarning
        case "red": return KingdomTheme.Colors.buttonDanger
        case "yellow": return KingdomTheme.Colors.gold
        default: return KingdomTheme.Colors.inkMedium
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

