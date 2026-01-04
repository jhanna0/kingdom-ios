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
                // Header with level and gold
                ProfileHeaderCard(
                    displayName: player.name,
                    level: player.level,
                    gold: player.gold,
                    rulerOf: player.isRuler ? player.currentKingdomName : nil
                )
                
                // Combined combat stats and training
                combatAndTrainingCard
                
                // Active Perks section
                if player.activePerks != nil {
                    activePerksCard
                }
                
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
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Combat & Skills")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
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
                        iconName: SkillConfig.get("attack").icon,
                        displayName: SkillConfig.get("attack").displayName,
                        tier: player.attackPower,
                        skillType: "attack"
                    )
                    
                    skillGridButton(
                        iconName: SkillConfig.get("defense").icon,
                        displayName: SkillConfig.get("defense").displayName,
                        tier: player.defensePower,
                        skillType: "defense"
                    )
                }
                
                HStack(spacing: 10) {
                    skillGridButton(
                        iconName: SkillConfig.get("leadership").icon,
                        displayName: SkillConfig.get("leadership").displayName,
                        tier: player.leadership,
                        skillType: "leadership"
                    )
                    
                    skillGridButton(
                        iconName: SkillConfig.get("building").icon,
                        displayName: SkillConfig.get("building").displayName,
                        tier: player.buildingSkill,
                        skillType: "building"
                    )
                }
                
                HStack(spacing: 10) {
                    skillGridButton(
                        iconName: SkillConfig.get("intelligence").icon,
                        displayName: SkillConfig.get("intelligence").displayName,
                        tier: player.intelligence,
                        skillType: "intelligence"
                    )
                    
                    skillGridButton(
                        iconName: SkillConfig.get("science").icon,
                        displayName: SkillConfig.get("science").displayName,
                        tier: player.science,
                        skillType: "science"
                    )
                }
                
                HStack(spacing: 10) {
                    skillGridButton(
                        iconName: SkillConfig.get("faith").icon,
                        displayName: SkillConfig.get("faith").displayName,
                        tier: player.faith,
                        skillType: "faith"
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
    
    private func getSkillColor(skillType: String) -> Color {
        return SkillConfig.get(skillType).color
    }
    
    private func getEquipmentColor(equipmentType: String, equipped: Bool) -> Color {
        switch equipmentType {
        case "weapon":
            return KingdomTheme.Colors.buttonDanger // Always red
        case "armor":
            return KingdomTheme.Colors.royalBlue // Always royal blue
        default:
            return KingdomTheme.Colors.inkMedium
        }
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
                            backgroundColor: getSkillColor(skillType: skillType),
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
                            backgroundColor: .black,
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
    
    // MARK: - Active Perks Card
    
    private var activePerksCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "star.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Active Bonuses")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            if let perks = player.activePerks {
                VStack(spacing: 10) {
                    // Combine all perks into brutalist badge grid
                    let allPerks = perks.combatPerks + perks.trainingPerks + perks.buildingPerks + 
                                   perks.espionagePerks + perks.politicalPerks + perks.travelPerks
                    
                    if allPerks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 32))
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            
                            Text("No Active Bonuses")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Text("Upgrade skills, equip items, and join kingdoms to gain bonuses")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        ForEach(allPerks, id: \.id) { perk in
                            perkBadge(perk)
                        }
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func perkBadge(_ perk: Player.PerkItem) -> some View {
        HStack(spacing: 12) {
            // Icon with color based on source type
            Image(systemName: perkIcon(for: perk))
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .brutalistBadge(
                    backgroundColor: perkColor(for: perk),
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                // Main text
                if let bonus = perk.bonus, let stat = perk.stat {
                    Text("\(bonus > 0 ? "+" : "")\(bonus) \(stat.capitalized)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                } else if let description = perk.description {
                    Text(description)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                // Source
                Text(perk.source)
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Expiration if applicable
                if let expiresAt = perk.expiresAt {
                    let remaining = expiresAt.timeIntervalSince(Date())
                    if remaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(FontStyles.iconMini)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text(formatDuration(remaining))
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
    }
    
    private func perkIcon(for perk: Player.PerkItem) -> String {
        // Use skill-specific icons based on the source
        if perk.sourceType == "player_skill" {
            // Try to match skill name dynamically
            for (skillType, config) in SkillConfig.all {
                if perk.source.lowercased().contains(skillType) {
                    return config.icon
                }
            }
        }
        
        switch perk.sourceType {
        case "equipment":
            // Use weapon/armor specific icons
            if perk.stat == "attack" {
                return SkillConfig.get("attack").icon
            } else {
                return SkillConfig.get("defense").icon
            }
        case "kingdom_building":
            if perk.source.contains("Education") {
                return "book.fill"
            } else if perk.source.contains("Farm") {
                return "leaf.fill"
            } else {
                return "building.2.fill"
            }
        case "property": return "house.fill"
        case "debuff": return "exclamationmark.triangle.fill"
        default: return "star.fill"
        }
    }
    
    private func perkColor(for perk: Player.PerkItem) -> Color {
        // Negative = red, positive based on type
        if let bonus = perk.bonus, bonus < 0 {
            return KingdomTheme.Colors.buttonDanger
        }
        
        // Color by skill type - DYNAMIC
        if perk.sourceType == "player_skill" {
            for (skillType, config) in SkillConfig.all {
                if perk.source.lowercased().contains(skillType) {
                    return config.color
                }
            }
        }
        
        switch perk.sourceType {
        case "equipment":
            // Match the stat type
            if perk.stat == "attack" {
                return SkillConfig.get("attack").color
            } else {
                return SkillConfig.get("defense").color
            }
        case "kingdom_building": return KingdomTheme.Colors.royalPurple
        case "property": return KingdomTheme.Colors.royalEmerald
        case "debuff": return KingdomTheme.Colors.buttonDanger
        default: return KingdomTheme.Colors.inkMedium
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Crafting Info Card
    
    private var craftingInfoCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
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
                    Text("\(player.gold)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Image(systemName: "g.circle.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.goldLight)
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
                            backgroundColor: getEquipmentColor(equipmentType: equipmentType, equipped: equipped != nil),
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
                                backgroundColor: .black,
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
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
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
                .brutalistBadge(backgroundColor: activity.color, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.description)
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
                    // Show minus for spending (travel_fee), plus for earning
                    let prefix = activity.actionType == "travel_fee" ? "-" : "+"
                    Text("\(prefix)\(amount)")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    // Show R for reputation (patrol) or G for gold
                    if activity.actionType == "patrol" {
                        Image(systemName: "r.circle.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.royalPurple)
                    } else {
                        Image(systemName: "g.circle.fill")
                            .font(FontStyles.iconMini)
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                    }
                }
            }
        }
        .padding(12)
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10, shadowOffset: 2, borderWidth: 2)
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

