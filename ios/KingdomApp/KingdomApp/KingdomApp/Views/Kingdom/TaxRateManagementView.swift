import SwiftUI

/// Full-page view for rulers to manage kingdom tax rate
struct TaxRateManagementView: View {
    let kingdom: Kingdom
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    // Local state for tax rate
    @State private var currentTaxRate: Int = 0
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "percent")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
                    Text("Tax Rate")
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("Set the percentage of citizen income that goes to the kingdom treasury")
                        .font(FontStyles.bodyMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Current Tax Rate Display
                VStack(spacing: 8) {
                    Text("Current Rate")
                        .font(FontStyles.labelMedium)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("\(currentTaxRate)%")
                        .font(FontStyles.displaySmall)
                        .foregroundColor(KingdomTheme.Colors.gold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                
                // Tax Rate Slider
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Adjust Tax Rate")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Slider(
                        value: Binding(
                            get: { Double(currentTaxRate) },
                            set: { newValue in
                                currentTaxRate = Int(newValue)
                            }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .accentColor(KingdomTheme.Colors.gold)
                    
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
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                
                // Save Button
                Button(action: {
                    saveTaxRate()
                }) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(FontStyles.iconMedium)
                        }
                        Text(isSaving ? "Saving..." : "Save Tax Rate")
                            .font(FontStyles.bodyMediumBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 12)
                .disabled(isSaving || currentTaxRate == kingdom.taxRate)
                .opacity(currentTaxRate == kingdom.taxRate ? 0.5 : 1.0)
                .padding(.horizontal)
                
                // Divider
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                    .padding(.horizontal)
                
                // Tax Impact Information
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("How it works:")
                        .font(FontStyles.headingMedium)
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
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                
                // Strategy tips
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Strategy:")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        strategyRow(
                            icon: "hand.thumbsup.fill",
                            title: "Low tax (0-25%)",
                            description: "Happy citizens, slower treasury growth"
                        )
                        
                        strategyRow(
                            icon: "equal.circle.fill",
                            title: "Moderate tax (30-50%)",
                            description: "Balanced approach for steady income"
                        )
                        
                        strategyRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "High tax (55-100%)",
                            description: "Maximum treasury income, risk of rebellion"
                        )
                    }
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                .padding(.bottom, KingdomTheme.Spacing.xLarge)
            }
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationTitle("Tax Rate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            currentTaxRate = kingdom.taxRate
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.gold, cornerRadius: 8)
            
            Text(text)
                .font(FontStyles.bodyMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
    }
    
    private func strategyRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text(description)
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
    }
    
    private func saveTaxRate() {
        isSaving = true
        viewModel.setKingdomTaxRate(currentTaxRate, for: kingdom.id)
        
        // Simulate a brief delay for the save operation
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

