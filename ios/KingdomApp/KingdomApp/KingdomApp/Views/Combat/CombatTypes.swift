import SwiftUI
import Combine

// MARK: - Combat Types
/// Shared types and protocols for unified combat system

/// Protocol for combat view models
protocol CombatViewModelProtocol: ObservableObject {
    /// Current bar value (0-100)
    var barValue: Double { get }
    
    /// Whether user can roll
    var canRoll: Bool { get }
    
    /// Whether user can resolve/finalize
    var canResolve: Bool { get }
    
    /// Current state
    var isRolling: Bool { get }
    var isResolving: Bool { get }
    var isComplete: Bool { get }
    
    /// Roll history
    var rollHistory: [RollHistoryItem] { get }
    
    /// Last roll result
    var lastOutcome: CombatOutcome? { get }
    var lastRollValue: Int? { get }
    var lastPushAmount: Double? { get }
    
    /// Actions
    func roll() async
    func resolve() async
}

// MARK: - Combat Configuration
/// Configuration for different combat types

struct CombatConfig {
    let leftLabel: String
    let rightLabel: String
    let leftColor: Color
    let rightColor: Color
    let rollButtonLabel: String
    let rollButtonIcon: String
    let resolveButtonLabel: String
    let resolveButtonIcon: String
    let critLabel: String
    
    // Presets
    static let battle = CombatConfig(
        leftLabel: "ATTACKERS",
        rightLabel: "DEFENDERS",
        leftColor: KingdomTheme.Colors.buttonDanger,
        rightColor: KingdomTheme.Colors.royalBlue,
        rollButtonLabel: "Swing!",
        rollButtonIcon: "figure.fencing",
        resolveButtonLabel: "Push!",
        resolveButtonIcon: "arrow.right.circle.fill",
        critLabel: "INJURE"
    )
    
    static let duel = CombatConfig(
        leftLabel: "You",
        rightLabel: "Opponent",
        leftColor: KingdomTheme.Colors.royalBlue,
        rightColor: KingdomTheme.Colors.royalCrimson,
        rollButtonLabel: "Attack!",
        rollButtonIcon: "figure.fencing",
        resolveButtonLabel: "End Turn",
        resolveButtonIcon: "checkmark.circle.fill",
        critLabel: "CRIT"
    )
    
    static let hunt = CombatConfig(
        leftLabel: "Hunters",
        rightLabel: "Prey",
        leftColor: KingdomTheme.Colors.buttonSuccess,
        rightColor: KingdomTheme.Colors.buttonWarning,
        rollButtonLabel: "Strike!",
        rollButtonIcon: "scope",
        resolveButtonLabel: "Finish",
        resolveButtonIcon: "checkmark.circle.fill",
        critLabel: "CRIT"
    )
}

// MARK: - Combat Player Info
/// Represents a player in combat

struct CombatPlayer {
    let id: Int
    let name: String
    let attack: Int
    let defense: Int
    let level: Int
    let isCurrentUser: Bool
    
    var displayName: String {
        isCurrentUser ? "You" : name
    }
}

// MARK: - Combat State
/// Current state of a combat encounter

enum CombatState: Equatable {
    case waiting       // Waiting for opponent
    case ready         // Both sides ready
    case active        // Combat in progress
    case rolling       // Roll animation
    case resolving     // Resolving outcome
    case victory(side: String)
    case defeat(side: String)
    
    var isInteractive: Bool {
        switch self {
        case .active: return true
        default: return false
        }
    }
}

// MARK: - Combat View
/// Unified combat view that works for battles, duels, and hunts

struct UnifiedCombatView<ViewModel: CombatViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    let config: CombatConfig
    
    /// Optional player info display
    var leftPlayer: CombatPlayer? = nil
    var rightPlayer: CombatPlayer? = nil
    
    /// Probability display (optional)
    var missChance: Int = 40
    var hitChance: Int = 50
    
    @State private var animatedBarValue: Double = 50
    
    var body: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Combat bar
            CombatBar(
                value: viewModel.barValue,
                animatedValue: $animatedBarValue,
                leftLabel: config.leftLabel,
                rightLabel: config.rightLabel,
                leftColor: config.leftColor,
                rightColor: config.rightColor
            )
            .onChange(of: viewModel.barValue) { newValue in
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedBarValue = newValue
                }
            }
            
            // Probability bar
            RollProbabilityBar(
                missChance: missChance,
                hitChance: hitChance,
                rollMarkerValue: viewModel.lastRollValue.map { Double($0) },
                isAnimating: viewModel.isRolling,
                critLabel: config.critLabel
            )
            
            // Last roll result
            if let outcome = viewModel.lastOutcome {
                RollResultDisplay(
                    outcome: outcome,
                    rollValue: viewModel.lastRollValue,
                    message: nil,
                    pushAmount: viewModel.lastPushAmount
                )
            }
            
            // Roll history
            if !viewModel.rollHistory.isEmpty {
                RollHistoryRow(results: viewModel.rollHistory)
                    .background(KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(10)
            }
            
            Spacer()
            
            // Action buttons
            CombatActionButtons(
                canRoll: viewModel.canRoll,
                canResolve: viewModel.canResolve,
                isRolling: viewModel.isRolling,
                isResolving: viewModel.isResolving,
                rollLabel: config.rollButtonLabel,
                resolveLabel: config.resolveButtonLabel,
                rollIcon: config.rollButtonIcon,
                resolveIcon: config.resolveButtonIcon,
                accentColor: config.leftColor,
                onRoll: { Task { await viewModel.roll() } },
                onResolve: { Task { await viewModel.resolve() } }
            )
        }
        .padding()
        .onAppear {
            animatedBarValue = viewModel.barValue
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
class PreviewCombatViewModel: CombatViewModelProtocol {
    @Published var barValue: Double = 45
    @Published var canRoll: Bool = true
    @Published var canResolve: Bool = false
    @Published var isRolling: Bool = false
    @Published var isResolving: Bool = false
    @Published var isComplete: Bool = false
    @Published var rollHistory: [RollHistoryItem] = [
        RollHistoryItem(outcome: .hit, rollValue: 65, isSuccess: true),
        RollHistoryItem(outcome: .miss, rollValue: 22, isSuccess: false),
    ]
    @Published var lastOutcome: CombatOutcome? = .hit
    @Published var lastRollValue: Int? = 65
    @Published var lastPushAmount: Double? = 10
    
    func roll() async {}
    func resolve() async {}
}

#Preview {
    UnifiedCombatView(
        viewModel: PreviewCombatViewModel(),
        config: .duel
    )
    .background(KingdomTheme.Colors.parchment)
}
#endif
