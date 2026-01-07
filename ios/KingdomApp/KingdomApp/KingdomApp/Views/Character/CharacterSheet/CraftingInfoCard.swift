import SwiftUI

/// Card displaying equipment crafting options
struct CraftingInfoCard: View {
    @ObservedObject var player: Player
    let craftingQueue: [CraftingContract]
    let craftingCosts: CraftingCosts?
    let onPurchaseCraft: (String, Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Equipment Crafting")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Show active crafting contract if exists
            if let activeContract = craftingQueue.first(where: { $0.status != "completed" }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        
                        Text("Crafting In Progress: Tier \(activeContract.tier) \(activeContract.equipmentType.capitalized)")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.buttonWarning)
                    }
                    
                    Text("Complete your current craft (\(activeContract.actionsCompleted)/\(activeContract.actionsRequired)) before starting a new one")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .padding()
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning.opacity(0.15), cornerRadius: 8)
            }
            
            Text("Tap equipment to view all tiers and start crafting")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Equipment grid
            HStack(spacing: 10) {
                craftGridButton(
                    iconName: "bolt.fill",
                    displayName: "Weapon",
                    equipmentType: "weapon",
                    equipped: player.equippedWeapon,
                    bonus: player.equippedWeapon?.attackBonus ?? 0
                )
                
                craftGridButton(
                    iconName: "shield.fill",
                    displayName: "Armor",
                    equipmentType: "armor",
                    equipped: player.equippedArmor,
                    bonus: player.equippedArmor?.defenseBonus ?? 0
                )
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private func craftGridButton(
        iconName: String,
        displayName: String,
        equipmentType: String,
        equipped: Player.EquipmentData?,
        bonus: Int
    ) -> some View {
        NavigationLink(destination: CraftingDetailView(
            player: player,
            equipmentType: equipmentType,
            craftingCosts: craftingCosts,
            craftingQueue: craftingQueue,
            onPurchase: { tier in
                onPurchaseCraft(equipmentType, tier)
            }
        )) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: getEquipmentColor(equipmentType: equipmentType),
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    if let item = equipped {
                        Text("\(item.tier)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .brutalistBadge(
                                backgroundColor: .black,
                                cornerRadius: 10,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                            .offset(x: 5, y: -5)
                    }
                }
                
                Text(displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
        }
        .buttonStyle(.plain)
    }
    
    private func getEquipmentColor(equipmentType: String) -> Color {
        switch equipmentType {
        case "weapon":
            return KingdomTheme.Colors.buttonDanger
        case "armor":
            return KingdomTheme.Colors.royalBlue
        default:
            return KingdomTheme.Colors.inkMedium
        }
    }
}

