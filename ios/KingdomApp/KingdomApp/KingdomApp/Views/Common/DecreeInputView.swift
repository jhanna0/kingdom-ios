import SwiftUI

struct DecreeInputView: View {
    let kingdom: Kingdom
    @Binding var decreeText: String
    @Environment(\.dismiss) var dismiss
    
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
                
                Button(action: {
                    // TODO: Send decree
                    dismiss()
                }) {
                    Text("Proclaim Decree")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.medieval(color: KingdomTheme.Colors.buttonPrimary, fullWidth: true))
                .padding(.horizontal)
                .disabled(decreeText.isEmpty)
                
                Spacer()
            }
        }
        .navigationTitle("Make Decree")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
