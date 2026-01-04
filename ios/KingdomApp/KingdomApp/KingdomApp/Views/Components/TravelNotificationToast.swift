import SwiftUI

/// Toast notification for travel events (entering kingdoms, paying fees, etc.)
struct TravelNotificationToast: View {
    let travelEvent: TravelEvent
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Icon with brutalist badge
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .brutalistBadge(
                    backgroundColor: iconBackgroundColor,
                    cornerRadius: 12,
                    shadowOffset: 3,
                    borderWidth: 2
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .background(
            ZStack {
                // Offset shadow
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                    .fill(Color.black)
                    .offset(x: KingdomTheme.Brutalist.offsetShadow, y: KingdomTheme.Brutalist.offsetShadow)
                
                // Main card
                RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
                            .stroke(Color.black, lineWidth: KingdomTheme.Brutalist.borderWidth)
                    )
            }
        )
        // Soft shadow for extra depth
        .shadow(
            color: KingdomTheme.Shadows.brutalistSoft.color,
            radius: KingdomTheme.Shadows.brutalistSoft.radius,
            x: KingdomTheme.Shadows.brutalistSoft.x,
            y: KingdomTheme.Shadows.brutalistSoft.y
        )
        .padding(.horizontal)
    }
    
    private var iconName: String {
        if travelEvent.denied == true || !travelEvent.entered_kingdom {
            return "xmark.octagon.fill"
        } else if travelEvent.travel_fee_paid > 0 {
            return "g.circle.fill"
        } else if travelEvent.free_travel_reason != nil {
            return "checkmark.seal.fill"
        } else {
            return "location.circle.fill"
        }
    }
    
    private var iconBackgroundColor: Color {
        if travelEvent.denied == true || !travelEvent.entered_kingdom {
            return KingdomTheme.Colors.buttonDanger
        } else if travelEvent.travel_fee_paid > 0 {
            return KingdomTheme.Colors.imperialGold
        } else {
            return KingdomTheme.Colors.buttonSuccess
        }
    }
    
    private var backgroundColor: Color {
        if travelEvent.denied == true || !travelEvent.entered_kingdom {
            return KingdomTheme.Colors.parchmentLight
        } else if travelEvent.travel_fee_paid > 0 {
            return KingdomTheme.Colors.parchmentHighlight
        } else {
            return KingdomTheme.Colors.parchmentLight
        }
    }
    
    private var title: String {
        if travelEvent.denied == true || !travelEvent.entered_kingdom {
            return "Entry Denied"
        } else if travelEvent.travel_fee_paid > 0 {
            return "Travel Fee Paid"
        } else {
            return "Welcome to \(travelEvent.kingdom_name)"
        }
    }
    
    private var message: String {
        if travelEvent.denied == true {
            // Use the backend's denial reason if provided
            if let denialReason = travelEvent.denial_reason {
                return denialReason
            } else {
                return "Cannot enter \(travelEvent.kingdom_name)"
            }
        } else if !travelEvent.entered_kingdom {
            return "Cannot enter \(travelEvent.kingdom_name)"
        } else if travelEvent.travel_fee_paid > 0 {
            return "Paid \(travelEvent.travel_fee_paid)g to enter \(travelEvent.kingdom_name)"
        } else if let reason = travelEvent.free_travel_reason {
            switch reason {
            case "ruler":
                return "Free travel as ruler of \(travelEvent.kingdom_name)"
            case "property_owner":
                return "Free travel - you own property here"
            case "allied":
                return "Free travel - allied empire"
            default:
                return "Entered \(travelEvent.kingdom_name)"
            }
        } else {
            return "Entered \(travelEvent.kingdom_name)"
        }
    }
}

#Preview {
    ZStack {
        KingdomTheme.Colors.parchment
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Fee paid
            TravelNotificationToast(
                travelEvent: TravelEvent(
                    entered_kingdom: true,
                    kingdom_name: "Boston",
                    travel_fee_paid: 50,
                    free_travel_reason: nil,
                    denied: nil,
                    denial_reason: nil
                ),
                onDismiss: {}
            )
            
            // Free travel as ruler
            TravelNotificationToast(
                travelEvent: TravelEvent(
                    entered_kingdom: true,
                    kingdom_name: "Cambridge",
                    travel_fee_paid: 0,
                    free_travel_reason: "ruler",
                    denied: nil,
                    denial_reason: nil
                ),
                onDismiss: {}
            )
            
            // Free travel as property owner
            TravelNotificationToast(
                travelEvent: TravelEvent(
                    entered_kingdom: true,
                    kingdom_name: "Somerville",
                    travel_fee_paid: 0,
                    free_travel_reason: "property_owner",
                    denied: nil,
                    denial_reason: nil
                ),
                onDismiss: {}
            )
            
            // Denied entry (insufficient gold)
            TravelNotificationToast(
                travelEvent: TravelEvent(
                    entered_kingdom: false,
                    kingdom_name: "Brookline",
                    travel_fee_paid: 0,
                    free_travel_reason: nil,
                    denied: true,
                    denial_reason: "Insufficient gold. Need 100g to enter."
                ),
                onDismiss: {}
            )
        }
        .padding()
    }
}

