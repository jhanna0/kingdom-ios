import SwiftUI

/// Reusable blocking error overlay - blocks entire UI until error is resolved
/// Used for critical failures that prevent the app from functioning
struct BlockingErrorView: View {
    let title: String
    let message: String
    let primaryAction: ErrorAction
    let secondaryAction: ErrorAction?
    
    struct ErrorAction {
        let label: String
        let icon: String
        let color: Color
        let action: () -> Void
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: KingdomTheme.Spacing.large) {
                // Error icon with brutalist badge
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .offset(x: 3, y: 3)
                    
                    Circle()
                        .fill(KingdomTheme.Colors.buttonDanger)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Button(action: primaryAction.action) {
                        Label(primaryAction.label, systemImage: primaryAction.icon)
                    }
                    .buttonStyle(.brutalist(backgroundColor: primaryAction.color))
                    
                    if let secondary = secondaryAction {
                        Button(action: secondary.action) {
                            Label(secondary.label, systemImage: secondary.icon)
                        }
                        .buttonStyle(.brutalist(backgroundColor: secondary.color))
                    }
                }
            }
            .padding(KingdomTheme.Spacing.xxLarge)
            .brutalistCard(cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

