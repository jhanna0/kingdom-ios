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
                // Visual representation of property tier
                tierVisual
                
                // Header with tier name and level
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(property.tierName)
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { tier in
                                Circle()
                                    .fill(tier <= property.tier ? tierColor : KingdomTheme.Colors.inkDark.opacity(0.2))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("T\(property.tier)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tierColor)
                            .cornerRadius(4)
                        
                        Text("\(property.currentValue) gold")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.6))
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
                
                // Key benefits
                benefitsPreview
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    // MARK: - Tier Visual
    
    private var tierVisual: some View {
        ZStack {
            // Background gradient based on tier
            LinearGradient(
                colors: [tierColor.opacity(0.15), tierColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 100)
            .cornerRadius(8)
            
            // Tier-specific illustration
            HStack(spacing: 16) {
                Spacer()
                
                switch property.tier {
                case 1:
                    // T1: Cleared land
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(tierColor)
                    
                case 2:
                    // T2: Simple house
                    Image(systemName: "house.fill")
                        .font(.system(size: 50))
                        .foregroundColor(tierColor)
                    
                case 3:
                    // T3: House with workshop
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 40))
                            .foregroundColor(tierColor)
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 35))
                            .foregroundColor(tierColor.opacity(0.8))
                            .offset(y: 10)
                    }
                    
                case 4:
                    // T4: Beautiful property
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 50))
                        .foregroundColor(tierColor)
                    
                case 5:
                    // T5: Estate with crown
                    VStack(spacing: -5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 25))
                            .foregroundColor(KingdomTheme.Colors.gold)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 45))
                            .foregroundColor(tierColor)
                    }
                    
                default:
                    Image(systemName: "questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(tierColor)
                }
                
                Spacer()
            }
        }
    }
    
    private var tierColor: Color {
        switch property.tier {
        case 1: return KingdomTheme.Colors.buttonSecondary
        case 2: return KingdomTheme.Colors.buttonPrimary
        case 3: return KingdomTheme.Colors.goldWarm
        case 4: return KingdomTheme.Colors.gold
        case 5: return KingdomTheme.Colors.gold
        default: return KingdomTheme.Colors.inkDark
        }
    }
    
    // MARK: - Benefits preview
    
    private var benefitsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if property.tier >= 1 {
                benefitRow(text: "Instant travel")
            }
            
            if property.tier >= 2 {
                benefitRow(text: "Residence")
            }
            
            if property.tier >= 3 {
                benefitRow(text: "Crafting")
            }
            
            if property.tier >= 4 {
                benefitRow(text: "No taxes")
            }
            
            if property.tier >= 5 {
                benefitRow(text: "Conquest protection")
            }
        }
    }
    
    private func benefitRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 14)
            
            Text(text)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
}


