import SwiftUI

/// Full overview of all property tiers and their benefits
/// Shows users what they're working toward
struct TierBenefitsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerCard
                
                // All 5 tiers
                ForEach(1...5, id: \.self) { tier in
                    tierCard(tier: tier)
                }
            }
            .padding()
        }
        .parchmentBackground()
        .navigationTitle("Property Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .parchmentNavigationBar()
    }
    
    // MARK: - Header
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 50))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            Text("Property Progression")
                .font(.title2.bold())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Upgrade your property to unlock new benefits")
                .font(.body)
                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Tier Card
    
    private func tierCard(tier: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tier header with icon
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tierColor(for: tier).opacity(0.2), tierColor(for: tier).opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    tierIcon(for: tier)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tier \(tier)")
                        .font(.caption.bold())
                        .foregroundColor(tierColor(for: tier))
                    
                    Text(tierName(for: tier))
                        .font(.title3.bold())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(tierDescription(for: tier))
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                Spacer()
            }
            
            Divider()
            
            // Benefits
            VStack(alignment: .leading, spacing: 10) {
                Text("Benefits:")
                    .font(.subheadline.bold())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                ForEach(tierBenefits(for: tier), id: \.self) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(tierColor(for: tier))
                            .frame(width: 16)
                        
                        Text(benefit)
                            .font(.subheadline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                }
            }
            
            // Cost and requirements
            Divider()
            
            HStack {
                if tier > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upgrade Cost")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                        
                        Text("\(upgradeCost(from: tier - 1)) gold")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Work Required")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                        
                        Text("\(baseActionsRequired(for: tier - 1)) actions")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Purchase Cost")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
                        
                        Text("500+ gold (varies)")
                            .font(.subheadline.bold())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
            }
        }
        .padding()
        .parchmentCard(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            borderColor: tierColor(for: tier).opacity(0.3)
        )
    }
    
    // MARK: - Tier Data
    
    private func tierName(for tier: Int) -> String {
        switch tier {
        case 1: return "Land"
        case 2: return "House"
        case 3: return "Workshop"
        case 4: return "Beautiful Property"
        case 5: return "Estate"
        default: return "Property"
        }
    }
    
    private func tierDescription(for tier: Int) -> String {
        switch tier {
        case 1: return "Cleared land"
        case 2: return "Basic dwelling"
        case 3: return "Workshop for crafting"
        case 4: return "Luxurious estate"
        case 5: return "Fortified estate"
        default: return ""
        }
    }
    
    private func tierBenefits(for tier: Int) -> [String] {
        switch tier {
        case 1:
            return ["Instant travel to kingdom", "Fast travel home base"]
        case 2:
            return ["Personal residence", "Storage space"]
        case 3:
            return ["Craft weapons and armor", "15% faster crafting"]
        case 4:
            return ["No taxes in kingdom", "Prestigious status"]
        case 5:
            return ["50% survive conquest", "Maximum protection"]
        default:
            return []
        }
    }
    
    private func upgradeCost(from tier: Int) -> Int {
        let baseCost = 500
        let nextTier = tier + 1
        return baseCost * Int(pow(2.0, Double(nextTier - 2)))
    }
    
    private func baseActionsRequired(for tier: Int) -> Int {
        return 5 + (tier * 2)
    }
    
    private func tierColor(for tier: Int) -> Color {
        switch tier {
        case 1: return KingdomTheme.Colors.buttonSecondary
        case 2: return KingdomTheme.Colors.buttonPrimary
        case 3: return KingdomTheme.Colors.inkMedium
        case 4: return KingdomTheme.Colors.inkMedium
        case 5: return KingdomTheme.Colors.inkMedium
        default: return KingdomTheme.Colors.inkDark
        }
    }
    
    @ViewBuilder
    private func tierIcon(for tier: Int) -> some View {
        switch tier {
        case 1:
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 35, weight: .light))
                .foregroundColor(tierColor(for: tier))
        case 2:
            Image(systemName: "house.fill")
                .font(.system(size: 35))
                .foregroundColor(tierColor(for: tier))
        case 3:
            Image(systemName: "hammer.fill")
                .font(.system(size: 35))
                .foregroundColor(tierColor(for: tier))
        case 4:
            Image(systemName: "building.columns.fill")
                .font(.system(size: 35))
                .foregroundColor(tierColor(for: tier))
        case 5:
            VStack(spacing: -5) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 30))
                    .foregroundColor(tierColor(for: tier))
            }
        default:
            Image(systemName: "questionmark")
                .font(.system(size: 35))
                .foregroundColor(tierColor(for: tier))
        }
    }
}



