import SwiftUI

struct DecreeInputView: View {
    let kingdom: Kingdom
    @Binding var decreeText: String
    @Environment(\.dismiss) var dismiss
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            KingdomTheme.Colors.parchment
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KingdomTheme.Spacing.xLarge) {
                    // Header Card
                    VStack(spacing: KingdomTheme.Spacing.medium) {
                        Image(systemName: "scroll.fill")
                            .font(FontStyles.iconLarge)
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalCrimson, cornerRadius: 12, shadowOffset: 3, borderWidth: 2)
                        
                        Text("Royal Decree")
                            .font(FontStyles.headingLarge)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Text("Announce your will to all subjects of \(kingdom.name)")
                            .font(FontStyles.bodyMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    
                    // Text Input Card
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                        HStack {
                            Text("Your Decree")
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Spacer()
                            
                            Text("\(decreeText.count)/500")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(decreeText.count > 500 ? KingdomTheme.Colors.royalCrimson : KingdomTheme.Colors.inkLight)
                        }
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 2)
                        
                        ZStack(alignment: .topLeading) {
                            if decreeText.isEmpty {
                                Text("What decree will you proclaim to your subjects?")
                                    .font(FontStyles.bodyMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.6))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            
                            TextEditor(text: $decreeText)
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                                .tint(KingdomTheme.Colors.inkDark)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 150)
                        }
                        .padding(12)
                        .background(KingdomTheme.Colors.parchment)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        
                        if let error = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(FontStyles.iconTiny)
                                Text(error)
                                    .font(FontStyles.labelSmall)
                            }
                            .foregroundColor(KingdomTheme.Colors.royalCrimson)
                        }
                    }
                    .padding()
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    
                    // Submit Button
                    Button {
                        Task {
                            await submitDecree()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "megaphone.fill")
                                    .font(FontStyles.iconSmall)
                            }
                            Text(isSubmitting ? "Proclaiming..." : "Proclaim Decree")
                                .font(FontStyles.bodyMediumBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .brutalistBadge(
                        backgroundColor: decreeText.isEmpty || decreeText.count > 500 ? KingdomTheme.Colors.inkLight : KingdomTheme.Colors.royalCrimson,
                        cornerRadius: 8,
                        shadowOffset: 3,
                        borderWidth: 2
                    )
                    .disabled(decreeText.isEmpty || decreeText.count > 500 || isSubmitting)
                }
                .padding()
            }
        }
        .navigationTitle("Make Decree")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Decree Proclaimed!", isPresented: $showSuccess) {
            Button("OK") {
                decreeText = ""
                dismiss()
            }
        } message: {
            Text("Your decree has been announced to all subjects of \(kingdom.name).")
        }
    }
    
    private func submitDecree() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        
        do {
            let response = try await KingdomAPIService.shared.kingdom.makeDecree(
                kingdomId: kingdom.id,
                decreeText: decreeText
            )
            
            isSubmitting = false
            if response.success {
                showSuccess = true
            }
        } catch {
            isSubmitting = false
            errorMessage = "Failed to proclaim decree"
        }
    }
}
