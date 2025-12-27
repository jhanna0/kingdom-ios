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
                    .fill(Color(red: 0.95, green: 0.87, blue: 0.70))  // Old parchment color
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(
                                    red: kingdom.color.strokeRGBA.red,
                                    green: kingdom.color.strokeRGBA.green,
                                    blue: kingdom.color.strokeRGBA.blue
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 2, y: 2)
                
                Text("🏰")
                    .font(.system(size: 22))
            }
            
            // Town name with parchment scroll style
            Text(kingdom.name)
                .font(.system(size: 11, weight: .bold, design: .serif))  // Serif for medieval feel
                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))  // Dark brown ink
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.95, green: 0.87, blue: 0.70))  // Parchment
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(
                                    Color(
                                        red: kingdom.color.strokeRGBA.red,
                                        green: kingdom.color.strokeRGBA.green,
                                        blue: kingdom.color.strokeRGBA.blue
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 1, y: 2)
        }
    }
}

