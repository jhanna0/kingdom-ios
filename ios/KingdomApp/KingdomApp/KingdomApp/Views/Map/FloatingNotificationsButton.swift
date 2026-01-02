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
                        // Brutalist offset shadow
                        Circle()
                            .fill(Color.black)
                            .frame(width: 60, height: 60)
                            .offset(x: 4, y: 4)
                        
                        // Main button
                        Circle()
                            .fill(KingdomTheme.Colors.gold)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Image(systemName: "bell.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                        
                        // Badge with brutalist style
                        if badgeCount > 0 {
                            ZStack {
                                // Badge shadow
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 26, height: 26)
                                    .offset(x: 2, y: 2)
                                
                                Circle()
                                    .fill(KingdomTheme.Colors.buttonDanger)
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                
                                Text("\(min(badgeCount, 99))")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
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
        FloatingNotificationsButton(showNotifications: .constant(false), badgeCount: 3)
    }
}

