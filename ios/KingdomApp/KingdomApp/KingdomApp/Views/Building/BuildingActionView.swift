import SwiftUI

/// DYNAMIC Building Action View - Routes to appropriate view based on backend action type
/// Frontend doesn't need to know about specific building types!
struct BuildingActionView: View {
    let action: BuildingClickAction
    let kingdom: Kingdom
    let playerId: Int
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            contentView
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch action.type {
        case "gathering":
            GatheringView(initialResource: action.resource ?? "wood")
        case "market":
            MarketView()
        case "townhall":
            TownHallView(kingdom: kingdom, playerId: playerId)
        default:
            // Unknown action type - show error
            VStack(spacing: 20) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 60))
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("Unknown Action")
                    .font(FontStyles.headingMedium)
                Text("Action type '\(action.type)' is not supported")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KingdomTheme.Colors.parchment)
        }
    }
}
