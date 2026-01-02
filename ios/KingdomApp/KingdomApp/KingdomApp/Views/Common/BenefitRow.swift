import SwiftUI

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 20)
            
            Text(text)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
        }
    }
}
