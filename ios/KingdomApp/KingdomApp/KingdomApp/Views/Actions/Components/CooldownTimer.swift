import SwiftUI

// MARK: - Cooldown Timer

struct CooldownTimer: View {
    let secondsRemaining: Int
    
    var formattedTime: String {
        let hours = secondsRemaining / 3600
        let minutes = (secondsRemaining % 3600) / 60
        let seconds = secondsRemaining % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(KingdomTheme.Colors.disabled)
            
            Text("Available in \(formattedTime)")
                .font(KingdomTheme.Typography.body())
                .foregroundColor(KingdomTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(KingdomTheme.Colors.parchmentDark)
        .cornerRadius(KingdomTheme.CornerRadius.medium)
    }
}

