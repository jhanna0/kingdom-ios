import Foundation
import SwiftUI
import Combine

/// ViewModel for the March endless runner minigame
@MainActor
class MarchViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var phase: MarchGamePhase = .ready
    @Published var wave: MarchWaveState = MarchWaveState()
    @Published var bossBattle: MarchBossBattleState?
    
    // Current event
    @Published var currentEvent: MarchEvent?
    @Published var pendingEvent: MarchEvent?
    @Published var lastRollOutcome: MarchRollOutcome?
    @Published var lastRollValue: Int = 0
    @Published var rollMarkerValue: Double = 0
    @Published var isRolling: Bool = false
    @Published var canContinueAfterResult: Bool = false
    @Published var requiresManualContinue: Bool = false
    
    // Active buffs
    @Published var hasShieldBuff: Bool = false  // From faith - blocks next failure
    @Published var hasInspireBuff: Bool = false // From faith - doubles next gain
    @Published var faithBlessing: FaithBlessing?  // Current blessing to display
    
    // High score
    @Published var highestWave: Int = 1
    @Published var highestDistance: Int = 0
    
    // Boss battle animation
    @Published var bossRollValue: Int = 0
    @Published var isBossRolling: Bool = false
    @Published var lastBossAction: MarchBossAction = .strike
    @Published var bossActionMessage: String = ""
    
    // MARK: - Player Reference
    
    weak var player: Player?
    
    // MARK: - Game Timer
    
    private var gameTimer: Timer?
    private var lastEventDistance: Int = 0
    private let eventSpacing: Int = 150  // Distance between events (increased for visibility)
    
    // MARK: - Upcoming Events Queue
    
    private var upcomingEvents: [MarchEvent] = []
    
    // MARK: - Init
    
    init(player: Player? = nil) {
        self.player = player
        loadHighScores()
    }
    
    // MARK: - Game Control
    
    func startGame() {
        // Reset state
        wave = MarchWaveState()
        wave.waveNumber = 1
        wave.armySize = 10
        wave.playerHP = 100
        wave.distance = 0
        wave.isRunning = true
        
        currentEvent = nil
        pendingEvent = nil
        lastRollOutcome = nil
        lastRollValue = 0
        rollMarkerValue = 0
        bossBattle = nil
        hasShieldBuff = false
        hasInspireBuff = false
        faithBlessing = nil
        lastEventDistance = 0
        canContinueAfterResult = false
        requiresManualContinue = false
        
        // Generate initial events
        generateUpcomingEvents()
        
        // Start running
        phase = .running
        startRunningTimer()
    }
    
    func pauseGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        wave.isRunning = false
    }
    
    func resumeGame() {
        guard phase == .running else { return }
        wave.isRunning = true
        startRunningTimer()
    }
    
    private func startRunningTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRunning()
            }
        }
    }
    
    private func updateRunning() {
        guard phase == .running, wave.isRunning else { return }
        
        // Move forward (slower pace for visibility)
        wave.distance += 1
        
        // Check for events
        checkForEvents()
        
        // Check for boss
        if wave.distance >= wave.bossDistance {
            triggerBossBattle()
        }
    }
    
    // MARK: - Event System
    
    private func generateUpcomingEvents() {
        upcomingEvents.removeAll()
        
        // Generate events for this wave
        let numEvents = 4 + wave.waveNumber  // More events in later waves
        var nextDistance = eventSpacing
        
        for _ in 0..<numEvents {
            // Pick a random event type
            let eventType = MarchEventType.allCases.randomElement()!
            let event = MarchEvent(type: eventType, distance: nextDistance)
            upcomingEvents.append(event)
            nextDistance += eventSpacing + Int.random(in: 0...30)
        }
    }
    
    private func checkForEvents() {
        guard pendingEvent == nil else { return }

        // Check if we've reached the next event
        if let nextEvent = upcomingEvents.first, wave.distance >= nextEvent.distance {
            upcomingEvents.removeFirst()
            triggerEvent(nextEvent)
        }
    }
    
    private func triggerEvent(_ event: MarchEvent) {
        pauseGame()
        pendingEvent = event
        currentEvent = nil
        lastRollOutcome = nil
        lastRollValue = 0
        rollMarkerValue = 0
        canContinueAfterResult = false
        requiresManualContinue = false
        phase = .eventReady
    }

    func engagePendingEvent() {
        guard phase == .eventReady, let event = pendingEvent else { return }
        pendingEvent = nil
        currentEvent = event
        lastRollOutcome = nil
        lastRollValue = 0
        rollMarkerValue = 0
        canContinueAfterResult = false
        requiresManualContinue = false
        phase = .eventActive
    }

    func handleObstacleTap() {
        if phase == .eventReady {
            engagePendingEvent()
            return
        }
        guard phase == .running, wave.isRunning else { return }
        guard pendingEvent == nil, let nextEvent = upcomingEvents.first else { return }

        let distanceToEvent = nextEvent.distance - wave.distance
        let visibleDistance = 120
        guard distanceToEvent <= visibleDistance else { return }

        // Engage early when visible instead of waiting for prompt.
        upcomingEvents.removeFirst()
        pauseGame()
        currentEvent = nextEvent
        lastRollOutcome = nil
        lastRollValue = 0
        canContinueAfterResult = false
        phase = .eventActive
    }
    
    // MARK: - Skill Check
    
    /// Get player's skill level for an event type
    func getSkillLevel(for eventType: MarchEventType) -> Int {
        guard let player = player else { return 1 }
        
        switch eventType.skillType {
        case "attack": return player.attackPower
        case "defense": return player.defensePower
        case "leadership": return player.leadership
        case "building": return player.buildingSkill
        case "intelligence": return player.intelligence
        case "science": return player.science
        case "faith": return player.faith
        case "merchant": return player.skillsData.first(where: { $0.skillType == "merchant" })?.currentTier ?? 1
        case "philosophy": return player.skillsData.first(where: { $0.skillType == "philosophy" })?.currentTier ?? 1
        default: return 1
        }
    }
    
    /// Perform the skill check roll
    func performRoll() async {
        guard let event = currentEvent else { return }
        
        phase = .rolling
        isRolling = true
        
        let skillLevel = getSkillLevel(for: event.type)
        let hitChance = event.hitChance(forSkillLevel: skillLevel)
        let critChance = event.criticalChance(forSkillLevel: skillLevel)
        
        // Final roll
        let finalRoll = Int.random(in: 1...100)

        // Animate roll (Hunt-style sweep)
        var positions = Array(stride(from: 1, through: 100, by: 2))
        if finalRoll < 100 {
            positions.append(contentsOf: stride(from: 98, through: max(1, finalRoll), by: -2))
        }
        if positions.last != finalRoll {
            positions.append(finalRoll)
        }

        for pos in positions {
            lastRollValue = pos
            rollMarkerValue = Double(pos)
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        
        // Determine outcome
        if finalRoll <= critChance {
            lastRollOutcome = .critical
        } else if finalRoll <= hitChance {
            lastRollOutcome = .hit
        } else {
            lastRollOutcome = .miss
        }
        
        isRolling = false
        
        // Small delay before applying result
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Apply result
        applyEventResult()
    }
    
    private func applyEventResult() {
        guard let event = currentEvent, let outcome = lastRollOutcome else { return }
        
        switch outcome {
        case .critical:
            // Double rewards
            var gain = event.type.baseSoldiersGained * 2
            if hasInspireBuff {
                gain *= 2
                hasInspireBuff = false
            }
            wave.armySize += gain
            
            // Special faith handling
            if event.type == .divineShrine {
                applyRandomBlessing()
            }
            
        case .hit:
            // Normal rewards
            var gain = event.type.baseSoldiersGained
            if hasInspireBuff {
                gain *= 2
                hasInspireBuff = false
            }
            wave.armySize += gain
            
            // Special faith handling
            if event.type == .divineShrine {
                applyRandomBlessing()
            }
            
        case .miss:
            // Check for shield buff
            if hasShieldBuff {
                hasShieldBuff = false
                // Blocked by shield, no penalty
            } else {
                // Apply penalty
                let loss = event.type.soldiersLostOnFail
                wave.armySize = max(0, wave.armySize - loss)
                
                // HP damage for certain events
                if event.type == .ambush {
                    wave.playerHP = max(0, wave.playerHP - 15)
                }
            }
        }
        
        wave.eventsCompleted += 1
        
        // Check for game over
        if wave.playerHP <= 0 || wave.armySize <= 0 {
            endGame()
            return
        }
        
        // Show result before continuing
        phase = .eventResult
        canContinueAfterResult = false
        requiresManualContinue = (outcome == .miss)
        Task { @MainActor in
            if requiresManualContinue {
                try? await Task.sleep(nanoseconds: 800_000_000)
                canContinueAfterResult = true
                return
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
            canContinueAfterResult = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            if phase == .eventResult {
                continueAfterEvent()
            }
        }
    }

    func continueAfterEvent() {
        guard phase == .eventResult else { return }
        currentEvent = nil
        faithBlessing = nil
        lastRollOutcome = nil
        lastRollValue = 0
        rollMarkerValue = 0
        canContinueAfterResult = false
        requiresManualContinue = false
        phase = .running
        resumeGame()
    }
    
    private func applyRandomBlessing() {
        let blessing = FaithBlessing.allCases.randomElement()!
        faithBlessing = blessing
        
        switch blessing {
        case .heal:
            wave.playerHP = min(100, wave.playerHP + 20)
        case .smite:
            // Will reduce enemy army in boss battle
            // For now, give bonus soldiers
            wave.armySize += 5
        case .shield:
            hasShieldBuff = true
        case .inspire:
            hasInspireBuff = true
        }
    }
    
    // MARK: - Boss Battle
    
    private func triggerBossBattle() {
        pauseGame()
        
        bossBattle = MarchBossBattleState(
            playerArmySize: wave.armySize,
            enemyArmySize: wave.enemyArmySize
        )
        
        phase = .bossBattle
    }
    
    /// Player taps to fight in boss battle
    func performBossRoll() async {
        await performBossAction(.strike)
    }
    
    /// Player chooses an action each boss round
    func performBossAction(_ action: MarchBossAction) async {
        guard var battle = bossBattle, !battle.isComplete else { return }
        
        phase = .bossRolling
        isBossRolling = true
        lastBossAction = action
        
        // Animate roll (fast, tap-driven)
        for _ in 0..<6 {
            bossRollValue = Int.random(in: 1...100)
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        
        // Calculate battle round
        let playerAttack = bossArmyAttack
        let playerDefense = bossArmyDefense
        let playerLeadership = bossArmyLeadership
        let enemyAttack = 3 + wave.waveNumber
        let enemyDefense = 2 + wave.waveNumber
        
        // Player hits
        let playerHitChance = Double(playerAttack * 9) / Double(playerAttack * 9 + enemyDefense * 20)
        let playerHits = Int(Double(battle.playerArmySize) * playerHitChance * 0.3)
        
        // Enemy hits
        let enemyHitChance = Double(enemyAttack * 9) / Double(enemyAttack * 9 + playerDefense * 20)
        let enemyHits = Int(Double(battle.enemyArmySize) * enemyHitChance * 0.3)
        
        // Action modifiers
        var playerPushMult: Double = 1.0
        var enemyPushMult: Double = 1.0
        var rallyBonusPush: Double = 0
        
        switch action {
        case .strike:
            bossActionMessage = "STRIKE! You press the attack."
        case .hold:
            playerPushMult = 0.85
            enemyPushMult = 0.6
            bossActionMessage = "HOLD THE LINE! Enemy momentum slows."
        case .rally:
            let leadershipBonus = min(20, playerLeadership)
            rallyBonusPush = Double(leadershipBonus) * 0.25
            bossActionMessage = "RALLY! Your troops surge forward."
            battle.playerArmySize += max(1, leadershipBonus / 5)
        }
        
        // Calculate push
        let playerPush = (Double(playerHits) * battle.playerPushPerHit * 2 * playerPushMult) + rallyBonusPush
        let enemyPush = Double(enemyHits) * battle.enemyPushPerHit * 2 * enemyPushMult
        let netPush = playerPush - enemyPush
        
        // Update control bar with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            battle.controlBar = min(100, max(0, battle.controlBar + netPush))
        }
        
        // Injuries
        let playerInjuries = min(battle.playerArmySize, Int(Double(enemyHits) * (action == .hold ? 0.06 : 0.1)))
        let enemyInjuries = min(battle.enemyArmySize, Int(Double(playerHits) * (action == .strike ? 0.12 : 0.1)))
        battle.playerArmySize = max(0, battle.playerArmySize - playerInjuries)
        battle.enemyArmySize = max(0, battle.enemyArmySize - enemyInjuries)
        
        battle.roundNumber += 1
        
        isBossRolling = false
        bossRollValue = Int(battle.controlBar)
        
        // Check for victory/defeat
        if battle.controlBar >= 100 || battle.enemyArmySize <= 0 {
            battle.isComplete = true
            battle.playerWon = true
        } else if battle.controlBar <= 0 || battle.playerArmySize <= 0 {
            battle.isComplete = true
            battle.playerWon = false
        }
        
        bossBattle = battle
        phase = .bossBattle
        
        // Handle completion
        if battle.isComplete {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if battle.playerWon {
                completeWave()
            } else {
                endGame()
            }
        }
    }
    
    private func completeWave() {
        // Update high scores
        if wave.waveNumber > highestWave {
            highestWave = wave.waveNumber
        }
        if wave.distance > highestDistance {
            highestDistance = wave.distance
        }
        saveHighScores()
        
        // Prepare next wave
        phase = .waveComplete
    }
    
    func startNextWave() {
        // Carry over army (with bonus)
        let armyBonus = 5 + wave.waveNumber
        let newArmySize = (bossBattle?.playerArmySize ?? wave.armySize) + armyBonus
        
        wave.waveNumber += 1
        wave.armySize = newArmySize
        wave.playerHP = min(100, wave.playerHP + 20)  // Heal between waves
        wave.distance = 0
        wave.eventsCompleted = 0
        wave.isRunning = true
        
        currentEvent = nil
        pendingEvent = nil
        lastRollOutcome = nil
        lastRollValue = 0
        rollMarkerValue = 0
        bossBattle = nil
        lastEventDistance = 0
        canContinueAfterResult = false
        requiresManualContinue = false
        
        // Generate new events
        generateUpcomingEvents()
        
        // Start running
        phase = .running
        startRunningTimer()
    }
    
    private func endGame() {
        pauseGame()
        
        // Update high scores
        if wave.waveNumber > highestWave {
            highestWave = wave.waveNumber
        }
        if wave.distance > highestDistance {
            highestDistance = wave.distance
        }
        saveHighScores()
        
        phase = .gameOver
    }
    
    // MARK: - High Scores (Local)
    
    private func loadHighScores() {
        highestWave = UserDefaults.standard.integer(forKey: "march_highest_wave")
        highestDistance = UserDefaults.standard.integer(forKey: "march_highest_distance")
        if highestWave == 0 { highestWave = 1 }
    }
    
    private func saveHighScores() {
        UserDefaults.standard.set(highestWave, forKey: "march_highest_wave")
        UserDefaults.standard.set(highestDistance, forKey: "march_highest_distance")
    }
    
    // MARK: - Computed Properties
    
    var currentHitChance: Int {
        guard let event = currentEvent else { return 0 }
        return event.hitChance(forSkillLevel: getSkillLevel(for: event.type))
    }
    
    var currentCritChance: Int {
        guard let event = currentEvent else { return 0 }
        return event.criticalChance(forSkillLevel: getSkillLevel(for: event.type))
    }
    
    var missChance: Int {
        return 100 - currentHitChance
    }
    
    /// Get the next upcoming event for display in the runner view
    var upcomingEventForDisplay: MarchEvent? {
        return pendingEvent ?? upcomingEvents.first
    }
    
    /// Progress of obstacle approaching (0 = just spawned, 1 = arrived)
    var obstacleApproachProgress: CGFloat {
        if pendingEvent != nil {
            return 1
        }
        guard let nextEvent = upcomingEvents.first else { return 0 }
        let distanceToEvent = nextEvent.distance - wave.distance
        let visibleDistance: CGFloat = 120  // Start showing when this close
        
        if distanceToEvent > Int(visibleDistance) {
            return 0
        }
        
        return CGFloat(Int(visibleDistance) - distanceToEvent) / visibleDistance
    }

    var isAwaitingEngagement: Bool {
        return phase == .eventReady && pendingEvent != nil
    }

    // MARK: - Boss Battle Stats

    var bossPlayerAttack: Int {
        player?.attackPower ?? 1
    }

    var bossPlayerDefense: Int {
        player?.defensePower ?? 1
    }

    var bossPlayerLeadership: Int {
        player?.leadership ?? 1
    }

    var bossArmyAttack: Int {
        max(1, bossPlayerAttack + wave.armySize / 4)
    }

    var bossArmyDefense: Int {
        max(1, bossPlayerDefense + wave.armySize / 5)
    }

    var bossArmyLeadership: Int {
        max(1, bossPlayerLeadership + wave.armySize / 6)
    }
}
