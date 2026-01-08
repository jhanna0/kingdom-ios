import SwiftUI

// MARK: - Combat HP Bar
// Visual HP indicator for strike phase

struct CombatHPBar: View {
    let animal: HuntAnimal?
    let animalHP: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Animal icon with brutalist badge
            Text(animal?.icon ?? "🎯")
                .font(.system(size: 32))
                .frame(width: 48, height: 48)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.parchmentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                    Text("\(animal?.name ?? "Prey") HP: \(animalHP)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                }
                
                Text("Deal damage to slay the creature!")
                    .font(.system(size: 10))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.vertical, 4)
    }
}
