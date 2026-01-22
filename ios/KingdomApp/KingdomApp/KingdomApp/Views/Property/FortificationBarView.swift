import SwiftUI

/// Compact fortification bar for displaying in property cards and lists
struct FortificationBarView: View {
    let percent: Int
    let basePercent: Int
    let showLabel: Bool
    let height: CGFloat
    
    private let fortificationColor = KingdomTheme.Colors.royalBlue
    
    init(percent: Int, basePercent: Int = 0, showLabel: Bool = true, height: CGFloat = 16) {
        self.percent = percent
        self.basePercent = basePercent
        self.showLabel = showLabel
        self.height = height
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 12))
                        .foregroundColor(fortificationColor)
                    
                    Text("Fortification")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("\(percent)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(fortificationColor)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KingdomTheme.Colors.parchmentDark)
                    
                    // Base fortification (T5 only) - lighter shade
                    if basePercent > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fortificationColor.opacity(0.3))
                            .frame(width: geometry.size.width * CGFloat(basePercent) / 100.0)
                    }
                    
                    // Current fortification
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fortificationColor)
                        .frame(width: geometry.size.width * CGFloat(percent) / 100.0)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black, lineWidth: 1.5)
                }
            }
            .frame(height: height)
        }
    }
}

/// Mini fortification indicator for compact spaces
struct FortificationBadge: View {
    let percent: Int
    
    private let fortificationColor = KingdomTheme.Colors.royalBlue
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 10))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .brutalistBadge(
            backgroundColor: fortificationColor,
            cornerRadius: 6,
            shadowOffset: 1,
            borderWidth: 1.5
        )
    }
}

// MARK: - Preview

#Preview("Fortification Bar") {
    VStack(spacing: 20) {
        FortificationBarView(percent: 0)
        FortificationBarView(percent: 35)
        FortificationBarView(percent: 75, basePercent: 50)
        FortificationBarView(percent: 100)
        
        HStack {
            FortificationBadge(percent: 42)
            FortificationBadge(percent: 100)
        }
    }
    .padding()
    .background(KingdomTheme.Colors.parchment)
}
