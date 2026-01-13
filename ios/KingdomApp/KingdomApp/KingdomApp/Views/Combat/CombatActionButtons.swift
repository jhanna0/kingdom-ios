import SwiftUI

// MARK: - Combat Action Buttons
/// Reusable Roll + Resolve button pair for all combat types

struct CombatActionButtons: View {
    /// Can the user roll again?
    let canRoll: Bool
    
    /// Can the user resolve/finalize?
    let canResolve: Bool
    
    /// Is a roll currently in progress?
    let isRolling: Bool
    
    /// Is resolution in progress?
    let isResolving: Bool
    
    /// Label for roll button
    var rollLabel: String = "Roll"
    
    /// Label for resolve button
    var resolveLabel: String = "Resolve"
    
    /// Icon for roll button
    var rollIcon: String = "dice.fill"
    
    /// Icon for resolve button
    var resolveIcon: String = "checkmark.circle.fill"
    
    /// Color theme
    var accentColor: Color = KingdomTheme.Colors.royalBlue
    
    /// Callbacks
    var onRoll: () -> Void
    var onResolve: () -> Void
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Roll button
            Button {
                onRoll()
            } label: {
                HStack {
                    if isRolling {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: rollIcon)
                    }
                    Text(isRolling ? "Rolling..." : rollLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(
                backgroundColor: canRoll && !isRolling ? accentColor.opacity(0.8) : KingdomTheme.Colors.disabled,
                foregroundColor: .white,
                fullWidth: true
            ))
            .disabled(!canRoll || isRolling)
            
            // Resolve button
            Button {
                onResolve()
            } label: {
                HStack {
                    if isResolving {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: resolveIcon)
                    }
                    Text(isResolving ? "..." : resolveLabel)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(
                backgroundColor: canResolve && !isResolving ? accentColor : KingdomTheme.Colors.disabled,
                foregroundColor: .white,
                fullWidth: true
            ))
            .disabled(!canResolve || isResolving)
        }
    }
}

// MARK: - Single Action Button
/// For simpler flows that only need one action

struct CombatSingleButton: View {
    let label: String
    let icon: String
    let isEnabled: Bool
    let isLoading: Bool
    var accentColor: Color = KingdomTheme.Colors.royalBlue
    var onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                    Text(label)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.brutalist(
            backgroundColor: isEnabled && !isLoading ? accentColor : KingdomTheme.Colors.disabled,
            foregroundColor: .white,
            fullWidth: true
        ))
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Attack Button (for turn-based)
/// Specialized button for "your turn" vs "waiting" states

struct TurnBasedAttackButton: View {
    let isYourTurn: Bool
    let hitChance: Int?
    let isAttacking: Bool
    var onAttack: () -> Void
    
    var body: some View {
        Button {
            onAttack()
        } label: {
            VStack(spacing: 4) {
                HStack {
                    if isAttacking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "figure.fencing")
                        Text(isYourTurn ? "ATTACK!" : "Opponent's Turn...")
                    }
                }
                .font(FontStyles.headingMedium)
                
                if isYourTurn, let chance = hitChance {
                    Text("\(chance)% hit chance")
                        .font(FontStyles.labelTiny)
                        .opacity(0.8)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(isYourTurn ? KingdomTheme.Colors.royalCrimson : KingdomTheme.Colors.inkLight)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .disabled(!isYourTurn || isAttacking)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        CombatActionButtons(
            canRoll: true,
            canResolve: false,
            isRolling: false,
            isResolving: false,
            rollLabel: "Swing!",
            resolveLabel: "Push!",
            rollIcon: "figure.fencing",
            onRoll: {},
            onResolve: {}
        )
        
        CombatActionButtons(
            canRoll: false,
            canResolve: true,
            isRolling: false,
            isResolving: false,
            accentColor: .red,
            onRoll: {},
            onResolve: {}
        )
        
        TurnBasedAttackButton(
            isYourTurn: true,
            hitChance: 65,
            isAttacking: false,
            onAttack: {}
        )
        
        TurnBasedAttackButton(
            isYourTurn: false,
            hitChance: nil,
            isAttacking: false,
            onAttack: {}
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
