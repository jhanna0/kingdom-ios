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
                Image(systemName: strength?.isOwnKingdom == true ? "shield.fill" : "eye.fill")
                    .foregroundColor(strength?.isOwnKingdom == true ? KingdomTheme.Colors.goldWarm : KingdomTheme.Colors.buttonWarning)
                Text(strength?.isOwnKingdom == true ? "Military Strength" : "Intelligence Report")
                    .font(KingdomTheme.Typography.subheadline())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                
                // Intel age indicator
                if let strength = strength, strength.hasIntel, let days = strength.intelAgeDays {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(KingdomTheme.Typography.caption2())
                        Text(strength.intelAgeText)
                            .font(KingdomTheme.Typography.caption2())
                    }
                    .foregroundColor(strength.isIntelExpiring ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkLight)
                }
            }
            
            // Show data based on what we know
            if let strength = strength {
                if strength.isOwnKingdom {
                    // Full details for own kingdom
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
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight, hasShadow: false)
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
        }
    }
    
    // MARK: - Enemy Kingdom with Intel
    
    private func enemyIntelView(_ strength: MilitaryStrength) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Intel source
            if let gatheredBy = strength.gatheredBy {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(KingdomTheme.Typography.caption2())
                    Text("Intel by \(gatheredBy)")
                        .font(KingdomTheme.Typography.caption2())
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
                        .foregroundColor(strength.canDefeatInAttack ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                    Text(strength.canDefeatInAttack ? "We could win an attack!" : "They're too strong to attack")
                        .font(KingdomTheme.Typography.caption())
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
                        Text("Update Intel (500g)")
                    }
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(canGatherIntel ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkLight.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(KingdomTheme.CornerRadius.medium)
                }
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
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.goldWarm)
                    .frame(width: 20)
                Text("Attack Power")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("###")
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .blur(radius: 3)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "shield.fill")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.goldWarm)
                    .frame(width: 20)
                Text("Total Defense")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("###")
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .blur(radius: 3)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.goldWarm)
                    .frame(width: 20)
                Text("Active Citizens")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Spacer()
                Text("##")
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .blur(radius: 3)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.goldWarm)
                .frame(width: 20)
            Text(label)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Spacer()
            Text(value)
                .font(KingdomTheme.Typography.caption())
                .fontWeight(.semibold)
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
