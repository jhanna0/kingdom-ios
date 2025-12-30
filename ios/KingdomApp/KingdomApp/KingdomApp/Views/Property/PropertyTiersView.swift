import SwiftUI

/// View to see all property tiers at once
struct PropertyTiersView: View {
    @ObservedObject var player: Player
    let property: Property
    @Environment(\.dismiss) var dismiss
    @State private var selectedTier: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Tier selector with picker
                TierSelectorCard(
                    currentTier: property.tier,
                    selectedTier: $selectedTier
                ) { tier in
                    tierContent(tier: tier)
                }
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("All Property Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedTier = property.tier
        }
    }
    
    private func tierContent(tier: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tier name
            Text("Tier \(tier)")
                .font(.headline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "star.fill", title: "Benefits")
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tier <= property.tier ? "checkmark.circle.fill" : "lock.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(tier <= property.tier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                        .frame(width: 20)
                    
                    Text(tierBenefit(tier))
                        .font(.subheadline)
                        .foregroundColor(tier <= property.tier ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Divider()
            
            // Cost
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "dollarsign.circle.fill", title: "Cost")
                
                ResourceRow(
                    icon: "circle.fill",
                    iconColor: KingdomTheme.Colors.gold,
                    label: "Gold",
                    required: upgradeCost(tier),
                    available: player.gold
                )
            }
            
            // Status
            if tier <= property.tier {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                    Text("Unlocked")
                        .font(.subheadline.bold())
                }
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.gold.opacity(0.1))
                .cornerRadius(10)
            } else if tier > property.tier + 1 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                    Text("Complete Tier \(property.tier + 1) first")
                        .font(.subheadline)
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                .cornerRadius(10)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                    Text("Locked")
                        .font(.subheadline)
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.inkDark.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
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
    
    private func tierName(_ tier: Int) -> String {
        switch tier {
        case 1: return "Empty Lot"
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"
        default: return "Tier \(tier)"
        }
    }
    
    private func tierBenefit(_ tier: Int) -> String {
        switch tier {
        case 1: return "Basic land ownership"
        case 2: return "Residence"
        case 3: return "Crafting"
        case 4: return "No taxes"
        case 5: return "Conquest protection"
        default: return ""
        }
    }
    
    private func upgradeCost(_ tier: Int) -> Int {
        // Approximate costs
        switch tier {
        case 2: return 100
        case 3: return 300
        case 4: return 600
        case 5: return 1000
        default: return 0
        }
    }
}

