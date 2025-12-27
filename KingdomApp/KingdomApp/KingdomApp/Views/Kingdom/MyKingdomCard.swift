import SwiftUI

// Kingdom card for the list
struct MyKingdomCard: View {
    let kingdom: Kingdom
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Castle icon with color
            ZStack {
                Circle()
                    .fill(
                        Color(
                            red: kingdom.color.rgba.red,
                            green: kingdom.color.rgba.green,
                            blue: kingdom.color.rgba.blue,
                            opacity: kingdom.color.rgba.alpha
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(
                                    red: kingdom.color.strokeRGBA.red,
                                    green: kingdom.color.strokeRGBA.green,
                                    blue: kingdom.color.strokeRGBA.blue
                                ),
                                lineWidth: KingdomTheme.BorderWidth.regular
                            )
                    )
                
                Text("🏰")
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(kingdom.name)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    Label("\(kingdom.treasuryGold)g", systemImage: "dollarsign.circle.fill")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Label("\(kingdom.checkedInPlayers)", systemImage: "person.2.fill")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}
