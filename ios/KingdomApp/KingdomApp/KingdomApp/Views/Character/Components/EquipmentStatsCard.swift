import SwiftUI

/// Reusable equipment display card
struct EquipmentStatsCard: View {
    let weaponTier: Int?
    let weaponBonus: Int?
    let armorTier: Int?
    let armorBonus: Int?
    
    let isInteractive: Bool  // Whether equipment is tappable (for crafting)
    let onEquipmentTap: ((String) -> Void)?
    
    init(
        weaponTier: Int?,
        weaponBonus: Int?,
        armorTier: Int?,
        armorBonus: Int?,
        isInteractive: Bool = false,
        onEquipmentTap: ((String) -> Void)? = nil
    ) {
        self.weaponTier = weaponTier
        self.weaponBonus = weaponBonus
        self.armorTier = armorTier
        self.armorBonus = armorBonus
        self.isInteractive = isInteractive
        self.onEquipmentTap = onEquipmentTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Equipment")
                    .font(.headline)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Weapon
                equipmentRow(
                    iconName: "bolt.fill",
                    displayName: "Weapon",
                    tier: weaponTier,
                    bonus: weaponBonus,
                    equipmentKey: "weapon"
                )
                
                // Armor
                equipmentRow(
                    iconName: "shield.fill",
                    displayName: "Armor",
                    tier: armorTier,
                    bonus: armorBonus,
                    equipmentKey: "armor"
                )
            }
        }
        .padding()
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func equipmentRow(
        iconName: String,
        displayName: String,
        tier: Int?,
        bonus: Int?,
        equipmentKey: String
    ) -> some View {
        Button(action: {
            if isInteractive {
                onEquipmentTap?(equipmentKey)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let tier = tier, let bonus = bonus {
                        Text("Tier \(tier) (+\(bonus))")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else {
                        Text("No \(displayName.lowercased()) equipped")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if isInteractive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.3))
                }
            }
            .padding()
            .background(KingdomTheme.Colors.inkDark.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KingdomTheme.Colors.inkDark.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!isInteractive)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // With equipment (non-interactive)
        EquipmentStatsCard(
            weaponTier: 3,
            weaponBonus: 5,
            armorTier: 2,
            armorBonus: 3,
            isInteractive: false
        )
        
        // No equipment (interactive)
        EquipmentStatsCard(
            weaponTier: nil,
            weaponBonus: nil,
            armorTier: 1,
            armorBonus: 1,
            isInteractive: true,
            onEquipmentTap: { equipment in
                print("Tapped \(equipment)")
            }
        )
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}



