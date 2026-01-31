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
                        
                        // Simple dot indicator
                        if hasUnread {
                            Circle()
                                .fill(KingdomTheme.Colors.buttonDanger)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 2)
                                )
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
