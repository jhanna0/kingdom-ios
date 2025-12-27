import SwiftUI

// Medieval-styled action button - now uses centralized theme
struct MedievalActionButton: View {
    let title: String
    let color: Color
    var fullWidth: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(.medieval(color: color, fullWidth: fullWidth))
    }
}
