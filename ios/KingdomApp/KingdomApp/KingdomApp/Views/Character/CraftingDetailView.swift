import SwiftUI

struct CraftingDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
    let equipmentType: String
    let craftingCosts: CraftingCosts?
    let craftingQueue: [CraftingContract]
    let onPurchase: (Int) -> Void
    
    @State private var selectedTier: Int = 1
    
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
                            .font(.system(size: 40))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        Text("Currently Equipped: Tier \(equipped.tier)")
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("+\(equipmentType == "weapon" ? equipped.attackBonus : equipped.defenseBonus) \(equipmentType == "weapon" ? "Attack" : "Defense")")
                            .font(.subheadline)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KingdomTheme.Colors.gold.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KingdomTheme.Colors.gold, lineWidth: 1)
                    )
                }
                
                // Unified tier selector
                TierSelectorCard(
                    currentTier: currentEquippedTier,
                    selectedTier: $selectedTier,
                    showCurrentBadge: false
                ) { tier in
                    if let costs = craftingCosts, let tierCost = costs.cost(for: tier) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Tier name
                            Text("Tier \(tier)")
                                .font(.headline)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            // Benefits - bullet list like training
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(icon: "star.fill", title: "Benefits")
                                
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                        .frame(width: 20)
                                    
                                    Text("+\(tierCost.statBonus) \(equipmentType == "weapon" ? "Attack" : "Defense")")
                                        .font(.subheadline)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            Divider()
                            
                            // Requirements - ALWAYS SHOW
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(icon: "hourglass", title: "Requirements")
                                
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                                        .frame(width: 20)
                                    Text("\(tierCost.actionsRequired) actions")
                                        .font(.subheadline)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Spacer()
                                    Text("2 hr cooldown")
                                        .font(.caption)
                                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                                }
                            }
                            
                            Divider()
                            
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
                                    icon: "circle.fill",
                                    iconColor: KingdomTheme.Colors.gold,
                                    label: "Gold",
                                    required: tierCost.gold,
                                    available: player.gold
                                )
                            }
                            
                            // Action button - no collapsing
                            let canAfford = canAffordTier(tierCost)
                            let hasActiveCrafting = craftingQueue.contains { $0.status != "completed" }
                            
                            UnifiedActionButton(
                                title: "Start Crafting",
                                subtitle: nil,
                                icon: "hammer.fill",
                                isEnabled: canAfford && !hasActiveCrafting,
                                statusMessage: hasActiveCrafting ? "Complete your current craft first" : !canAfford ? "Insufficient resources" : nil,
                                action: {
                                    onPurchase(tier)
                                    dismiss()
                                }
                            )
                        }
                    } else {
                        Text("Loading costs...")
                            .font(.subheadline)
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
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.gold)
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    // MARK: - Computed Properties
    
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

