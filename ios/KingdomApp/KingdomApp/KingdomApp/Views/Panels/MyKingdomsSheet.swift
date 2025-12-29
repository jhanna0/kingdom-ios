import SwiftUI

struct MyKingdomsSheet: View {
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if player.fiefsRuled.isEmpty {
                    VStack(spacing: KingdomTheme.Spacing.large) {
                        Image(systemName: "crown")
                            .font(.system(size: 60))
                            .foregroundColor(KingdomTheme.Colors.goldWarm)
                            .opacity(0.5)
                        
                        Text("No Kingdoms Yet")
                            .font(KingdomTheme.Typography.title3())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Find unclaimed territories and check in to claim them!")
                            .font(KingdomTheme.Typography.body())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: KingdomTheme.Spacing.large) {
                            ForEach(viewModel.kingdoms.filter { player.fiefsRuled.contains($0.name) }) { kingdom in
                                NavigationLink(value: kingdom) {
                                    MyKingdomCard(kingdom: kingdom)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Kingdoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationDestination(for: Kingdom.self) { kingdom in
                KingdomDetailView(
                    kingdomId: kingdom.id,
                    player: player,
                    viewModel: viewModel
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(KingdomTheme.Typography.headline())
                    .fontWeight(.semibold)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                }
            }
        }
    }
}
