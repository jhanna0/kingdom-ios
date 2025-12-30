import SwiftUI

// MARK: - Sabotage Target Card

struct SabotageTargetCard: View {
    let target: SabotageTarget
    let canSabotage: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: iconForBuildingType(target.buildingType))
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.buttonDanger)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(target.buildingType)
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("Level \(target.buildingLevel)")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(KingdomTheme.Colors.parchmentDark)
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 4) {
                        Text(target.progress)
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("•")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("\(target.progressPercent)% complete")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.gold)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
            }
            
            // Sabotage Effect Preview
            HStack(spacing: KingdomTheme.Spacing.small) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                
                Text("Will add +\(target.potentialDelay) actions required")
                    .font(KingdomTheme.Typography.caption())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
            .cornerRadius(KingdomTheme.CornerRadius.small)
            
            // Action Button
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "flame.fill")
                    Text("Sabotage This Contract")
                }
            }
            .buttonStyle(.medieval(
                color: canSabotage ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.disabled,
                fullWidth: true
            ))
            .disabled(!canSabotage)
        }
        .padding()
        .parchmentCard()
        .padding(.horizontal)
    }
    
    private func iconForBuildingType(_ type: String) -> String {
        switch type.lowercased() {
        case "walls": return "building.2.fill"
        case "mine": return "hammer.circle.fill"
        case "market": return "cart.fill"
        case "vault": return "archivebox.fill"
        default: return "building.fill"
        }
    }
}

