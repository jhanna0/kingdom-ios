import SwiftUI

/// Card for rulers to manage kingdom tax rate
struct TaxRateManagementCard: View {
    @Binding var kingdom: Kingdom
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(FontStyles.iconLarge)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                Text("Tax Rate")
                    .font(FontStyles.headingMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Text("Set the percentage of citizen income that goes to the kingdom treasury.")
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Tax Rate Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tax Rate:")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("\(kingdom.taxRate)%")
                        .font(FontStyles.headingSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(kingdom.taxRate) },
                        set: { newValue in
                            viewModel.setKingdomTaxRate(Int(newValue), for: kingdom.id)
                            // Update local binding
                            if let index = viewModel.kingdoms.firstIndex(where: { $0.id == kingdom.id }) {
                                kingdom = viewModel.kingdoms[index]
                            }
                        }
                    ),
                    in: 0...100,
                    step: 5
                )
                .accentColor(KingdomTheme.Colors.inkMedium)
                
                HStack {
                    Text("Low (0%)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("High (100%)")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Tax Impact Information
            VStack(alignment: .leading, spacing: 8) {
                Text("How it works:")
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                infoRow(
                    icon: "hammer.fill",
                    text: "Citizens pay taxes on any income"
                )
                
                infoRow(
                    icon: "map.fill",
                    text: "Tax applied to scouting and other actions"
                )
                
                infoRow(
                    icon: "checkmark.circle.fill",
                    text: "Tax collected on daily check-ins"
                )
                
                infoRow(
                    icon: "crown.fill",
                    text: "As ruler, you pay no tax in your kingdom"
                )
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Strategy tips
            VStack(alignment: .leading, spacing: 4) {
                Text("Strategy:")
                    .font(FontStyles.labelBold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("• Low tax = Happy citizens, slower treasury growth")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("• High tax = More treasury income, unhappy citizens")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(16)
        .brutalistCard(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium
        )
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 16)
            
            Text(text)
                .font(FontStyles.labelMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
}



