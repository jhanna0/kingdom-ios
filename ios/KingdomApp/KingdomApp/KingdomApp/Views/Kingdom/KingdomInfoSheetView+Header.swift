import SwiftUI

// MARK: - Header Views

extension KingdomInfoSheetView {
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(FontStyles.iconExtraLarge)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .brutalistBadge(
                        backgroundColor: Color(
                            red: kingdom.color.strokeRGBA.red,
                            green: kingdom.color.strokeRGBA.green,
                            blue: kingdom.color.strokeRGBA.blue
                        ),
                        cornerRadius: 12,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(kingdom.name)
                        .font(FontStyles.displaySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if kingdom.isUnclaimed {
                        Text("No ruler")
                            .font(FontStyles.bodySmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else {
                        HStack(spacing: 4) {
                            Text("Ruled by \(kingdom.rulerName)")
                                .font(FontStyles.bodySmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                    }
                }
                
                Spacer()
                
                if kingdom.isUnclaimed {
                    Text("Unclaimed")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 6)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Kingdom color divider with brutalist style
            Rectangle()
                .fill(Color.black)
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.top, KingdomTheme.Spacing.xLarge)
        }
    }
}
