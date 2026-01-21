import Foundation
import SwiftUI

// MARK: - March Event Types

/// Types of events that can spawn during the march
enum MarchEventType: String, CaseIterable {
    case brokenBridge = "broken_bridge"
    case enemySquad = "enemy_squad"
    case ambush = "ambush"
    case lostSoldiers = "lost_soldiers"
    case divineShrine = "divine_shrine"
    case spyIntel = "spy_intel"
    case ancientText = "ancient_text"
    case tradeCaravan = "trade_caravan"
    case wisdomStone = "wisdom_stone"
    
    /// The skill type used for this event
    var skillType: String {
        switch self {
        case .brokenBridge: return "building"
        case .enemySquad: return "attack"
        case .ambush: return "defense"
        case .lostSoldiers: return "leadership"
        case .divineShrine: return "faith"
        case .spyIntel: return "intelligence"
        case .ancientText: return "science"
        case .tradeCaravan: return "merchant"
        case .wisdomStone: return "philosophy"
        }
    }
    
    /// Display name for the event
    var displayName: String {
        switch self {
        case .brokenBridge: return "Broken Bridge"
        case .enemySquad: return "Enemy Squad"
        case .ambush: return "Ambush!"
        case .lostSoldiers: return "Lost Soldiers"
        case .divineShrine: return "Divine Shrine"
        case .spyIntel: return "Spy Intel"
        case .ancientText: return "Ancient Text"
        case .tradeCaravan: return "Trade Caravan"
        case .wisdomStone: return "Wisdom Stone"
        }
    }
    
    /// Icon for the event
    var icon: String {
        switch self {
        case .brokenBridge: return "hammer.fill"
        case .enemySquad: return "bolt.fill"
        case .ambush: return "shield.fill"
        case .lostSoldiers: return "crown.fill"
        case .divineShrine: return "hands.sparkles.fill"
        case .spyIntel: return "eye.fill"
        case .ancientText: return "flask.fill"
        case .tradeCaravan: return "dollarsign.circle.fill"
        case .wisdomStone: return "book.fill"
        }
    }
    
    /// Action button text
    var actionText: String {
        switch self {
        case .brokenBridge: return "REPAIR"
        case .enemySquad: return "ATTACK"
        case .ambush: return "DEFEND"
        case .lostSoldiers: return "RALLY"
        case .divineShrine: return "PRAY"
        case .spyIntel: return "SCOUT"
        case .ancientText: return "STUDY"
        case .tradeCaravan: return "TRADE"
        case .wisdomStone: return "MEDITATE"
        }
    }
    
    /// Color for the event (uses skill colors)
    var color: Color {
        SkillConfig.get(skillType).color
    }
    
    /// Success message
    var successMessage: String {
        switch self {
        case .brokenBridge: return "Bridge repaired! Safe crossing."
        case .enemySquad: return "Enemies defeated! Soldiers join your army."
        case .ambush: return "Ambush blocked! No casualties."
        case .lostSoldiers: return "Soldiers rallied to your banner!"
        case .divineShrine: return "The gods smile upon you!"
        case .spyIntel: return "Enemy movements revealed!"
        case .ancientText: return "Ancient knowledge gained!"
        case .tradeCaravan: return "Profitable trade completed!"
        case .wisdomStone: return "Enlightenment achieved!"
        }
    }
    
    /// Failure message
    var failureMessage: String {
        switch self {
        case .brokenBridge: return "Bridge collapsed! Soldiers lost."
        case .enemySquad: return "Retreat! Soldiers wounded."
        case .ambush: return "Ambush succeeded! Casualties taken."
        case .lostSoldiers: return "Soldiers scattered further."
        case .divineShrine: return "The gods are silent."
        case .spyIntel: return "Intel unclear."
        case .ancientText: return "Text remains cryptic."
        case .tradeCaravan: return "Trade failed."
        case .wisdomStone: return "Mind wanders."
        }
    }
    
    /// Critical success message
    var criticalMessage: String {
        switch self {
        case .brokenBridge: return "MASTERWORK! Bridge fortified!"
        case .enemySquad: return "DEVASTATING! Enemy routed!"
        case .ambush: return "COUNTER-ATTACK! Ambushers flee!"
        case .lostSoldiers: return "INSPIRING! Double soldiers join!"
        case .divineShrine: return "MIRACLE! Divine blessing!"
        case .spyIntel: return "BRILLIANT! All secrets revealed!"
        case .ancientText: return "EUREKA! Breakthrough discovery!"
        case .tradeCaravan: return "JACKPOT! Treasure found!"
        case .wisdomStone: return "TRANSCENDENCE! Ultimate wisdom!"
        }
    }
    
    /// Base soldiers gained on success
    var baseSoldiersGained: Int {
        switch self {
        case .brokenBridge: return 0  // No gain, just safe passage
        case .enemySquad: return 8
        case .ambush: return 0  // No gain, just protection
        case .lostSoldiers: return 12
        case .divineShrine: return 5
        case .spyIntel: return 3
        case .ancientText: return 2
        case .tradeCaravan: return 4
        case .wisdomStone: return 3
        }
    }
    
    /// Soldiers lost on failure
    var soldiersLostOnFail: Int {
        switch self {
        case .brokenBridge: return 5
        case .enemySquad: return 3
        case .ambush: return 8
        case .lostSoldiers: return 2
        case .divineShrine: return 0
        case .spyIntel: return 0
        case .ancientText: return 0
        case .tradeCaravan: return 0
        case .wisdomStone: return 0
        }
    }
}

// MARK: - March Event

/// A single event in the march
struct MarchEvent: Identifiable {
    let id = UUID()
    let type: MarchEventType
    let distance: Int  // Distance at which this event triggers
    
    /// Calculate hit chance based on skill level
    func hitChance(forSkillLevel level: Int) -> Int {
        // Base 30% + 10% per skill level, capped at 90%
        let base = 30
        let perLevel = 10
        return min(90, base + (level * perLevel))
    }
    
    /// Calculate critical chance (10% of hit section)
    func criticalChance(forSkillLevel level: Int) -> Int {
        return hitChance(forSkillLevel: level) / 10
    }
}

// MARK: - Roll Outcome

enum MarchRollOutcome {
    case miss
    case hit
    case critical
    
    var displayName: String {
        switch self {
        case .miss: return "MISS"
        case .hit: return "HIT"
        case .critical: return "CRITICAL"
        }
    }
    
    var color: Color {
        switch self {
        case .miss: return KingdomTheme.Colors.inkMedium
        case .hit: return KingdomTheme.Colors.buttonSuccess
        case .critical: return KingdomTheme.Colors.imperialGold
        }
    }
}

// MARK: - Wave State

/// State for a single wave
struct MarchWaveState {
    var waveNumber: Int = 1
    var armySize: Int = 10
    var playerHP: Int = 100
    var distance: Int = 0
    var eventsCompleted: Int = 0
    var isRunning: Bool = false
    
    /// Enemy army size scales with wave number
    var enemyArmySize: Int {
        return 20 + (waveNumber * 15)
    }
    
    /// Distance needed to reach boss
    var bossDistance: Int {
        return 500 + (waveNumber * 100)
    }
    
    /// Progress toward boss (0-1)
    var progress: Double {
        return min(1.0, Double(distance) / Double(bossDistance))
    }
}

// MARK: - Boss Battle State

struct MarchBossBattleState {
    var playerArmySize: Int
    var enemyArmySize: Int
    var controlBar: Double = 50.0  // 0 = enemy wins, 100 = player wins
    var roundNumber: Int = 0
    var isComplete: Bool = false
    var playerWon: Bool = false
    
    /// Player's push value per hit (scales inversely with army size)
    var playerPushPerHit: Double {
        return 1.0 / pow(Double(max(1, playerArmySize)), 0.5)
    }
    
    /// Enemy's push value per hit
    var enemyPushPerHit: Double {
        return 1.0 / pow(Double(max(1, enemyArmySize)), 0.5)
    }
}

// MARK: - Game State

enum MarchGamePhase {
    case ready           // Not started
    case running         // Auto-running, events spawning
    case eventReady      // Event reached, waiting for tap to engage
    case eventActive     // Event popup shown, waiting for player
    case rolling         // Roll animation playing
    case eventResult     // Roll outcome shown before resuming
    case bossBattle      // Fighting the wave boss
    case bossRolling     // Boss battle roll in progress
    case waveComplete    // Wave won, continue to next
    case gameOver        // Lost
}

// MARK: - Boss Battle Actions

enum MarchBossAction: CaseIterable {
    case strike
    case hold
    case rally
    
    var title: String {
        switch self {
        case .strike: return "STRIKE"
        case .hold: return "HOLD"
        case .rally: return "RALLY"
        }
    }
    
    var subtitle: String {
        switch self {
        case .strike: return "Press the attack"
        case .hold: return "Reduce enemy push"
        case .rally: return "Boost your line"
        }
    }
    
    var icon: String {
        switch self {
        case .strike: return "bolt.fill"
        case .hold: return "shield.fill"
        case .rally: return "flag.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .strike: return KingdomTheme.Colors.buttonDanger
        case .hold: return KingdomTheme.Colors.buttonWarning
        case .rally: return KingdomTheme.Colors.buttonSuccess
        }
    }
}

// MARK: - Faith Blessing (Special random effect)

enum FaithBlessing: CaseIterable {
    case heal
    case smite
    case shield
    case inspire
    
    var displayName: String {
        switch self {
        case .heal: return "Divine Heal"
        case .smite: return "Holy Smite"
        case .shield: return "Sacred Shield"
        case .inspire: return "Inspiring Light"
        }
    }
    
    var description: String {
        switch self {
        case .heal: return "Restore 20 HP"
        case .smite: return "Enemy loses 10 soldiers"
        case .shield: return "Block next failure"
        case .inspire: return "Double next soldier gain"
        }
    }
    
    var icon: String {
        switch self {
        case .heal: return "heart.fill"
        case .smite: return "bolt.horizontal.fill"
        case .shield: return "shield.checkered"
        case .inspire: return "sparkles"
        }
    }
}
