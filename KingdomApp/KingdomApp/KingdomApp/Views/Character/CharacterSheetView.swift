import SwiftUI


/// Character progression and training view
struct CharacterSheetView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with level and XP
                    levelCard
                    
                    // Reputation section
                    reputationCard
                    
                    // Combat stats section
                    combatStatsCard
                    
                    // Training section
                    trainingCard
                }
                .padding()
            }
            .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
            .navigationTitle("Character Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                }
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
                    
                    Text("\(player.skillPoints) skill points")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
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
    
    // MARK: - Combat Stats Card
    
    private var combatStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat Stats")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            statRow(
                icon: "⚔️",
                name: "Attack Power",
                value: player.attackPower,
                description: "Offensive strength in coups"
            )
            
            Divider()
            
            statRow(
                icon: "🛡️",
                name: "Defense Power",
                value: player.defensePower,
                description: "Defend against coups"
            )
            
            Divider()
            
            statRow(
                icon: "👑",
                name: "Leadership",
                value: player.leadership,
                description: "Bonus to vote weight"
            )
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Training Card
    
    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("\(player.gold)💰")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            
            Text("Manage your gold wisely - invest in power or save for other opportunities")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            
            Divider()
            
            // Purchase XP Section
            VStack(alignment: .leading, spacing: 8) {
                Text("📚 Purchase Experience")
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Buy XP to level up and earn skill points")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                HStack(spacing: 8) {
                    xpPurchaseButton(xp: 10, cost: 100, label: "Small")
                    xpPurchaseButton(xp: 50, cost: 500, label: "Medium")
                    xpPurchaseButton(xp: 100, cost: 1000, label: "Large")
                }
            }
            
            Divider()
            
            // Direct Stat Training (More expensive than XP route)
            VStack(alignment: .leading, spacing: 8) {
                Text("⚔️ Direct Training")
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Instant stat increases (more expensive)")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
            }
            
            // Train Attack
            trainingButton(
                icon: "⚔️",
                name: "Train Attack",
                cost: player.getAttackTrainingCost(),
                currentValue: player.attackPower,
                canAfford: player.gold >= player.getAttackTrainingCost()
            ) {
                if player.trainAttack() {
                    // Success feedback (could add haptics here)
                }
            }
            
            // Train Defense
            trainingButton(
                icon: "🛡️",
                name: "Train Defense",
                cost: player.getDefenseTrainingCost(),
                currentValue: player.defensePower,
                canAfford: player.gold >= player.getDefenseTrainingCost()
            ) {
                if player.trainDefense() {
                    // Success feedback
                }
            }
            
            // Train Leadership
            trainingButton(
                icon: "👑",
                name: "Train Leadership",
                cost: player.getLeadershipTrainingCost(),
                currentValue: player.leadership,
                canAfford: player.gold >= player.getLeadershipTrainingCost()
            ) {
                if player.trainLeadership() {
                    // Success feedback
                }
            }
            
            if player.skillPoints > 0 {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skill Points: \(player.skillPoints)")
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Text("Use skill points to increase stats for free!")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    
                    HStack(spacing: 12) {
                        skillPointButton(icon: "⚔️", stat: .attack)
                        skillPointButton(icon: "🛡️", stat: .defense)
                        skillPointButton(icon: "👑", stat: .leadership)
                    }
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
    
    private func statRow(icon: String, name: String, value: Int, description: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
            
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
    }
    
    private func trainingButton(
        icon: String,
        name: String,
        cost: Int,
        currentValue: Int,
        canAfford: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(icon)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.bold())
                    
                    Text("\(currentValue) → \(currentValue + 1)")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
                
                Text("\(cost)💰")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(canAfford ? KingdomTheme.Colors.gold : .red)
            }
            .padding()
            .background(canAfford ? KingdomTheme.Colors.inkDark.opacity(0.05) : KingdomTheme.Colors.inkDark.opacity(0.02))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(canAfford ? KingdomTheme.Colors.inkDark.opacity(0.3) : .red.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!canAfford)
        .foregroundColor(KingdomTheme.Colors.inkDark)
    }
    
    private func skillPointButton(icon: String, stat: Player.SkillStat) -> some View {
        Button {
            player.useSkillPoint(on: stat)
        } label: {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                
                Text("+1")
                    .font(.caption.bold())
                    .foregroundColor(KingdomTheme.Colors.gold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(KingdomTheme.Colors.gold.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KingdomTheme.Colors.gold, lineWidth: 2)
            )
        }
    }
    
    private func xpPurchaseButton(xp: Int, cost: Int, label: String) -> some View {
        Button {
            _ = player.purchaseXP(amount: xp)
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("+\(xp) XP")
                    .font(.caption2)
                    .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                
                Text("\(cost)💰")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(player.gold >= cost ? KingdomTheme.Colors.gold : .red)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(player.gold >= cost ? KingdomTheme.Colors.inkDark.opacity(0.05) : KingdomTheme.Colors.inkDark.opacity(0.02))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(player.gold >= cost ? KingdomTheme.Colors.inkDark.opacity(0.3) : .red.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(player.gold < cost)
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
            p.skillPoints = 2
            return p
        }())
    }
}

