import SwiftUI

/// Battle phase view for Coup V2
/// Shows 3 territories with tug-of-war bars and fight buttons
struct CoupBattleView: View {
    let coup: CoupEventResponse
    let onDismiss: () -> Void
    let onFight: (String) -> Void  // territory name
    
    @State private var localCooldownSeconds: Int = 0
    @State private var localInjurySeconds: Int = 0
    @State private var timerActive = false
    
    private var rulerName: String {
        coup.rulerName ?? "The Crown"
    }
    
    /// Locally-tracked cooldown that ticks down
    private var displayCooldownSeconds: Int {
        max(0, localCooldownSeconds)
    }
    
    /// Locally-tracked injury that ticks down  
    private var displayInjurySeconds: Int {
        max(0, localInjurySeconds)
    }
    
    /// Can user fight based on local timers?
    private var localCanFight: Bool {
        guard coup.isBattlePhase else { return false }
        guard coup.userSide != nil else { return false }
        guard displayInjurySeconds <= 0 else { return false }
        guard displayCooldownSeconds <= 0 else { return false }
        return true
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
    
    private var territories: [CoupTerritory] {
        coup.territories ?? []
    }
    
    private var canFight: Bool {
        localCanFight
    }
    
    /// Format seconds to display string
    private func formatTime(_ seconds: Int) -> String {
        if seconds <= 0 { return "Ready" }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    private var capturedByAttackers: Int {
        territories.filter { $0.capturedBy == "attackers" }.count
    }
    
    private var capturedByDefenders: Int {
        territories.filter { $0.capturedBy == "defenders" }.count
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
                    timeRemaining: "BATTLE",
                    status: coup.status,
                    userSide: coup.userSide,
                    challengerStats: challengerStats,
                    rulerStats: rulerStats,
                    onDismiss: onDismiss
                )
                
                // Battle status card
                battleStatusCard
                
                // User status (cooldown / injury)
                if coup.userSide != nil {
                    userStatusCard
                }
                
                // Territory cards
                territoriesSection
                
                // Win condition info
                winConditionCard
            }
            .padding(.horizontal, KingdomTheme.Spacing.medium)
            .padding(.vertical, KingdomTheme.Spacing.medium)
        }
        .parchmentBackground()
        .onAppear {
            syncTimersFromServer()
            startTimer()
        }
        .onChange(of: coup.battleCooldownSeconds) { _, newValue in
            if let newValue = newValue, newValue > localCooldownSeconds {
                localCooldownSeconds = newValue
            }
        }
        .onChange(of: coup.injuryExpiresSeconds) { _, newValue in
            if let newValue = newValue, newValue > localInjurySeconds {
                localInjurySeconds = newValue
            }
        }
    }
    
    // MARK: - Battle Status Card
    
    private var battleStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonDanger,
                    cornerRadius: 12,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("BATTLE IN PROGRESS")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 12) {
                    // Attacker captures
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                        Text("Coupers: \(capturedByAttackers)/3")
                            .font(FontStyles.labelBadge)
                    }
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    
                    // Defender captures
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                        Text("Crown: \(capturedByDefenders)/3")
                            .font(FontStyles.labelBadge)
                    }
                    .foregroundColor(KingdomTheme.Colors.royalBlue)
                }
            }
            
            Spacer()
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - User Status Card
    
    private var userStatusCard: some View {
        let isAttacker = coup.userSide == "attackers"
        let sideColor = isAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
        let sideIcon = isAttacker ? "figure.fencing" : "shield.fill"
        let sideName = isAttacker ? "COUPERS" : "CROWN"
        
        return VStack(spacing: 10) {
            // Your side
            HStack(spacing: 10) {
                Image(systemName: sideIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(sideColor)
                
                Text("You are fighting for \(sideName)")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Divider()
            
            // Status row - uses LOCAL timers that tick down
            HStack(spacing: 16) {
                if displayCooldownSeconds > 0 {
                    // On cooldown
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("COOLDOWN")
                                .font(FontStyles.labelBadge)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            Text(formatTime(displayCooldownSeconds))
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .monospacedDigit()
                        }
                    }
                } else if displayInjurySeconds > 0 {
                    // Injured
                    HStack(spacing: 6) {
                        Image(systemName: "bandage.fill")
                            .font(.system(size: 14))
                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("INJURED")
                                .font(FontStyles.labelBadge)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                            Text(formatTime(displayInjurySeconds))
                                .font(FontStyles.labelBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .monospacedDigit()
                        }
                    }
                } else {
                    // Ready
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        
                        Text("READY TO FIGHT")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    }
                }
                
                Spacer()
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Territories Section
    
    private var territoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("TERRITORIES")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(1)
            }
            .padding(.top, 4)
            
            // Sort: Throne Room first, then others
            let sortedTerritories = territories.sorted { t1, t2 in
                if t1.name == "throne_room" { return true }
                if t2.name == "throne_room" { return false }
                return t1.name < t2.name
            }
            
            ForEach(sortedTerritories) { territory in
                CoupTerritoryCard(
                    territory: territory,
                    userSide: coup.userSide,
                    canFight: canFight && !territory.isCaptured,
                    onFight: { onFight(territory.name) }
                )
            }
        }
    }
    
    // MARK: - Win Condition Card
    
    private var winConditionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.imperialGold)
                Text("WIN CONDITION")
                    .font(FontStyles.labelBadge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .tracking(1)
            }
            
            Text("Capture 2 of 3 territories to win the coup!")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
    }
    
    // MARK: - Timer
    
    private func syncTimersFromServer() {
        localCooldownSeconds = coup.battleCooldownSeconds ?? 0
        localInjurySeconds = coup.injuryExpiresSeconds ?? 0
    }
    
    private func startTimer() {
        guard !timerActive else { return }
        timerActive = true
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Tick down local counters
            if localCooldownSeconds > 0 {
                localCooldownSeconds -= 1
            }
            if localInjurySeconds > 0 {
                localInjurySeconds -= 1
            }
        }
    }
}

// MARK: - Fight Result Sheet

struct FightResultSheet: View {
    let result: CoupFightResponse
    let userIsAttacker: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Outcome icon
                    outcomeHeader
                    
                    // Message
                    Text(result.message)
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Roll results
                    rollResultsSection
                    
                    // Bar movement
                    if result.bestOutcome != "miss" {
                        barMovementSection
                    }
                    
                    // Territory status
                    territorySummary
                }
                .padding()
            }
            .parchmentBackground()
            .navigationTitle("Battle Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
            .parchmentNavigationBar()
        }
    }
    
    private var outcomeHeader: some View {
        let (icon, color, label) = outcomeDisplay
        
        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .brutalistBadge(
                    backgroundColor: color,
                    cornerRadius: 20,
                    shadowOffset: 4,
                    borderWidth: 3
                )
            
            Text(label)
                .font(FontStyles.headingLarge)
                .foregroundColor(color)
        }
    }
    
    private var outcomeDisplay: (String, Color, String) {
        switch result.bestOutcome {
        case "injure":
            return ("flame.fill", KingdomTheme.Colors.imperialGold, "CRITICAL STRIKE!")
        case "hit":
            return ("bolt.fill", KingdomTheme.Colors.buttonSuccess, "DIRECT HIT!")
        default:
            return ("xmark", KingdomTheme.Colors.inkMedium, "MISSED")
        }
    }
    
    private var rollResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROLLS (\(result.rollCount))")
                .font(FontStyles.labelBadge)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 6) {
                ForEach(result.rolls) { roll in
                    rollBadge(roll: roll)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func rollBadge(roll: CoupRollResult) -> some View {
        let (icon, color) = rollDisplay(roll)
        
        return Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
    
    private func rollDisplay(_ roll: CoupRollResult) -> (String, Color) {
        switch roll.outcome {
        case "injure":
            return ("flame.fill", KingdomTheme.Colors.imperialGold)
        case "hit":
            return ("checkmark", KingdomTheme.Colors.buttonSuccess)
        default:
            return ("xmark", KingdomTheme.Colors.inkLight)
        }
    }
    
    private var barMovementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BAR MOVEMENT")
                .font(FontStyles.labelBadge)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("Before")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Text(String(format: "%.1f", result.barBefore))
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                
                VStack(spacing: 2) {
                    Text("After")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Text(String(format: "%.1f", result.barAfter))
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Push")
                        .font(FontStyles.labelBadge)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Text(String(format: "+%.2f", result.pushAmount))
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var territorySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: result.territory.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(result.territory.displayName.uppercased())
                    .font(FontStyles.labelBold)
            }
            .foregroundColor(KingdomTheme.Colors.inkDark)
            
            TugOfWarBar(
                value: result.territory.controlBar,
                isCaptured: result.territory.isCaptured,
                capturedBy: result.territory.capturedBy,
                userIsAttacker: userIsAttacker
            )
            
            if result.territory.isCaptured {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                    Text("Captured by \(result.territory.capturedBy ?? "")!")
                }
                .font(FontStyles.labelSmall)
                .foregroundColor(result.territory.capturedBy == "attackers" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
            }
        }
        .padding(12)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

// MARK: - Preview

#Preview {
    CoupBattleView(
        coup: CoupEventResponse(
            id: 1,
            kingdomId: "test",
            kingdomName: "San Francisco",
            initiatorId: 123,
            initiatorName: "John the Bold",
            initiatorStats: nil,
            rulerId: 200,
            rulerName: "King Marcus",
            rulerStats: nil,
            status: "battle",
            startTime: "2024-01-01T00:00:00Z",
            pledgeEndTime: "2024-01-01T12:00:00Z",
            battleEndTime: nil,
            timeRemainingSeconds: 0,
            attackers: [],
            defenders: [],
            attackerCount: 5,
            defenderCount: 3,
            userSide: "attackers",
            canPledge: false,
            territories: [
                CoupTerritory(name: "throne_room", displayName: "Throne Room", icon: "building.columns.fill", controlBar: 50.0, capturedBy: nil, capturedAt: nil),
                CoupTerritory(name: "coupers_territory", displayName: "Coupers Territory", icon: "figure.fencing", controlBar: 25.0, capturedBy: nil, capturedAt: nil),
                CoupTerritory(name: "crowns_territory", displayName: "Crowns Territory", icon: "crown.fill", controlBar: 75.0, capturedBy: nil, capturedAt: nil),
            ],
            battleCooldownSeconds: 0,
            isInjured: false,
            injuryExpiresSeconds: 0,
            isResolved: false,
            attackerVictory: nil,
            resolvedAt: nil,
            winnerSide: nil
        ),
        onDismiss: {},
        onFight: { _ in }
    )
}
