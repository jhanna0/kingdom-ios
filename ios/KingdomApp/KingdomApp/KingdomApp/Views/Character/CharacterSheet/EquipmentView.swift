import SwiftUI

/// Full screen view for managing equipment
struct EquipmentView: View {
    @ObservedObject var player: Player
    @State private var equipment: EquipmentResponse?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let eq = equipment {
                    // Weapon section - RED
                    equipmentSection(
                        title: "Weapon",
                        equipped: eq.equippedWeapon,
                        unequipped: eq.unequippedWeapons,
                        icon: "bolt.fill",
                        color: KingdomTheme.Colors.buttonDanger
                    )
                    
                    // Armor section - BLUE
                    equipmentSection(
                        title: "Armor",
                        equipped: eq.equippedArmor,
                        unequipped: eq.unequippedArmor,
                        icon: "shield.fill",
                        color: KingdomTheme.Colors.royalBlue
                    )
                } else {
                    Text("No equipment available")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await loadEquipment()
        }
    }
    
    // MARK: - Section View
    
    @ViewBuilder
    private func equipmentSection(
        title: String,
        equipped: EquipmentItem?,
        unequipped: [EquipmentItem],
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(color)
                
                Text(title)
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(color)
                .frame(height: 2)
            
            // Equipped item
            if let item = equipped {
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: color,
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        let bonus = item.type == "weapon" ? item.attackBonus : item.defenseBonus
                        let stat = item.type == "weapon" ? "Attack" : "Defense"
                        Text("+\(bonus) \(stat)")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task { await unequip(item) }
                    } label: {
                        Text("Unequip")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .brutalistBadge(
                        backgroundColor: KingdomTheme.Colors.buttonDanger,
                        cornerRadius: 6,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
            } else {
                // Empty slot
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .frame(width: 44, height: 44)
                        .brutalistBadge(
                            backgroundColor: KingdomTheme.Colors.parchment,
                            cornerRadius: 10,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No \(title) Equipped")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Text("Select one below to equip")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
            }
            
            // Unequipped items
            if !unequipped.isEmpty {
                Text("Available")
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                ForEach(unequipped) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .brutalistBadge(
                                backgroundColor: color,
                                cornerRadius: 8,
                                shadowOffset: 1,
                                borderWidth: 1.5
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            let bonus = item.type == "weapon" ? item.attackBonus : item.defenseBonus
                            let stat = item.type == "weapon" ? "Attack" : "Defense"
                            Text("+\(bonus) \(stat)")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(color)
                        }
                        
                        Spacer()
                        
                        Button {
                            Task { await equip(item) }
                        } label: {
                            Text("Equip")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .brutalistBadge(
                            backgroundColor: color,
                            cornerRadius: 6,
                            shadowOffset: 2,
                            borderWidth: 2
                        )
                    }
                    .padding(12)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - API
    
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
    
    private func equip(_ item: EquipmentItem) async {
        do {
            _ = try await KingdomAPIService.shared.equipment.equip(itemId: item.id)
            await loadEquipment()
        } catch {
            print("Failed to equip: \(error)")
        }
    }
    
    private func unequip(_ item: EquipmentItem) async {
        do {
            _ = try await KingdomAPIService.shared.equipment.unequip(itemId: item.id)
            await loadEquipment()
        } catch {
            print("Failed to unequip: \(error)")
        }
    }
}
