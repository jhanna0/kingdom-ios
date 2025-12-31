import SwiftUI

struct MyKingdomsSheet: View {
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void
    
    @State private var myKingdoms: [MyKingdomResponse] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading kingdoms...")
                } else if myKingdoms.isEmpty {
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
                            ForEach(myKingdoms) { response in
                                if let kingdom = viewModel.kingdoms.first(where: { $0.id == response.id }) {
                                    NavigationLink(value: kingdom) {
                                        MyKingdomCardFromBackend(response: response)
                                    }
                                } else {
                                    MyKingdomCardFromBackend(response: response)
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
            .task {
                await loadRuledKingdoms()
            }
        }
    }
    
    private func loadRuledKingdoms() async {
        isLoading = true
        
        do {
            // Backend is source of truth
            myKingdoms = try await KingdomAPIService.shared.kingdom.getMyKingdoms()
            print("✅ Loaded \(myKingdoms.count) kingdoms from backend")
        } catch {
            print("❌ Failed to load kingdoms: \(error)")
            myKingdoms = []
        }
        
        isLoading = false
    }
}

// Card that displays backend data - matches MyKingdomCard style
struct MyKingdomCardFromBackend: View {
    let response: MyKingdomResponse
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Castle icon with color
            ZStack {
                Circle()
                    .fill(KingdomTheme.Colors.buttonPrimary.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(KingdomTheme.Colors.buttonPrimary, lineWidth: KingdomTheme.BorderWidth.regular)
                    )
                
                Text("🏰")
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(response.name)
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: KingdomTheme.Spacing.medium) {
                    Label("\(response.treasury_gold)g", systemImage: "dollarsign.circle.fill")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.gold)
                    
                    Label("\(response.checked_in_players)", systemImage: "person.2.fill")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(KingdomTheme.Colors.inkLight)
        }
        .padding()
        .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
    }
}
