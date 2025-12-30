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
                    .foregroundColor(KingdomTheme.Colors.gold)
                Text("Tax Rate")
                    .font(KingdomTheme.Typography.title3())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
            }
            
            Text("Set the percentage of citizen income that goes to the kingdom treasury.")
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Tax Rate Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tax Rate:")
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("\(kingdom.taxRate)%")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.gold)
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
                .accentColor(KingdomTheme.Colors.gold)
                
                HStack {
                    Text("Low (0%)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Spacer()
                    
                    Text("High (100%)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            
            Divider()
                .background(KingdomTheme.Colors.inkLight)
            
            // Tax Impact Information
            VStack(alignment: .leading, spacing: 8) {
                Text("How it works:")
                    .font(KingdomTheme.Typography.body())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                infoRow(
                    icon: "hammer.fill",
                    text: "Citizens pay \(kingdom.taxRate)% tax on contract work"
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
            
            Divider()
                .background(KingdomTheme.Colors.inkLight)
            
            // Strategy tips
            VStack(alignment: .leading, spacing: 4) {
                Text("Strategy:")
                    .font(KingdomTheme.Typography.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("• Low tax = Happy citizens, slower treasury growth")
                    .font(KingdomTheme.Typography.caption2())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                
                Text("• High tax = More treasury income, unhappy citizens")
                    .font(KingdomTheme.Typography.caption2())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchmentLight)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(KingdomTheme.Colors.gold)
                .frame(width: 16)
            
            Text(text)
                .font(KingdomTheme.Typography.caption())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
}

