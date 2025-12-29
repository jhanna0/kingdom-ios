import SwiftUI

struct CraftingDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
    let equipmentType: String
    let craftingCosts: CraftingCosts?
    let craftingQueue: [CraftingContract]
    let onPurchase: (Int) -> Void
    
    @State private var selectedTier: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Tier selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Tier")
                        .font(.system(.title3, design: .default).bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Picker("Tier", selection: $selectedTier) {
                        ForEach(1...5, id: \.self) { tier in
                            Text("T\(tier)").tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(KingdomTheme.Colors.parchmentLight)
                .cornerRadius(12)
                
                // Tier details
                if let costs = craftingCosts, let tierCost = costs.cost(for: selectedTier) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Benefits
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Benefits")
                                .font(.headline)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            HStack {
                                Image(systemName: equipmentType == "weapon" ? "bolt.fill" : "shield.fill")
                                    .font(.title2)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                                
                                Text("+\(tierCost.statBonus) \(equipmentType == "weapon" ? "Attack" : "Defense")")
                                    .font(.title2.bold())
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                        
                        Divider()
                        
                        // Requirements
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Requirements")
                                .font(.headline)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            HStack {
                                Text("\(tierCost.actionsRequired) actions")
                                    .font(.body)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Spacer()
                                Text("(2 hour cooldown)")
                                    .font(.caption)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                        
                        Divider()
                        
                        // Cost
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cost")
                                .font(.headline)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                if tierCost.iron > 0 {
                                    HStack {
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        Text("\(tierCost.iron) Iron")
                                            .font(.body)
                                            .foregroundColor(KingdomTheme.Colors.inkDark)
                                        Spacer()
                                        Text("Have: \(player.iron)")
                                            .font(.body)
                                            .foregroundColor(player.iron >= tierCost.iron ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                                    }
                                }
                                
                                if tierCost.steel > 0 {
                                    HStack {
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                        Text("\(tierCost.steel) Steel")
                                            .font(.body)
                                            .foregroundColor(KingdomTheme.Colors.inkDark)
                                        Spacer()
                                        Text("Have: \(player.steel)")
                                            .font(.body)
                                            .foregroundColor(player.steel >= tierCost.steel ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(KingdomTheme.Colors.gold)
                                    Text("\(tierCost.gold) Gold")
                                        .font(.body)
                                        .foregroundColor(KingdomTheme.Colors.inkDark)
                                    Spacer()
                                    Text("Have: \(player.gold)")
                                        .font(.body)
                                        .foregroundColor(player.gold >= tierCost.gold ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
                                }
                            }
                        }
                        
                        // Purchase button
                        let canAffordGold = player.gold >= tierCost.gold
                        let canAffordIron = player.iron >= tierCost.iron
                        let canAffordSteel = player.steel >= tierCost.steel
                        let canAfford = canAffordGold && canAffordIron && canAffordSteel
                        let hasActiveCrafting = craftingQueue.contains { $0.status != "completed" }
                        
                        Button(action: {
                            onPurchase(selectedTier)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                Text("Start Crafting")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canAfford && !hasActiveCrafting ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.disabled)
                            .foregroundColor(KingdomTheme.Colors.parchmentLight)
                            .cornerRadius(12)
                        }
                        .disabled(!canAfford || hasActiveCrafting)
                        
                        if hasActiveCrafting {
                            Text("Complete your current craft first")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if !canAfford {
                            Text("Insufficient resources")
                                .font(.caption)
                                .foregroundColor(KingdomTheme.Colors.buttonDanger)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                    .background(KingdomTheme.Colors.parchmentLight)
                    .cornerRadius(12)
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
}

