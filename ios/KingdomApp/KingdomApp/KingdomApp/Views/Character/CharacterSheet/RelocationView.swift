import SwiftUI

/// View for confirming hometown relocation
struct RelocationView: View {
    @ObservedObject var player: Player
    let relocationStatus: RelocationStatusResponse?
    let onRelocate: () async -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var isRelocating = false
    @State private var showConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let status = relocationStatus {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let currentKingdomName = player.currentKingdomName {
                            Text("Set \(currentKingdomName) as your hometown?")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Your hometown appears in royal blue on the map. You can change this once every \(status.cooldown_days) days.")
                                .font(FontStyles.bodyMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            Button(action: {
                                showConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "house.fill")
                                        .font(FontStyles.iconSmall)
                                    Text("Confirm")
                                }
                                .font(FontStyles.bodyLargeBold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10, shadowOffset: 3, borderWidth: 2)
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView()
                    .tint(KingdomTheme.Colors.inkMedium)
            }
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Relocate Hometown")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Confirm Relocation", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Relocate", role: .destructive) {
                Task {
                    isRelocating = true
                    await onRelocate()
                    isRelocating = false
                    dismiss()
                }
            }
        } message: {
            if let kingdomName = player.currentKingdomName {
                Text("Set \(kingdomName) as your hometown? This will appear in royal blue on your map.")
            }
        }
        .overlay {
            if isRelocating {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
    }
}

