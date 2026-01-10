import SwiftUI

/// Pledge phase view for Coup V2
/// Shows VS poster as hero, pledge buttons below - ONE cohesive screen

struct CoupPledgeView: View {
    let coup: CoupEventResponse
    let onDismiss: () -> Void
    let onPledge: (String) -> Void
    
    @State private var selectedSide: String?
    @State private var showParticipants = false
    
    private var rulerName: String {
        coup.rulerName ?? "The Crown"
    }
    
    private var challengerStats: FighterStats {
        if let stats = coup.initiatorStats {
            return FighterStats(from: stats)
        }
        return .empty
    }
    
    private var rulerStats: FighterStats {
        if let stats = coup.rulerStats {
            return FighterStats(from: stats)
        }
        return .empty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.medium) {
                // Hero VS Poster
                CoupVsPosterView(
                    kingdomName: coup.kingdomName ?? "Kingdom",
                    challengerName: coup.initiatorName,
                    rulerName: rulerName,
                    attackerCount: coup.attackerCount,
                    defenderCount: coup.defenderCount,
                    timeRemaining: coup.timeRemainingFormatted,
                    status: coup.status,
                    userSide: coup.userSide,
                    challengerStats: challengerStats,
                    rulerStats: rulerStats,
                    onDismiss: onDismiss
                )
                
                // Pledge buttons OR pledged status - NO card wrapper
                if coup.canPledge {
                    pledgeButtons
                } else if let userSide = coup.userSide {
                    pledgedStatus(side: userSide)
                }
                
                // View participants - subtle link
                viewParticipantsButton
            }
            .padding(.horizontal, KingdomTheme.Spacing.medium)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .parchmentBackground()
        .sheet(isPresented: $showParticipants) {
            participantsSheet
        }
    }
    
    // MARK: - Pledge Buttons (no card wrapper!)
    
    private var pledgeButtons: some View {
        VStack(spacing: 10) {
            // Two big choice buttons
            CoupPledgeChoiceCard(
                title: "ATTACKERS",
                subtitle: "Join the revolt",
                icon: "figure.fencing",
                tint: KingdomTheme.Colors.buttonDanger,
                isSelected: selectedSide == "attackers",
                onTap: { selectedSide = "attackers" }
            )
            
            CoupPledgeChoiceCard(
                title: "DEFENDERS",
                subtitle: "Protect the crown",
                icon: "shield.fill",
                tint: KingdomTheme.Colors.royalBlue,
                isSelected: selectedSide == "defenders",
                onTap: { selectedSide = "defenders" }
            )
            
            // Confirm button appears after selection
            if let side = selectedSide {
                Button(action: { onPledge(side) }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("CONFIRM PLEDGE")
                            .font(.system(size: 14, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: side == "attackers" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue,
                    foregroundColor: .white,
                    fullWidth: true
                ))
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Pledged Status
    
    private func pledgedStatus(side: String) -> some View {
        let isAttacker = side.lowercased().contains("attack")
        let tint = isAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        let label = isAttacker ? "ATTACKERS" : "DEFENDERS"
        let icon = isAttacker ? "figure.fencing" : "shield.fill"
        
        return HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("YOU PLEDGED")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                    Text(label)
                        .font(.system(size: 16, weight: .black, design: .serif))
                }
                .foregroundColor(tint)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .offset(x: 3, y: 3)
                RoundedRectangle(cornerRadius: 14)
                    .fill(KingdomTheme.Colors.parchmentLight)
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint, lineWidth: 2)
            }
        )
    }
    
    // MARK: - View Participants
    
    private var viewParticipantsButton: some View {
        Button(action: { showParticipants = true }) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 12, weight: .bold))
                
                Text("View All Participants")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(KingdomTheme.Colors.inkMedium)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Participants Sheet
    
    private var participantsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.large) {
                    participantList(
                        title: "Attackers",
                        icon: "figure.fencing",
                        color: KingdomTheme.Colors.buttonDanger,
                        participants: coup.attackers
                    )
                    
                    participantList(
                        title: "Defenders",
                        icon: "shield.fill",
                        color: KingdomTheme.Colors.royalBlue,
                        participants: coup.defenders
                    )
                }
                .padding(KingdomTheme.Spacing.large)
            }
            .parchmentBackground()
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showParticipants = false }
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .parchmentNavigationBar()
        }
    }
    
    private func participantList(title: String, icon: String, color: Color, participants: [CoupParticipant]) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black)
                                .offset(x: 1.5, y: 1.5)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color)
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 2)
                        }
                    )
                
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text("\(participants.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if participants.isEmpty {
                Text("No one yet...")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KingdomTheme.Spacing.medium)
            } else {
                ForEach(participants) { participant in
                    participantRow(participant: participant, sideColor: color)
                }
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func participantRow(participant: CoupParticipant, sideColor: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(sideColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(participant.playerName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(sideColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.playerName)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Lv.\(participant.level) • \(participant.kingdomReputation) rep")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "sword.fill")
                        .font(.system(size: 9))
                    Text("\(participant.attackPower)")
                }
                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                HStack(spacing: 3) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 9))
                    Text("\(participant.defensePower)")
                }
                .foregroundColor(KingdomTheme.Colors.royalBlue)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(KingdomTheme.Colors.parchment)
        )
    }
}

// MARK: - Preview

#Preview {
    CoupPledgeView(
        coup: CoupEventResponse(
            id: 1,
            kingdomId: "test",
            kingdomName: "San Francisco",
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
            rulerId: 200,
            rulerName: "King Marcus",
            rulerStats: InitiatorStats(
                level: 20,
                kingdomReputation: 800,
                attackPower: 5,
                defensePower: 15,
                leadership: 5,
                buildingSkill: 12,
                intelligence: 10,
                contractsCompleted: 120,
                totalWorkContributed: 850,
                coupsWon: 0,
                coupsFailed: 0
            ),
            status: "pledge",
            startTime: "2024-01-01T00:00:00Z",
            pledgeEndTime: "2024-01-01T12:00:00Z",
            battleEndTime: nil,
            timeRemainingSeconds: 32400,
            attackers: [
                CoupParticipant(playerId: 123, playerName: "John the Bold", kingdomReputation: 650, attackPower: 12, defensePower: 10, leadership: 4, level: 15),
                CoupParticipant(playerId: 124, playerName: "Alice the Brave", kingdomReputation: 400, attackPower: 8, defensePower: 6, leadership: 2, level: 10)
            ],
            defenders: [
                CoupParticipant(playerId: 200, playerName: "King Marcus", kingdomReputation: 800, attackPower: 5, defensePower: 15, leadership: 5, level: 20)
            ],
            attackerCount: 2,
            defenderCount: 1,
            userSide: nil,
            canPledge: true,
            isResolved: false,
            attackerVictory: nil,
            resolvedAt: nil
        ),
        onDismiss: {},
        onPledge: { _ in }
    )
}
