import SwiftUI

/// Pledge phase view for Coup V2
/// Displays initiator character sheet and participant lists sorted by reputation
struct CoupPledgeView: View {
    let coup: CoupEventResponse
    let onPledge: (String) -> Void
    
    @State private var selectedSide: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Header
                headerSection
                
                // Timer
                timerSection
                
                // Initiator Character Sheet
                if let stats = coup.initiatorStats {
                    initiatorSection(stats: stats)
                }
                
                // Current Forces
                forcesSection
                
                // Participant Lists
                participantListsSection
                
                // Pledge Buttons (if can pledge)
                if coup.canPledge {
                    pledgeSection
                } else if let userSide = coup.userSide {
                    alreadyPledgedSection(side: userSide)
                }
            }
            .padding()
        }
        .parchmentBackground()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: KingdomTheme.Spacing.small) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(KingdomTheme.Colors.buttonSpecial)
            
            Text("Coup in \(coup.kingdomName ?? "Kingdom")")
                .font(KingdomTheme.Typography.title())
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .multilineTextAlignment(.center)
            
            Text("\(coup.initiatorName) challenges the throne!")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(.vertical)
    }
    
    // MARK: - Timer
    
    private var timerSection: some View {
        VStack(spacing: 4) {
            Text("Pledge Phase Ends In")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            Text(coup.timeRemainingFormatted)
                .font(KingdomTheme.Typography.title2())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.buttonSpecial)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Initiator Character Sheet
    
    private func initiatorSection(stats: InitiatorStats) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonSpecial)
                Text("The Challenger: \(coup.initiatorName)")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            // Main Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: KingdomTheme.Spacing.medium) {
                statCell(label: "Level", value: "\(stats.level)", icon: "star.fill", color: KingdomTheme.Colors.imperialGold)
                statCell(label: "Kingdom Rep", value: "\(stats.kingdomReputation)", icon: "heart.fill", color: KingdomTheme.Colors.buttonSpecial)
            }
            
            Divider()
                .background(KingdomTheme.Colors.border)
            
            // Combat Stats
            Text("Combat Stats")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: KingdomTheme.Spacing.small) {
                statCell(label: "Attack", value: "\(stats.attackPower)", icon: "sword.fill", color: KingdomTheme.Colors.buttonDanger)
                statCell(label: "Defense", value: "\(stats.defensePower)", icon: "shield.fill", color: KingdomTheme.Colors.royalBlue)
                statCell(label: "Leadership", value: "\(stats.leadership)", icon: "crown.fill", color: KingdomTheme.Colors.imperialGold)
            }
            
            Divider()
                .background(KingdomTheme.Colors.border)
            
            // Track Record
            Text("Track Record")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkLight)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: KingdomTheme.Spacing.small) {
                statCell(label: "Contracts", value: "\(stats.contractsCompleted)", icon: "checkmark.circle.fill", color: KingdomTheme.Colors.buttonSuccess)
                statCell(label: "Work Done", value: "\(stats.totalWorkContributed)", icon: "hammer.fill", color: KingdomTheme.Colors.goldWarm)
                statCell(label: "Coups Won", value: "\(stats.coupsWon)", icon: "flag.fill", color: KingdomTheme.Colors.buttonSuccess)
                statCell(label: "Coups Failed", value: "\(stats.coupsFailed)", icon: "xmark.circle.fill", color: KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func statCell(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(KingdomTheme.Typography.headline())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            Text(label)
                .font(KingdomTheme.Typography.caption2())
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Forces Overview
    
    private var forcesSection: some View {
        HStack(spacing: KingdomTheme.Spacing.xxLarge) {
            forceDisplay(
                icon: "sword.fill",
                count: coup.attackerCount,
                label: "Attackers",
                color: KingdomTheme.Colors.buttonDanger
            )
            
            Text("VS")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            forceDisplay(
                icon: "shield.fill",
                count: coup.defenderCount,
                label: "Defenders",
                color: KingdomTheme.Colors.royalBlue
            )
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func forceDisplay(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: KingdomTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text("\(count)")
                .font(KingdomTheme.Typography.title())
                .fontWeight(.bold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text(label)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    // MARK: - Participant Lists
    
    private var participantListsSection: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Attackers
            participantList(
                title: "Attackers",
                icon: "sword.fill",
                color: KingdomTheme.Colors.buttonDanger,
                participants: coup.attackers
            )
            
            // Defenders
            participantList(
                title: "Defenders",
                icon: "shield.fill",
                color: KingdomTheme.Colors.royalBlue,
                participants: coup.defenders
            )
        }
    }
    
    private func participantList(title: String, icon: String, color: Color, participants: [CoupParticipant]) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                Text("\(participants.count)")
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            if participants.isEmpty {
                Text("No one yet...")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .italic()
                    .padding(.vertical, KingdomTheme.Spacing.small)
            } else {
                ForEach(participants) { participant in
                    participantRow(participant: participant, sideColor: color)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func participantRow(participant: CoupParticipant, sideColor: Color) -> some View {
        HStack {
            Circle()
                .fill(sideColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(participant.playerName.prefix(1)).uppercased())
                        .font(KingdomTheme.Typography.caption())
                        .fontWeight(.bold)
                        .foregroundColor(sideColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.playerName)
                    .font(KingdomTheme.Typography.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Lv.\(participant.level) • \(participant.kingdomReputation) rep")
                    .font(KingdomTheme.Typography.caption2())
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
            
            // Combat stats
            HStack(spacing: KingdomTheme.Spacing.small) {
                Label("\(participant.attackPower)", systemImage: "sword.fill")
                    .font(KingdomTheme.Typography.caption2())
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                Label("\(participant.defensePower)", systemImage: "shield.fill")
                    .font(KingdomTheme.Typography.caption2())
                    .foregroundColor(KingdomTheme.Colors.royalBlue)
            }
        }
        .padding(.vertical, KingdomTheme.Spacing.small)
    }
    
    // MARK: - Pledge Section
    
    private var pledgeSection: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            Text("Choose Your Side")
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Attackers Button
            pledgeButton(
                title: "Support the Challenger",
                subtitle: "Help \(coup.initiatorName) seize power",
                icon: "sword.fill",
                color: KingdomTheme.Colors.buttonDanger,
                side: "attackers"
            )
            
            // Defenders Button
            pledgeButton(
                title: "Defend the Crown",
                subtitle: "Protect the current ruler",
                icon: "shield.fill",
                color: KingdomTheme.Colors.royalBlue,
                side: "defenders"
            )
            
            // Confirm Button
            if let side = selectedSide {
                Button(action: { onPledge(side) }) {
                    Text("Confirm Pledge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(backgroundColor: KingdomTheme.Colors.buttonSpecial, fullWidth: true))
                .padding(.top)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentRich)
    }
    
    private func pledgeButton(title: String, subtitle: String, icon: String, color: Color, side: String) -> some View {
        Button(action: { selectedSide = side }) {
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(subtitle)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
                
                if selectedSide == side {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                    .fill(selectedSide == side ? color.opacity(0.15) : KingdomTheme.Colors.parchmentLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusSmall)
                    .stroke(selectedSide == side ? color : KingdomTheme.Colors.border, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Already Pledged
    
    private func alreadyPledgedSection(side: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            Text("You pledged to the \(side)")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.buttonSuccess.opacity(0.1))
    }
}

// MARK: - Preview

#Preview {
    CoupPledgeView(
        coup: CoupEventResponse(
            id: 1,
            kingdomId: "test",
            kingdomName: "Test Kingdom",
            initiatorId: 123,
            initiatorName: "John the Bold",
            initiatorStats: InitiatorStats(
                level: 15,
                kingdomReputation: 650,
                attackPower: 12,
                defensePower: 10,
                leadership: 4,
                buildingSkill: 8,
                intelligence: 6,
                contractsCompleted: 45,
                totalWorkContributed: 320,
                coupsWon: 2,
                coupsFailed: 1
            ),
            status: "pledge",
            startTime: "2024-01-01T00:00:00Z",
            pledgeEndTime: "2024-01-01T12:00:00Z",
            battleEndTime: nil,
            timeRemainingSeconds: 32400,
            attackers: [
                CoupParticipant(playerId: 123, playerName: "John the Bold", kingdomReputation: 650, attackPower: 12, defensePower: 10, leadership: 4, level: 15),
                CoupParticipant(playerId: 124, playerName: "Alice", kingdomReputation: 400, attackPower: 8, defensePower: 6, leadership: 2, level: 10)
            ],
            defenders: [
                CoupParticipant(playerId: 200, playerName: "The King", kingdomReputation: 800, attackPower: 5, defensePower: 15, leadership: 5, level: 20)
            ],
            attackerCount: 2,
            defenderCount: 1,
            userSide: nil,
            canPledge: true,
            isResolved: false,
            attackerVictory: nil,
            resolvedAt: nil
        ),
        onPledge: { _ in }
    )
}
