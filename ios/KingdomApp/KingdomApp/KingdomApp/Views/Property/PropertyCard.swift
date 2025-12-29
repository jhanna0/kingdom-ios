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
                // Header with icon and tier name
                HStack {
                    Image(systemName: tierIcon)
                        .font(.system(size: 36))
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(property.tierName)
                            .font(.headline)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { tier in
                                Circle()
                                    .fill(tier <= property.tier ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkDark.opacity(0.2))
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
                            .background(KingdomTheme.Colors.gold)
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
    
    private var tierIcon: String {
        switch property.tier {
        case 1: return "map"
        case 2: return "house"
        case 3: return "hammer"
        case 4: return "building.columns"
        case 5: return "crown"
        default: return "map"
        }
    }
    
    // MARK: - Benefits preview
    
    private var benefitsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if property.tier >= 1 {
                benefitRow(text: "50% travel cost, instant travel")
            }
            
            if property.tier >= 2 {
                benefitRow(text: "Personal residence")
            }
            
            if property.tier >= 3 {
                benefitRow(text: "Can craft weapons & armor")
            }
            
            if property.tier >= 4 {
                benefitRow(text: "Tax exemption")
            }
            
            if property.tier >= 5 {
                benefitRow(text: "50% survive conquest")
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

