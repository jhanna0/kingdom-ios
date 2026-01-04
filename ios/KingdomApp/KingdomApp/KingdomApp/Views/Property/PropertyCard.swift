import SwiftUI

/// Reusable card component for displaying property information - Compact brutalist style
struct PropertyCard: View {
    let property: Property
    var showOwner: Bool = false
    var onTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 14) {
            // Property icon in brutalist badge
            Image(systemName: tierIcon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonSuccess,
                    cornerRadius: 10,
                    shadowOffset: 2,
                    borderWidth: 2
                )
            
            // Property info
            VStack(alignment: .leading, spacing: 4) {
                Text(property.tierName)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(FontStyles.iconMini)
                    Text(property.kingdomName)
                        .font(FontStyles.labelMedium)
                    
                    if showOwner {
                        Text("•")
                            .font(FontStyles.labelMedium)
                        Text(property.ownerName)
                            .font(FontStyles.labelMedium)
                    }
                }
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Tier badge
            Text("T\(property.tier)")
                .font(FontStyles.headingLarge)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
    
    private var tierIcon: String {
        switch property.tier {
        case 1: return "rectangle.dashed"
        case 2: return "house.fill"
        case 3: return "hammer.fill"
        case 4: return "building.columns.fill"
        case 5: return "crown.fill"
        default: return "building.fill"
        }
    }
}


