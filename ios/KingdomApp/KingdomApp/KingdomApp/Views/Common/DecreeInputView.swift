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
            
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                Text("Royal Decree")
                    .font(KingdomTheme.Typography.title2())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                    .padding(.top)
                
                Text("Announce your will to all subjects of \(kingdom.name)")
                    .font(KingdomTheme.Typography.subheadline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Character count
                HStack {
                    Spacer()
                    Text("\(decreeText.count)/500")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(decreeText.count > 500 ? .red : KingdomTheme.Colors.inkLight)
                }
                .padding(.horizontal)
                
                ZStack(alignment: .topLeading) {
                    if decreeText.isEmpty {
                        Text("What decree will you proclaim to your subjects?")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    }
                    
                    TextEditor(text: $decreeText)
                        .font(KingdomTheme.Typography.body())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .tint(KingdomTheme.Colors.inkDark)
                        .scrollContentBackground(.hidden)
                        .frame(height: 150)
                        .padding(12)
                }
                .background(Color.white)
                .cornerRadius(KingdomTheme.CornerRadius.large)
                .overlay(
                    RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.large)
                        .stroke(KingdomTheme.Colors.inkLight.opacity(0.3), lineWidth: KingdomTheme.BorderWidth.thin)
                )
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button {
                    Task {
                        await submitDecree()
                    }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Proclaiming..." : "Proclaim Decree")
                    }
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .brutalistBadge(
                    backgroundColor: KingdomTheme.Colors.buttonPrimary,
                    cornerRadius: 8,
                    shadowOffset: 2,
                    borderWidth: 2
                )
                .padding(.horizontal)
                .disabled(decreeText.isEmpty || decreeText.count > 500 || isSubmitting)
                
                Spacer()
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
