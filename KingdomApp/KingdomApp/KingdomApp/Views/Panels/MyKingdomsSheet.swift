import SwiftUI

struct MyKingdomsSheet: View {
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.87, blue: 0.70)
                    .ignoresSafeArea()
                
                if player.fiefsRuled.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "crown")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .opacity(0.5)
                        
                        Text("No Kingdoms Yet")
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Text("Find unclaimed territories and check in to claim them!")
                            .font(.system(.body, design: .serif))
                            .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
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
            .navigationDestination(for: Kingdom.self) { kingdom in
                KingdomDetailView(
                    kingdom: kingdom,
                    player: player,
                    viewModel: viewModel
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
                }
            }
        }
    }
}

