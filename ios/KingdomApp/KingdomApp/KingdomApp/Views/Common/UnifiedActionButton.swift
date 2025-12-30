import SwiftUI

/// Unified action button used across training, crafting, property upgrades, etc.
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
                        .font(.subheadline)
                    Text(title)
                        .font(.subheadline.bold())
                }
                .foregroundColor(KingdomTheme.Colors.parchmentLight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(KingdomTheme.Colors.buttonPrimary)
                .cornerRadius(10)
            }
        } else if let message = statusMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                Text(message)
                    .font(.subheadline)
            }
            .foregroundColor(KingdomTheme.Colors.buttonWarning)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
            .cornerRadius(10)
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
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(required)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(canAfford ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.buttonDanger)
                
                Text("/")
                    .font(.caption)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("\(available)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(canAfford ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.buttonDanger)
            }
        }
        .padding(.vertical, 4)
    }
}

