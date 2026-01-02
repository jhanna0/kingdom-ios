import SwiftUI

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let icon: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(FontStyles.iconLarge)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(description)
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Spacer()
            }
        }
        .padding()
        .brutalistCard()
        .padding(.horizontal)
    }
}



