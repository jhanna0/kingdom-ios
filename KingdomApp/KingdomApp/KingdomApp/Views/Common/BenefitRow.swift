import SwiftUI

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                .frame(width: 20)
            
            Text(text)
                .font(.system(.caption, design: .serif))
                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
            
            Spacer()
        }
    }
}

