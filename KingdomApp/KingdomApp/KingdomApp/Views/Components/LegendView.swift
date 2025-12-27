import SwiftUI

// Legend showing kingdom info - Medieval scroll style
struct LegendView: View {
    let kingdomCount: Int
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⚔️ \(kingdomCount) Kingdoms")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
                }
            }
            
            Text("Ancient territories")
                .font(.system(.caption, design: .serif))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
        }
        .padding(12)
        .background(Color(red: 0.95, green: 0.87, blue: 0.70))  // Parchment
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 2, y: 3)
    }
}

