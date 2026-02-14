import SwiftUI

// MARK: - Cooldown Timer

struct CooldownTimer: View {
    let secondsRemaining: Int
    let totalSeconds: Int?
    let onBookTap: (() -> Void)?  // Optional book button callback
    
    init(secondsRemaining: Int, totalSeconds: Int? = nil, onBookTap: (() -> Void)? = nil) {
        self.secondsRemaining = secondsRemaining
        self.totalSeconds = totalSeconds
        self.onBookTap = onBookTap
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
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                
                Text("In Progress")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Text(formattedTime)
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Book button (skip cooldown)
                if let onBookTap = onBookTap {
                    Button(action: onBookTap) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .brutalistBadge(backgroundColor: .brown, cornerRadius: 6, shadowOffset: 2, borderWidth: 1.5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(height: 38)
            
            // Progress bar - brutalist style
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.parchmentDark)
                        .frame(height: 12)
                        .brutalistProgressBar()
                    
                    Rectangle()
                        .fill(KingdomTheme.Colors.buttonWarning)
                        .frame(width: max(0, geometry.size.width * progress - 4), height: 8)
                        .offset(x: 2)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

