import SwiftUI

/// Unified action button used across training, crafting, property upgrades, etc.
/// Uses EXACT MapHUD button style
struct UnifiedActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isEnabled: Bool
    let statusMessage: String?
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        isEnabled: Bool,
        statusMessage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isEnabled = isEnabled
        self.statusMessage = statusMessage
        self.action = action
    }
    
    var body: some View {
        if isEnabled {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KingdomTheme.Colors.buttonPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            }
            .buttonStyle(.plain)
        } else if let message = statusMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(message)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(KingdomTheme.Colors.buttonWarning)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black)
                        .offset(x: 2, y: 2)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(KingdomTheme.Colors.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            )
        }
    }
}

/// Unified cost/requirement display row
struct ResourceRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let required: Int
    let available: Int
    
    var canAfford: Bool {
        available >= required
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(required)")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundColor(canAfford ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.buttonDanger)
                
                Text("/")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("\(available)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundColor(canAfford ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding(.vertical, 4)
    }
}
