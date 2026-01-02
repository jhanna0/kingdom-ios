import SwiftUI

struct MilitaryStrengthCard: View {
    let strength: MilitaryStrength?
    let kingdom: Kingdom
    let player: Player
    let onGatherIntel: () -> Void
    
    @State private var isGathering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: strength?.isRuler == true ? "shield.fill" : "eye.fill")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .brutalistBadge(
                        backgroundColor: strength?.isRuler == true ? KingdomTheme.Colors.gold : KingdomTheme.Colors.buttonWarning,
                        cornerRadius: 8,
                        shadowOffset: 2,
                        borderWidth: 1.5
                    )
                Text(strength?.isRuler == true ? "Military Strength" : "Intelligence Report")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                
                // Intel age indicator
                if let strength = strength, strength.hasIntel, let _ = strength.intelAgeDays {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(FontStyles.iconMini)
                        Text(strength.intelAgeText)
                            .font(FontStyles.labelTiny)
                    }
                    .foregroundColor(strength.isIntelExpiring ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkLight)
                }
            }
            
            // Show data based on what we know
            if let strength = strength {
                if strength.isRuler {
                    // Full details for kingdoms you rule
                    ownKingdomView(strength)
                } else if strength.hasIntel {
                    // Intel we've gathered
                    enemyIntelView(strength)
                } else {
                    // No intel - just walls
                    noIntelView(strength)
                }
            } else {
                // Loading state
                HStack {
                    ProgressView()
                    Text("Loading intelligence...")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Own Kingdom View
    
    private func ownKingdomView(_ strength: MilitaryStrength) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            statRow(
                icon: "building.2.fill",
                label: "Walls",
                value: "Level \(strength.wallLevel) (+\(strength.wallLevel * 5) defense)"
            )
            
            if let attack = strength.totalAttack {
                statRow(
                    icon: "bolt.fill",
                    label: "Total Attack",
                    value: "\(attack)"
                )
            }
            
            if let defense = strength.totalDefenseWithWalls {
                statRow(
                    icon: "shield.fill",
                    label: "Total Defense",
                    value: "\(defense)"
                )
            }
            
            if let citizens = strength.activeCitizens {
                statRow(
                    icon: "person.3.fill",
                    label: "Active Citizens",
                    value: "\(citizens)"
                )
            }
            
            if let patrolStrength = strength.patrolStrength {
                statRow(
                    icon: "eye.fill",
                    label: "Currently Patrolling",
                    value: "\(patrolStrength)"
                )
            }
        }
    }
    
    // MARK: - Enemy Kingdom with Intel
    
    private func enemyIntelView(_ strength: MilitaryStrength) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Intel source
            if let gatheredBy = strength.gatheredBy {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(FontStyles.iconMini)
                    Text("Intel by \(gatheredBy)")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .padding(.bottom, 4)
            }
            
            // Always show walls
            statRow(
                icon: "building.2.fill",
                label: "Walls",
                value: "Level \(strength.wallLevel)"
            )
            
            // Level 3+: Population
            if let level = strength.intelLevel, level >= 3 {
                if let population = strength.population {
                    statRow(
                        icon: "person.3.fill",
                        label: "Population",
                        value: "~\(population)"
                    )
                }
                
                if let citizens = strength.activeCitizens {
                    statRow(
                        icon: "person.2.circle.fill",
                        label: "Active Citizens",
                        value: "\(citizens)"
                    )
                }
                
                if let patrolStrength = strength.patrolStrength {
                    statRow(
                        icon: "eye.fill",
                        label: "Currently Patrolling",
                        value: "\(patrolStrength)"
                    )
                }
            }
            
            // Level 5+: Military stats
            if let level = strength.intelLevel, level >= 5 {
                if let attack = strength.totalAttack {
                    statRow(
                        icon: "bolt.fill",
                        label: "Attack Power",
                        value: "\(attack)"
                    )
                }
                
                if let defense = strength.totalDefenseWithWalls {
                    statRow(
                        icon: "shield.fill",
                        label: "Total Defense",
                        value: "\(defense)"
                    )
                }
                
                // Combat assessment
                HStack(spacing: 4) {
                    Image(systemName: strength.canDefeatInAttack ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(strength.canDefeatInAttack ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                    Text(strength.canDefeatInAttack ? "We could win an attack!" : "They're too strong to attack")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(strength.canDefeatInAttack ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                }
                .padding(.top, 4)
            }
            
            // Update intel button
            if !isGathering {
                Button(action: {
                    Task {
                        isGathering = true
                        onGatherIntel()
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        isGathering = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(FontStyles.iconSmall)
                        Text("Update Intel (500g)")
                            .font(FontStyles.labelBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .foregroundColor(.white)
                }
                .brutalistBadge(
                    backgroundColor: canGatherIntel ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkLight.opacity(0.5),
                    cornerRadius: 8
                )
                .disabled(!canGatherIntel)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - No Intel View
    
    private func noIntelView(_ strength: MilitaryStrength) -> some View {
        VStack(spacing: 8) {
            statRow(
                icon: "building.2.fill",
                label: "Walls",
                value: "Level \(strength.wallLevel)"
            )
            
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .frame(width: 20)
                Text("Attack Power")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("###")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .blur(radius: 3)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "shield.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .frame(width: 20)
                Text("Total Defense")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("###")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .blur(radius: 3)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.gold)
                    .frame(width: 20)
                Text("Active Citizens")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("##")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .blur(radius: 3)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconMini)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 20)
            Text(label)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Spacer()
            Text(value)
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    private func requirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(met ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.error)
            Text(text)
        }
    }
    
    // MARK: - Actions
    
    private var canGatherIntel: Bool {
        player.intelligence >= 3 &&
        player.gold >= 500 &&
        player.currentKingdom == kingdom.id &&
        !isGathering
    }
}
