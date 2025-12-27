import SwiftUI

// Medieval-styled action button
struct MedievalActionButton: View {
    let title: String
    let color: Color
    var fullWidth: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.95, green: 0.87, blue: 0.70))
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 1, y: 2)
        }
    }
}

