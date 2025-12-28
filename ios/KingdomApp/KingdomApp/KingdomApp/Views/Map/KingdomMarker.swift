import SwiftUI

// Kingdom marker on map - Medieval war map style
struct KingdomMarker: View {
    let kingdom: Kingdom
    
    var body: some View {
        VStack(spacing: 3) {
            // Medieval castle icon with parchment background
            ZStack {
                // Parchment-style background
                Circle()
                    .fill(KingdomTheme.Colors.parchment)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(
                                    red: kingdom.color.strokeRGBA.red,
                                    green: kingdom.color.strokeRGBA.green,
                                    blue: kingdom.color.strokeRGBA.blue
                                ),
                                lineWidth: KingdomTheme.BorderWidth.thick
                            )
                    )
                    .shadow(
                        color: KingdomTheme.Shadows.card.color,
                        radius: 4,
                        x: 2,
                        y: 2
                    )
                
                Text("🏰")
                    .font(.system(size: 22))
            }
            
            // Town name with parchment scroll style
            Text(kingdom.name)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(KingdomTheme.Colors.inkDark)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(
                                    Color(
                                        red: kingdom.color.strokeRGBA.red,
                                        green: kingdom.color.strokeRGBA.green,
                                        blue: kingdom.color.strokeRGBA.blue
                                    ),
                                    lineWidth: KingdomTheme.BorderWidth.regular
                                )
                        )
                )
                .shadow(
                    color: KingdomTheme.Shadows.button.color,
                    radius: KingdomTheme.Shadows.button.radius,
                    x: KingdomTheme.Shadows.button.x,
                    y: KingdomTheme.Shadows.button.y
                )
        }
    }
}
