import SwiftUI

/// Card displaying equipment - tap to manage weapons and armor
struct EquipmentInfoCard: View {
    @ObservedObject var player: Player
    @State private var equipment: EquipmentResponse?
    @State private var isLoading = true
    
    var body: some View {
        NavigationLink(destination: EquipmentView(player: player)) {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(FontStyles.iconMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Equipment")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                
                Text("Tap to view and equip your weapons and armor")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 10)
                } else {
                    // Equipment grid
                    HStack(spacing: 10) {
                        equipmentGridButton(
                            iconName: equipment?.equippedWeapon?.icon ?? "bolt.fill",
                            displayName: "Weapon",
                            equipmentType: "weapon",
                            equipped: equipment?.equippedWeapon
                        )
                        
                        equipmentGridButton(
                            iconName: equipment?.equippedArmor?.icon ?? "shield.fill",
                            displayName: "Armor",
                            equipmentType: "armor",
                            equipped: equipment?.equippedArmor
                        )
                    }
                }
            }
            .padding()
            .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        }
        .buttonStyle(.plain)
        .task {
            await loadEquipment()
        }
    }
    
    private func equipmentGridButton(
        iconName: String,
        displayName: String,
        equipmentType: String,
        equipped: EquipmentItem?
    ) -> some View {
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
                    let bonus = equipmentType == "weapon" ? item.attackBonus : item.defenseBonus
                    Text("+\(bonus)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .frame(height: 18)
                        .brutalistBadge(
                            backgroundColor: .black,
                            cornerRadius: 6,
                            shadowOffset: 1,
                            borderWidth: 1.5
                        )
                        .offset(x: 8, y: -6)
                }
            }
            
            Text(equipped?.displayName ?? displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
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
    
    private func loadEquipment() async {
        do {
            let response = try await KingdomAPIService.shared.equipment.getEquipment()
            await MainActor.run {
                equipment = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
