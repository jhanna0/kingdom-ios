import SwiftUI

struct FloatingNotificationsButton: View {
    @Binding var showNotifications: Bool
    let hasUnread: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showNotifications = true
                }) {
                    ZStack {
                        // Brutalist offset shadow
                        Circle()
                            .fill(Color.black)
                            .frame(width: 60, height: 60)
                            .offset(x: 4, y: 4)
                        
                        // Main button
                        Circle()
                            .fill(KingdomTheme.Colors.inkMedium)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Image(systemName: "scroll.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Simple dot indicator centered on top-right of circle border
                        if hasUnread {
                            ZStack {
                                // Dot shadow
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 16, height: 16)
                                    .offset(x: 2, y: 2)
                                
                                Circle()
                                    .fill(KingdomTheme.Colors.buttonDanger)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }
                            // Position at 45° on the circle border (radius 30)
                            // cos(45°) ≈ 0.707, so offset ≈ 21
                            .offset(x: 21, y: -21)
                        }
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: [])
    }
}

#Preview {
    ZStack {
        Color.gray
        FloatingNotificationsButton(showNotifications: .constant(false), hasUnread: true)
    }
}

