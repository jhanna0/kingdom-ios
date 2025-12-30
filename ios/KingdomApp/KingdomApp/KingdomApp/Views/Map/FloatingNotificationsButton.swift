import SwiftUI

struct FloatingNotificationsButton: View {
    @Binding var showNotifications: Bool
    let badgeCount: Int
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showNotifications = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        KingdomTheme.Colors.gold,
                                        KingdomTheme.Colors.gold.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "bell.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                        
                        // Badge
                        if badgeCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(KingdomTheme.Colors.buttonDanger)
                                    .frame(width: 24, height: 24)
                                
                                Text("\(min(badgeCount, 99))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Above the HUD buttons
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        FloatingNotificationsButton(showNotifications: .constant(false), badgeCount: 3)
    }
}

