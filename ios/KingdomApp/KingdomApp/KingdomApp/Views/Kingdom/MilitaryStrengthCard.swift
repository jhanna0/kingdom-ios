import SwiftUI

struct MilitaryStrengthCard: View {
    let strength: MilitaryStrength?
    let kingdom: Kingdom
    let player: Player
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
            // Compact header with key stats inline
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    Image(systemName: strength?.isRuler == true ? "shield.fill" : "eye.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .brutalistBadge(
                            backgroundColor: strength?.isRuler == true ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonWarning,
                            cornerRadius: 6,
                            shadowOffset: 2,
                            borderWidth: 1.5
                        )
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(strength?.isRuler == true ? "Military" : "Intel")
                            .font(FontStyles.labelBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if let strength = strength {
                            Text("Walls Lv.\(strength.wallLevel)")
                                .font(FontStyles.labelTiny)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                        }
                    }
                    
                    Spacer()
                    
                    // Quick stats summary
                    if let strength = strength {
                        HStack(spacing: 8) {
                            if let attack = strength.totalAttack {
                                statBadge(icon: "bolt.fill", value: "\(attack)", color: KingdomTheme.Colors.buttonDanger)
                            }
                            if let defense = strength.totalDefenseWithWalls {
                                statBadge(icon: "shield.fill", value: "\(defense)", color: KingdomTheme.Colors.buttonPrimary)
                            }
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(FontStyles.iconMini)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details
            if isExpanded, let strength = strength {
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 1)
                
                if strength.isRuler {
                    ownKingdomView(strength)
                } else if strength.hasIntel {
                    enemyIntelView(strength)
                } else {
                    noIntelView(strength)
                }
            }
            
            // Loading state
            if strength == nil {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Stat Badge
    
    private func statBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(KingdomTheme.Colors.parchment)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black, lineWidth: 1)
        )
    }
    
    // MARK: - Own Kingdom View
    
    private func ownKingdomView(_ strength: MilitaryStrength) -> some View {
        VStack(spacing: 6) {
            compactStatRow(icon: "building.2.fill", label: "Walls", value: "Lv.\(strength.wallLevel) (+\(strength.wallLevel * 5) def)")
            
            if let citizens = strength.activeCitizens {
                compactStatRow(icon: "person.3.fill", label: "Citizens", value: "\(citizens)")
            }
            
            if let patrolStrength = strength.patrolStrength {
                compactStatRow(icon: "eye.fill", label: "Patrolling", value: "\(patrolStrength)")
            }
        }
    }
    
    // MARK: - Enemy Kingdom with Intel (passive display - no button)
    
    private func enemyIntelView(_ strength: MilitaryStrength) -> some View {
        VStack(spacing: 6) {
            if let gatheredBy = strength.gatheredBy {
                Text("Intel by \(gatheredBy)")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            compactStatRow(icon: "building.2.fill", label: "Walls", value: "Lv.\(strength.wallLevel)")
            
            // T2+ intel: show citizens
            if let citizens = strength.activeCitizens {
                compactStatRow(icon: "person.3.fill", label: "Citizens", value: "\(citizens)")
            }
            
            // T2+ intel: show military stats
            if let attack = strength.totalAttack {
                compactStatRow(icon: "bolt.fill", label: "Attack", value: "\(attack)")
            }
            if let defense = strength.totalDefense {
                compactStatRow(icon: "shield.fill", label: "Defense", value: "\(defense)")
            }
            
            // Show vulnerability assessment if we have military intel
            if strength.totalAttack != nil {
                HStack(spacing: 4) {
                    Image(systemName: strength.canDefeatInAttack ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(FontStyles.iconMini)
                        .foregroundColor(strength.canDefeatInAttack ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                    Text(strength.canDefeatInAttack ? "Vulnerable" : "Too strong")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(strength.canDefeatInAttack ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonWarning)
                }
            }
            
            // Show intel age
            if let intelAge = strength.intelAgeDays {
                Text(intelAge == 0 ? "Intel gathered today" : "Intel is \(intelAge) day\(intelAge == 1 ? "" : "s") old")
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                    .padding(.top, 2)
            }
        }
    }
    
    // MARK: - No Intel View (passive - tells user to scout via Actions)
    
    private func noIntelView(_ strength: MilitaryStrength) -> some View {
        VStack(spacing: 6) {
            compactStatRow(icon: "building.2.fill", label: "Walls", value: "Lv.\(strength.wallLevel)")
            
            HStack(spacing: 4) {
                Image(systemName: "eye.slash")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
                Text("No intel available")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            // Hint to use Scout action
            Text("Use Scout action to gather intel")
                .font(FontStyles.labelTiny)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .italic()
        }
    }
    
    // MARK: - Compact Stat Row
    
    private func compactStatRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 16)
            Text(label)
                .font(FontStyles.labelSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Spacer()
            Text(value)
                .font(FontStyles.labelBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}
