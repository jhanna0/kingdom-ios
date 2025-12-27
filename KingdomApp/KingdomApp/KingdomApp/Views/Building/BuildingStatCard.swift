import SwiftUI

struct BuildingStatCard: View {
    let icon: String
    let name: String
    let level: Int
    let maxLevel: Int
    let benefit: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text(name)
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
            
            Text("Level \(level)/\(maxLevel)")
                .font(.system(.caption, design: .serif))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text(benefit)
                .font(.system(.caption2, design: .serif))
                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(red: 0.98, green: 0.92, blue: 0.80))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 1.5)
        )
    }
}

