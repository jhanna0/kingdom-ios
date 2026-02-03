import SwiftUI

// Kingdom marker on map - Bold brutalist style with visual indicators
struct KingdomMarker: View {
    let kingdom: Kingdom
    let homeKingdomId: String?
    let playerId: Int
    let markerScale: CGFloat  // Scale factor based on territory size (0.5 - 1.0)
    
    // Animation state
    @State private var isPressed = false
    
    // Visual state
    private var isUnclaimed: Bool { kingdom.isUnclaimed }
    private var isHomeKingdom: Bool { kingdom.id == homeKingdomId }
    
    // Scaled dimensions
    private var mainSize: CGFloat { 56 * markerScale }
    private var cornerRadius: CGFloat { 14 * markerScale }
    private var shadowOffset: CGFloat { 3 * markerScale }
    private var iconSize: CGFloat { 28 * markerScale }
    private var borderWidth: CGFloat { max(2, 3 * markerScale) }
    private var levelBadgeSize: CGFloat { 24 * markerScale }
    private var levelBadgeFontSize: CGFloat { 11 * markerScale }
    private var levelBadgeOffset: CGFloat { 22 * markerScale }
    private var statusBadgeSize: CGFloat { 22 * markerScale }
    private var statusBadgeSizeSmall: CGFloat { 20 * markerScale }
    private var statusIconSize: CGFloat { 10 * markerScale }
    private var statusBadgeOffset: CGFloat { 22 * markerScale }
    private var nameFontSize: CGFloat { max(10, 12 * markerScale) }
    private var namePaddingH: CGFloat { 10 * markerScale }
    private var namePaddingV: CGFloat { 5 * markerScale }
    
    // Match EXACTLY what DrawnMapView uses for polygon colors
    private var markerBackgroundColor: Color {
        return KingdomTheme.Colors.territoryColor(
            kingdomId: kingdom.id,
            isPlayer: isHomeKingdom,
            isEnemy: kingdom.isEnemy,
            isAllied: kingdom.isAllied,
            isAtWar: isHomeKingdom && kingdom.isAtWar,
            isPartOfEmpire: kingdom.isEmpire
        )
    }
    
    var body: some View {
        VStack(spacing: 6 * markerScale) {
            // Main castle marker - clean brutalist style
            ZStack {
                // Offset shadow
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black)
                    .frame(width: mainSize, height: mainSize)
                    .offset(x: shadowOffset, y: shadowOffset)
                
                // Main marker - colored background like a game piece
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(markerBackgroundColor)
                    .frame(width: mainSize, height: mainSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.black, lineWidth: borderWidth)
                    )
                
                // Kingdom icon - white on colored background (game piece style)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.white)
                
                // Level badge - brutalist style
                ZStack {
                    // Badge shadow
                    Circle()
                        .fill(Color.black)
                        .frame(width: levelBadgeSize, height: levelBadgeSize)
                        .offset(x: 2 * markerScale, y: 2 * markerScale)
                    
                    Circle()
                        .fill(markerBackgroundColor)
                        .frame(width: levelBadgeSize, height: levelBadgeSize)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                        )
                    
                    Text("\(kingdom.buildingLevel("wall"))")
                        .font(.system(size: levelBadgeFontSize, weight: .black))
                        .foregroundColor(.white)
                }
                .offset(x: levelBadgeOffset, y: levelBadgeOffset)
                
                // Status badge: War icon if at war, Crown if claimed
                if kingdom.isAtWar {
                    // At war - show crossed swords
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .offset(x: 1 * markerScale, y: 1 * markerScale)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.buttonSpecial)
                            .frame(width: statusBadgeSize, height: statusBadgeSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                        
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: statusIconSize, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -statusBadgeOffset, y: -statusBadgeOffset)
                } else if !isUnclaimed {
                    // Crown for claimed kingdoms (no active coup)
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: statusBadgeSizeSmall, height: statusBadgeSizeSmall)
                            .offset(x: 1 * markerScale, y: 1 * markerScale)
                        
                        Circle()
                            .fill(KingdomTheme.Colors.imperialGold)
                            .frame(width: statusBadgeSizeSmall, height: statusBadgeSizeSmall)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: statusIconSize, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: -statusBadgeOffset, y: -statusBadgeOffset)
                }
            }
            
            // Kingdom name banner - brutalist style
            Text(kingdom.name)
                .font(.system(size: nameFontSize, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.horizontal, namePaddingH)
                .padding(.vertical, namePaddingV)
                .background(
                    ZStack {
                        // Banner shadow
                        RoundedRectangle(cornerRadius: 8 * markerScale)
                            .fill(Color.black)
                            .offset(x: 2 * markerScale, y: 2 * markerScale)
                        
                        // Banner background
                        RoundedRectangle(cornerRadius: 8 * markerScale)
                            .fill(KingdomTheme.Colors.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8 * markerScale)
                                    .stroke(Color.black, lineWidth: max(1.5, 2 * markerScale))
                            )
                    }
                )
            
            // Status indicators (if any) - brutalist style
            if !kingdom.allies.isEmpty || !kingdom.enemies.isEmpty {
                HStack(spacing: 6 * markerScale) {
                    if !kingdom.allies.isEmpty {
                        StatusBadge(
                            icon: "person.2.fill",
                            color: KingdomTheme.Colors.buttonSuccess,
                            scale: markerScale
                        )
                    }
                    if !kingdom.enemies.isEmpty {
                        StatusBadge(
                            icon: "flame.fill",
                            color: KingdomTheme.Colors.buttonDanger,
                            scale: markerScale
                        )
                    }
                }
            }
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
    
    // MARK: - Helper to calculate marker scale from territory radius
    
    /// Calculates marker scale factor based on territory radius
    /// - Parameter radiusMeters: The territory radius in meters
    /// - Returns: Either small (0.65) or normal (1.0) scale
    static func calculateScale(for radiusMeters: Double) -> CGFloat {
        let threshold: Double = 4000  // Below 5km = small marker
        return radiusMeters < threshold ? 0.65 : 1.0
    }
}

// MARK: - Status Badge Component
private struct StatusBadge: View {
    let icon: String
    let color: Color
    let scale: CGFloat
    
    var body: some View {
        let size: CGFloat = 20 * scale
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
                .offset(x: 1 * scale, y: 1 * scale)
            
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: max(1.5, 2 * scale))
                )
            
            Image(systemName: icon)
                .font(.system(size: 9 * scale, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
