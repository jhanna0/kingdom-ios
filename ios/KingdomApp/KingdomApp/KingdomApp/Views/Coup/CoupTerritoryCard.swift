import SwiftUI

/// Territory card for coup battles
/// Shows tug-of-war bar and fight button
struct CoupTerritoryCard: View {
    let territory: CoupTerritory
    let userSide: String?
    let canFight: Bool
    let onFight: () -> Void
    
    private var isUserAttacker: Bool {
        userSide == "attackers"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with icon and name
            HStack(spacing: 10) {
                Image(systemName: territory.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(
                        backgroundColor: territory.isCaptured 
                            ? (territory.capturedBy == "attackers" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
                            : KingdomTheme.Colors.inkMedium,
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(territory.displayName.uppercased())
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if territory.isCaptured {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                            Text("Captured by \(territory.capturedBy ?? "")")
                                .font(FontStyles.labelBadge)
                        }
                        .foregroundColor(territory.capturedBy == "attackers" ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
                    }
                }
                
                Spacer()
            }
            
            // Tug-of-war bar (user's side always on left)
            TugOfWarBar(
                value: territory.controlBar,
                isCaptured: territory.isCaptured,
                capturedBy: territory.capturedBy,
                userIsAttacker: isUserAttacker
            )
            
            // Fight button (only if not captured)
            if !territory.isCaptured {
                Button(action: onFight) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("FIGHT HERE")
                            .font(FontStyles.labelBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: canFight 
                        ? (isUserAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue)
                        : KingdomTheme.Colors.disabled,
                    foregroundColor: .white,
                    fullWidth: true
                ))
                .disabled(!canFight)
            }
        }
        .padding(14)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 14)
    }
}

// MARK: - Tug-of-War Bar

struct TugOfWarBar: View {
    let value: Double  // 0-100, where 0 = attackers captured, 100 = defenders captured
    let isCaptured: Bool
    let capturedBy: String?
    var userIsAttacker: Bool = true  // If true, user (left) is attacker. If false, flip the bar.
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 28
            let progress = min(1.0, max(0.0, value / 100.0))
            
            // User's side is always on the LEFT
            // If user is attacker: attackerWidth from left (low value = more progress)
            // If user is defender: defenderWidth from left (high value = more progress)
            let userProgress = userIsAttacker ? (1 - progress) : progress
            let userWidth = width * userProgress
            let userColor = userIsAttacker ? KingdomTheme.Colors.buttonDanger : KingdomTheme.Colors.royalBlue
            let enemyColor = userIsAttacker ? KingdomTheme.Colors.royalBlue : KingdomTheme.Colors.buttonDanger
            
            ZStack(alignment: .leading) {
                // Background (enemy side)
                RoundedRectangle(cornerRadius: 8)
                    .fill(enemyColor.opacity(0.3))
                
                // User progress (from left)
                RoundedRectangle(cornerRadius: 8)
                    .fill(userColor.opacity(0.7))
                    .frame(width: userWidth)
                
                // Center marker (50% line)
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 2, height: height - 8)
                    .position(x: width / 2, y: height / 2)
                
                // Current position marker
                if !isCaptured {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4, height: height - 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .position(x: max(6, min(width - 6, userWidth)), y: height / 2)
                }
                
                // Labels - YOU on left, ENEMY on right
                HStack {
                    Text("YOU")
                        .font(.system(size: 9, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .padding(.leading, 6)
                    
                    Spacer()
                    
                    // Percentage in center
                    let userPct = Int(userProgress * 100)
                    let enemyPct = 100 - userPct
                    Text(isCaptured ? "CAPTURED" : "\(userPct)% vs \(enemyPct)%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("ENEMY")
                        .font(.system(size: 9, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .padding(.trailing, 6)
                }
                
                // Border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 2)
            }
            .frame(height: height)
        }
        .frame(height: 28)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CoupTerritoryCard(
            territory: CoupTerritory(
                name: "throne_room",
                displayName: "Throne Room",
                icon: "building.columns.fill",
                controlBar: 50.0,
                capturedBy: nil,
                capturedAt: nil
            ),
            userSide: "attackers",
            canFight: true,
            onFight: {}
        )
        
        CoupTerritoryCard(
            territory: CoupTerritory(
                name: "coupers_territory",
                displayName: "Coupers Territory",
                icon: "figure.fencing",
                controlBar: 15.0,
                capturedBy: nil,
                capturedAt: nil
            ),
            userSide: "attackers",
            canFight: false,
            onFight: {}
        )
        
        CoupTerritoryCard(
            territory: CoupTerritory(
                name: "crowns_territory",
                displayName: "Crowns Territory",
                icon: "crown.fill",
                controlBar: 100.0,
                capturedBy: "defenders",
                capturedAt: "2024-01-01T00:00:00Z"
            ),
            userSide: "attackers",
            canFight: false,
            onFight: {}
        )
    }
    .padding()
    .parchmentBackground()
}
