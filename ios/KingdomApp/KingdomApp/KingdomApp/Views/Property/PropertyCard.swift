import SwiftUI

/// Reusable card component for displaying property information
struct PropertyCard: View {
    let property: Property
    var showOwner: Bool = false
    var onTap: (() -> Void)?
    
    var body: some View {
        cardContent
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
                // Header with icon and type
                HStack {
                    Text(property.icon)
                        .font(.system(size: 40))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(property.type.rawValue)
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { tier in
                                Image(systemName: tier <= property.tier ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(tier <= property.tier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Tier \(property.tier)")
                            .font(.caption.bold())
                            .foregroundColor(KingdomTheme.Colors.gold)
                        
                        Text("\(property.currentValue)💰")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                }
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
                    
                    Text(property.kingdomName)
                        .font(.caption)
                        .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                }
                
                // Owner (if shown)
                if showOwner {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.5))
                        
                        Text(property.ownerName)
                            .font(.caption)
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                    }
                }
                
                Divider()
                
                // Primary benefit based on type
                switch property.type {
                case .house:
                    houseBenefitsPreview
                case .shop:
                    shopBenefitsPreview
                case .personalMine:
                    mineBenefitsPreview
                }
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Type-specific benefit previews
    
    private var houseBenefitsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            benefitRow(
                icon: "airplane",
                text: "Instant travel to \(property.kingdomName)",
                active: true
            )
            
            if property.tier >= 3 {
                benefitRow(
                    icon: "bolt.fill",
                    text: "10% faster on all actions",
                    active: true
                )
            }
            
            if property.tier >= 4 {
                benefitRow(
                    icon: "percent",
                    text: "50% tax reduction",
                    active: true
                )
            }
            
            if property.tier >= 5 {
                benefitRow(
                    icon: "shield.fill",
                    text: "50% survive conquest",
                    active: true
                )
            }
        }
    }
    
    private var shopBenefitsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            benefitRow(
                icon: "dollarsign.circle.fill",
                text: "\(property.dailyGoldIncome)💰 per day",
                active: true
            )
            
            if property.pendingGoldIncome > 0 {
                benefitRow(
                    icon: "clock.fill",
                    text: "\(property.pendingGoldIncome)💰 pending",
                    active: true
                )
            }
        }
    }
    
    private var mineBenefitsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            benefitRow(
                icon: "hammer.fill",
                text: "\(property.dailyIronYield) iron per day",
                active: true
            )
            
            if property.tier >= 2 {
                benefitRow(
                    icon: "shield.lefthalf.filled",
                    text: "\(property.dailySteelYield) steel per day",
                    active: true
                )
            }
            
            benefitRow(
                icon: "checkmark.shield.fill",
                text: "No taxes on mining",
                active: true
            )
        }
    }
    
    private func benefitRow(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(active ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.3))
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(active ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkDark.opacity(0.5))
        }
    }
}

// MARK: - Preview

struct PropertyCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            PropertyCard(
                property: Property.samples[0],
                showOwner: true
            )
            
            PropertyCard(
                property: Property.samples[1],
                showOwner: false
            )
            
            PropertyCard(
                property: Property.samples[2],
                showOwner: true
            )
        }
        .padding()
        .background(KingdomTheme.Colors.parchment)
    }
}

