import SwiftUI

struct CraftingDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
    let equipmentType: String
    let craftingCosts: CraftingCosts?
    let craftingQueue: [CraftingContract]
    let onPurchase: (Int) -> Void
    
    @State private var selectedTier: Int = 1
    
    private var hasWorkshop: Bool {
        // Check if player has any property with tier >= 3 (Workshop)
        return player.hasWorkshop
    }
    
    private var currentEquippedTier: Int {
        if equipmentType == "weapon" {
            return player.equippedWeapon?.tier ?? 0
        } else {
            return player.equippedArmor?.tier ?? 0
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current equipment card
                if let equipped = currentEquipment {
                    VStack(spacing: 12) {
                        Image(systemName: equipmentType == "weapon" ? "bolt.fill" : "shield.fill")
                            .font(FontStyles.iconExtraLarge)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 16, shadowOffset: 3, borderWidth: 2)
                        
                        Text("Currently Equipped: Tier \(equipped.tier)")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("+\(equipmentType == "weapon" ? equipped.attackBonus : equipped.defenseBonus) \(equipmentType == "weapon" ? "Attack" : "Defense")")
                            .font(FontStyles.bodyMediumBold)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.inkMedium.opacity(0.1))
                }
                
                // Unified tier selector
                TierSelectorCard(
                    currentTier: currentEquippedTier,
                    selectedTier: $selectedTier,
                    showCurrentBadge: false,
                    accentColor: craftingColor
                ) { tier in
                    if let costs = craftingCosts, let tierCost = costs.cost(for: tier) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Tier name
                            Text("Tier \(tier)")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            // Benefits - bullet list like training
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(icon: "star.fill", title: "Benefits")
                                
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(craftingColor)
                                        .frame(width: 20)
                                    
                                    Text("+\(tierCost.statBonus) \(equipmentType == "weapon" ? "Attack" : "Defense")")
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            Rectangle()
                                .fill(craftingColor.opacity(0.3))
                                .frame(height: 2)
                            
                            // Requirements - ALWAYS SHOW
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(icon: "hourglass", title: "Requirements")
                                
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(craftingColor.opacity(0.5))
                                        .frame(width: 20)
                                    Text("\(tierCost.actionsRequired) actions")
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Spacer()
                                    Text("2 hr cooldown")
                                        .font(FontStyles.labelSmall)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                            }
                            
                            Rectangle()
                                .fill(craftingColor.opacity(0.3))
                                .frame(height: 2)
                            
                            // Cost - ALWAYS SHOW
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(icon: "dollarsign.circle.fill", title: "Cost")
                                
                                if tierCost.iron > 0 {
                                    ResourceRow(
                                        icon: "cube.fill",
                                        iconColor: .gray,
                                        label: "Iron",
                                        required: tierCost.iron,
                                        available: player.iron
                                    )
                                }
                                
                                if tierCost.steel > 0 {
                                    ResourceRow(
                                        icon: "cube.fill",
                                        iconColor: .blue,
                                        label: "Steel",
                                        required: tierCost.steel,
                                        available: player.steel
                                    )
                                }
                                
                                ResourceRow(
                                    icon: "g.circle.fill",
                                    iconColor: KingdomTheme.Colors.goldLight,
                                    label: "Gold",
                                    required: tierCost.gold,
                                    available: player.gold
                                )
                            }
                            
                            // Workshop requirement warning
                            if !hasWorkshop {
                                Rectangle()
                                    .fill(craftingColor.opacity(0.3))
                                    .frame(height: 2)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(FontStyles.iconSmall)
                                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                        Text("Workshop Required")
                                            .font(FontStyles.bodyMediumBold)
                                            .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                    }
                                    
                                    Text("You need a Workshop (Property Tier 3+) to craft equipment. Purchase and upgrade property first.")
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                            }
                            
                            // Action button
                            let canAfford = canAffordTier(tierCost)
                            let hasActiveCrafting = craftingQueue.contains { $0.status != "completed" }
                            
                            UnifiedActionButton(
                                title: hasWorkshop ? "Start Crafting" : "Need Workshop (Tier 3)",
                                subtitle: nil,
                                icon: "hammer.fill",
                                isEnabled: hasWorkshop && canAfford && !hasActiveCrafting,
                                statusMessage: !hasWorkshop ? "Upgrade property to Workshop first" : hasActiveCrafting ? "Complete your current craft first" : !canAfford ? "Insufficient resources" : nil,
                                action: {
                                    onPurchase(tier)
                                    dismiss()
                                }
                            )
                        }
                    } else {
                        Text("Loading costs...")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Craft \(equipmentType.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(craftingColor.opacity(0.5))
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Computed Properties
    
    private var craftingColor: Color {
        return EquipmentConfig.get(equipmentType).color
    }
    
    private var currentEquipment: Player.EquipmentData? {
        if equipmentType == "weapon" {
            return player.equippedWeapon
        } else {
            return player.equippedArmor
        }
    }
    
    private func canAffordTier(_ cost: CraftingCostTier) -> Bool {
        return player.gold >= cost.gold &&
               player.iron >= cost.iron &&
               player.steel >= cost.steel
    }
}

