import SwiftUI

// MARK: - Kingdom Buildings

extension KingdomInfoSheetView {
    
    // MARK: - Kingdom Buildings Card
    
    var kingdomBuildingsCard: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("Buildings")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            let sortedBuildings = kingdom.sortedBuildings()
            
            if sortedBuildings.isEmpty {
                ProgressView().padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedBuildings, id: \.type) { building in
                        buildingRow(building: building)
                    }
                }
            }
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .padding(.horizontal)
    }
    
    // MARK: - Building Row
    
    @ViewBuilder
    func buildingRow(building: BuildingMetadata) -> some View {
        let isBuilt = building.level > 0
        let color = Color(hex: building.colorHex) ?? KingdomTheme.Colors.inkMedium
        // DYNAMIC: Building is clickable if backend says so AND player is inside
        let isClickable = isPlayerInside && building.isClickable
        // Check if player needs to complete catch-up work
        let needsCatchup = building.needsCatchup && isPlayerInside
        
        let content = HStack(spacing: 10) {
            // Icon with level badge - brutalist style
            ZStack(alignment: .topTrailing) {
                Image(systemName: building.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .brutalistBadge(
                        backgroundColor: isBuilt ? color : KingdomTheme.Colors.inkLight,
                        cornerRadius: 8,
                        shadowOffset: 2,
                        borderWidth: 2
                    )
                
                if isBuilt {
                    Text("\(building.level)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .brutalistBadge(backgroundColor: .black, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
                        .offset(x: 6, y: -6)
                }
            }
            
            // Name + description
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(building.displayName)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    // Show expand badge if building needs capacity expansion
                    if needsCatchup {
                        Text("EXPAND")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(KingdomTheme.Colors.buttonWarning)
                            .cornerRadius(4)
                    }
                }
                
                if needsCatchup, let catchup = building.catchup {
                    Text("\(catchup.actionsCompleted)/\(catchup.actionsRequired) actions to unlock")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        .lineLimit(1)
                } else {
                    Text(building.description)
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Chevron for clickable buildings or catchup
            if isClickable || needsCatchup {
                Image(systemName: needsCatchup ? "hammer.fill" : "chevron.right")
                    .font(FontStyles.iconMini)
                    .foregroundColor(needsCatchup ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(10)
        .background(isBuilt ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(needsCatchup ? KingdomTheme.Colors.buttonWarning : Color.black, lineWidth: needsCatchup ? 2 : 1.5))
        
        // Handle click: catchup takes priority over normal action
        if needsCatchup {
            Button {
                catchupBuilding = building
            } label: { content }
            .buttonStyle(.plain)
        } else if isClickable, let clickAction = building.clickAction {
            Button {
                activeBuildingAction = clickAction
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
