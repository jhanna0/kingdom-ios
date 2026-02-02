import SwiftUI

struct FloatingAchievementsButton: View {
    @Binding var showAchievements: Bool
    let claimableCount: Int
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Button(action: {
                    showAchievements = true
                }) {
                    ZStack {
                        // Main button
                        Circle()
                            .fill(KingdomTheme.Colors.buttonSuccess)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                            )
                        
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Badge for claimable achievements
                        if claimableCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                
                                Text("\(min(claimableCount, 99))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 21, y: -21)
                        }
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 20)
                .padding(.bottom, 20)
                
                Spacer()
            }
        }
        .ignoresSafeArea(edges: [])
    }
}

#Preview {
    ZStack {
        Color.gray
        FloatingAchievementsButton(showAchievements: .constant(false), claimableCount: 3)
    }
}
