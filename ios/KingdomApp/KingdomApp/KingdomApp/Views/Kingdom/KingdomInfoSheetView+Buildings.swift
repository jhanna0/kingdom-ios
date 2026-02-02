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
        // Check if player needs a permit (visiting and not allied)
        let needsPermit = isPlayerInside && (building.permit?.showBuyPermit ?? false)
        let hasValidPermit = building.permit?.hasValidPermit ?? false
        let permitBlocked = isPlayerInside && (building.permit?.needsPermit == true && !hasValidPermit && !(building.permit?.canBuyPermit ?? false))
        
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
                    
                    // Show permit badge if player needs to buy one
                    if needsPermit {
                        if let permit = building.permit {
                            Text("\(permit.permitCost)g")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(KingdomTheme.Colors.gold)
                                .cornerRadius(4)
                        }
                    } else if hasValidPermit, let permit = building.permit {
                        Text("\(permit.permitMinutesRemaining)m")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(KingdomTheme.Colors.buttonSuccess)
                            .cornerRadius(4)
                    }
                }
                
                if needsCatchup, let catchup = building.catchup {
                    Text("\(catchup.actionsCompleted)/\(catchup.actionsRequired) actions to unlock")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.buttonWarning)
                        .lineLimit(1)
                } else if permitBlocked, let permit = building.permit {
                    Text(permit.reason)
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.buttonDanger)
                        .lineLimit(1)
                } else if needsPermit, let permit = building.permit {
                    Text("Permit: \(permit.permitCost)g for \(permit.permitDurationMinutes)m")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .lineLimit(1)
                } else if hasValidPermit, let permit = building.permit {
                    Text("Permit active • \(permit.permitMinutesRemaining)m remaining")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        .lineLimit(1)
                } else {
                    Text(building.description)
                        .font(FontStyles.labelTiny)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Chevron/icon for clickable buildings
            if needsCatchup {
                Image(systemName: "hammer.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
            } else if needsPermit {
                Image(systemName: "ticket.fill")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.gold)
            } else if isClickable || hasValidPermit {
                Image(systemName: "chevron.right")
                    .font(FontStyles.iconMini)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(10)
        .background(isBuilt ? KingdomTheme.Colors.parchment : KingdomTheme.Colors.parchmentLight)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
            needsCatchup ? KingdomTheme.Colors.buttonWarning :
            needsPermit ? KingdomTheme.Colors.gold :
            Color.black,
            lineWidth: needsCatchup || needsPermit ? 2 : 1.5
        ))
        
        // Handle click: catchup takes priority, then permit, then check exhaustion, then normal action
        if needsCatchup {
            Button {
                catchupBuilding = building
            } label: { content }
            .buttonStyle(.plain)
        } else if needsPermit {
            Button {
                permitBuilding = building
            } label: { content }
            .buttonStyle(.plain)
        } else if (isClickable || hasValidPermit), let clickAction = building.clickAction {
            Button {
                // Check if building is exhausted (daily limit reached)
                if clickAction.exhausted, let message = clickAction.exhaustedMessage {
                    exhaustedMessage = message
                    showExhaustedAlert = true
                } else {
                    activeBuildingAction = clickAction
                }
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
