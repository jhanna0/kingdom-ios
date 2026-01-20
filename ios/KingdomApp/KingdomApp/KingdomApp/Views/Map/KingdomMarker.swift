import SwiftUI

// Kingdom marker on map - Bold brutalist style with visual indicators
struct KingdomMarker: View {
    let kingdom: Kingdom
    let homeKingdomId: String?
    let playerId: Int
    
    // Animation state
    @State private var isPressed = false
    
    // Visual state
    private var isUnclaimed: Bool { kingdom.isUnclaimed }
    private var isHomeKingdom: Bool { kingdom.id == homeKingdomId }
    
    // Match EXACTLY what DrawnMapView uses for polygon colors
    private var markerBackgroundColor: Color {
        return KingdomTheme.Colors.territoryColor(
            kingdomId: kingdom.id,
            isPlayer: isHomeKingdom,
            isEnemy: kingdom.isEnemy,
            isAllied: kingdom.isAllied,
            isAtWar: isHomeKingdom && kingdom.isAtWar
        )
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Main castle marker - clean brutalist style
            ZStack {
                // Offset shadow
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)
                    .frame(width: 56, height: 56)
                    .offset(x: 3, y: 3)
                
                // Main marker - colored background like a game piece
                RoundedRectangle(cornerRadius: 14)
                    .fill(markerBackgroundColor)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black, lineWidth: 3)
                    )
                
                // Kingdom icon - white on colored background (game piece style)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                // Level badge - brutalist style
                ZStack {
                    // Badge shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: 24, height: 24)
                        .offset(x: 2, y: 2)
                    
                    Circle()
                        .fill(markerBackgroundColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    Text("\(kingdom.buildingLevel("wall"))")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                }
                .offset(x: 22, y: 22)
                
                // Status badge: War icon if at war, Crown if claimed
                if kingdom.isAtWar {
                    // At war - show crossed swords
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 22, height: 22)
                            .offset(x: 1, y: 1)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.buttonSpecial)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                        
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -22, y: -22)
                } else if !isUnclaimed {
                    // Crown for claimed kingdoms (no active coup)
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 20, height: 20)
                            .offset(x: 1, y: 1)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.imperialGold)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -22, y: -22)
                }
            }
            
            // Kingdom name banner - brutalist style
            Text(kingdom.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        // Banner shadow
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .offset(x: 2, y: 2)
                        
                        // Banner background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                )
            
            // Status indicators (if any) - brutalist style
            if !kingdom.allies.isEmpty || !kingdom.enemies.isEmpty {
                HStack(spacing: 6) {
                    if !kingdom.allies.isEmpty {
                        StatusBadge(
                            icon: "person.2.fill",
                            color: KingdomTheme.Colors.buttonSuccess
                        )
                    }
                    if !kingdom.enemies.isEmpty {
                        StatusBadge(
                            icon: "flame.fill",
                            color: KingdomTheme.Colors.buttonDanger
                        )
                    }
                }
            }
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Status Badge Component
private struct StatusBadge: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 20, height: 20)
                .offset(x: 1, y: 1)
            
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                )
            
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
