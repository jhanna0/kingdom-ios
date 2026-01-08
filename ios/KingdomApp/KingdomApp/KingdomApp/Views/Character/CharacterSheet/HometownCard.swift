import SwiftUI

/// Card showing hometown relocation options when player is away from home
struct HometownCard: View {
    @ObservedObject var player: Player
    let relocationStatus: RelocationStatusResponse?
    let isLoadingRelocationStatus: Bool
    let onRelocate: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Image(systemName: "house.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.royalBlue)
                
                Text("Hometown")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if isLoadingRelocationStatus {
                    ProgressView()
                        .tint(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Travel to a kingdom and tap below to set it as your hometown.")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                // Relocation navigation link
                NavigationLink(destination: RelocationView(
                    player: player,
                    relocationStatus: relocationStatus,
                    onRelocate: onRelocate
                )) {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(FontStyles.iconSmall)
                        
                        if let status = relocationStatus {
                            if status.can_relocate {
                                Text("Set \(player.currentKingdomName ?? "Current Kingdom") as Hometown")
                            } else {
                                Text("Available in \(status.days_until_available) days")
                            }
                        } else {
                            Text("Set as Hometown")
                        }
                    }
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .brutalistBadge(
                    backgroundColor: relocationStatus?.can_relocate == true ? KingdomTheme.Colors.buttonPrimary : KingdomTheme.Colors.inkLight,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
                .disabled(relocationStatus?.can_relocate != true)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}

