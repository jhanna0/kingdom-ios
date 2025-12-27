import SwiftUI

struct DecreeInputView: View {
    let kingdom: Kingdom
    @Binding var decreeText: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.87, blue: 0.70)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Royal Decree")
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                        .padding(.top)
                    
                    Text("Announce your will to all subjects of \(kingdom.name)")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    TextEditor(text: $decreeText)
                        .font(.system(.body, design: .serif))
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(red: 0.98, green: 0.92, blue: 0.80))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    Button(action: {
                        // TODO: Send decree
                        dismiss()
                    }) {
                        Text("Proclaim Decree")
                            .font(.system(.headline, design: .serif))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.5, green: 0.3, blue: 0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(decreeText.isEmpty)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
                }
            }
        }
    }
}

