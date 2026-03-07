import SwiftUI

/// Full-page view for rulers to manage kingdom tax rate
/// Supports two flows:
/// 1. Map flow: init(kingdom:viewModel:) - uses Kingdom object and MapViewModel
/// 2. Empire flow: init(kingdomId:kingdomName:currentTaxRate:onSave:) - uses simple params and API directly
struct TaxRateManagementView: View {
    // Core data (used by both flows)
    private let kingdomId: String
    private let kingdomName: String
    private let initialTaxRate: Int
    
    // Map flow dependencies (optional)
    private var viewModel: MapViewModel?
    
    // Empire flow callback (optional)
    private var onSave: ((Int) -> Void)?
    
    @Environment(\.dismiss) var dismiss
    
    // Local state
    @State private var currentTaxRate: Int = 0
    @State private var isSaving = false
    
    // MARK: - Initializers
    
    /// Map flow initializer - uses Kingdom object and MapViewModel
    init(kingdom: Kingdom, viewModel: MapViewModel) {
        self.kingdomId = kingdom.id
        self.kingdomName = kingdom.name
        self.initialTaxRate = kingdom.taxRate
        self.viewModel = viewModel
        self.onSave = nil
    }
    
    /// Empire flow initializer - uses simple params and callback
    init(kingdomId: String, kingdomName: String, currentTaxRate: Int, onSave: @escaping (Int) -> Void) {
        self.kingdomId = kingdomId
        self.kingdomName = kingdomName
        self.initialTaxRate = currentTaxRate
        self.viewModel = nil
        self.onSave = onSave
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "percent")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
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
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
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
                .disabled(isSaving || currentTaxRate == initialTaxRate)
                .opacity(currentTaxRate == initialTaxRate ? 0.5 : 1.0)
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
                        text: "Additional taxes apply on top of training costs"
                    )
                    
                    infoRow(
                        icon: "checkmark.circle.fill",
                        text: "Taxes directly fund the kingdom's treasury"
                    )
                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                            title: "Low tax",
                            description: "Citizens happier, smaller treasury"
                        )
                        
                        strategyRow(
                            icon: "equal.circle.fill",
                            title: "Moderate tax",
                            description: "Mixture of citizen happiness and treasury"
                        )
                        
                        strategyRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "High tax",
                            description: "Hated by citizens, but allows explosive kingdom growth"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            currentTaxRate = initialTaxRate
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 8)
            
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
        
        // Use appropriate save method based on which flow we're in
        if let viewModel = viewModel {
            // Map flow - use viewModel
            viewModel.setKingdomTaxRate(currentTaxRate, for: kingdomId)
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            }
        } else {
            // Empire flow - call API directly
            Task {
                do {
                    try await KingdomAPIService.shared.kingdom.setTaxRate(
                        kingdomId: kingdomId,
                        taxRate: currentTaxRate
                    )
                    await MainActor.run {
                        isSaving = false
                        onSave?(currentTaxRate)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isSaving = false
                    }
                }
            }
        }
    }
}

