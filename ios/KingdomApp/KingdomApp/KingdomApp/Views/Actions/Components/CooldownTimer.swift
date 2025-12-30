import SwiftUI

// MARK: - Cooldown Timer

struct CooldownTimer: View {
    let secondsRemaining: Int
    let totalSeconds: Int?
    
    init(secondsRemaining: Int, totalSeconds: Int? = nil) {
        self.secondsRemaining = secondsRemaining
        self.totalSeconds = totalSeconds
    }
    
    var progress: Double {
        guard let total = totalSeconds, total > 0 else { return 0 }
        let elapsed = Double(total - secondsRemaining)
        return min(max(elapsed / Double(total), 0), 1.0)
    }
    
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                
                Text("In Progress")
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formattedTime)
                    .font(KingdomTheme.Typography.body())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .fontWeight(.medium)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.buttonWarning)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.linear(duration: 0.5), value: progress)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(KingdomTheme.Colors.parchmentDark)
        .cornerRadius(KingdomTheme.CornerRadius.medium)
    }
}

