import SwiftUI

struct BuildingUpgradeCard: View {
    let icon: String
    let name: String
    let currentLevel: Int
    let maxLevel: Int
    let cost: Int
    let benefit: String
    let kingdomTreasury: Int
    let onUpgrade: () -> Void
    
    var canAfford: Bool {
        kingdomTreasury >= cost
    }
    
    var isMaxLevel: Bool {
        currentLevel >= maxLevel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.title3, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                    
                    Text("Level \(currentLevel)/\(maxLevel)")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
                
                Spacer()
            }
            
            if !isMaxLevel {
                Text(benefit)
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color(red: 0.3, green: 0.15, blue: 0.05))
                    .padding(.vertical, 4)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption)
                        Text("\(cost)")
                            .font(.system(.headline, design: .serif))
                            .fontWeight(.bold)
                        Text("from treasury")
                            .font(.system(.caption, design: .serif))
                    }
                    .foregroundColor(canAfford ? Color(red: 0.4, green: 0.2, blue: 0.1) : .red)
                    
                    Spacer()
                    
                    Button(action: onUpgrade) {
                        Text("Upgrade")
                            .font(.system(.subheadline, design: .serif))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(canAfford ? Color(red: 0.5, green: 0.3, blue: 0.1) : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!canAfford)
                }
            } else {
                Text("Maximum level reached")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                    .italic()
            }
        }
        .padding()
        .background(Color(red: 0.98, green: 0.92, blue: 0.80))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
        )
    }
}

