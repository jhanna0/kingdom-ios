import SwiftUI

// Kingdom card for the list
struct MyKingdomCard: View {
    let kingdom: Kingdom
    
    var body: some View {
        HStack(spacing: 12) {
            // Castle icon with color
            ZStack {
                Circle()
                    .fill(
                        Color(
                            red: kingdom.color.rgba.red,
                            green: kingdom.color.rgba.green,
                            blue: kingdom.color.rgba.blue,
                            opacity: kingdom.color.rgba.alpha
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(
                                    red: kingdom.color.strokeRGBA.red,
                                    green: kingdom.color.strokeRGBA.green,
                                    blue: kingdom.color.strokeRGBA.blue
                                ),
                                lineWidth: 2
                            )
                    )
                
                Text("🏰")
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(kingdom.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                
                HStack(spacing: 12) {
                    Label("\(kingdom.treasuryGold)g", systemImage: "dollarsign.circle.fill")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    
                    Label("\(kingdom.checkedInPlayers)", systemImage: "person.2.fill")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
        }
        .padding()
        .background(Color(red: 0.98, green: 0.92, blue: 0.80))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 1, y: 2)
    }
}

