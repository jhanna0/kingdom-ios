import SwiftUI
import MapKit

struct MyKingdomsView: View {
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @State private var selectedKingdom: Kingdom?
    
    var ruledKingdoms: [Kingdom] {
        viewModel.kingdoms.filter { kingdom in
            player.fiefsRuled.contains(kingdom.name)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Parchment background
                KingdomTheme.Colors.parchment
                    .ignoresSafeArea()
                
                if ruledKingdoms.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        
                        Text("No Kingdoms Ruled")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                        
                        Text("Venture forth and claim your first territory!")
                            .font(.system(.body, design: .serif))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            // Switch to map tab
                        }) {
                            Text("Explore Map")
                                .font(.system(.headline, design: .serif))
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.5, green: 0.3, blue: 0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 10)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Player stats header
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.name)
                                            .font(.system(.title3, design: .serif))
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                        
                                        Text("\(player.isRuler ? "Ruler" : "Commoner")")
                                            .font(.system(.caption, design: .serif))
                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    }
                                    
                                    Spacer()
                                    
                                    // Personal gold
                                    HStack(spacing: 4) {
                                        Text("\(player.gold)")
                                            .font(.system(.title3, design: .serif))
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                        Image(systemName: "g.circle.fill")
                                            .foregroundColor(KingdomTheme.Colors.goldLight)
                                    }
                                }
                                
                                // Stats row
                                HStack(spacing: 20) {
                                    StatBadge(label: "Kingdoms", value: "\(ruledKingdoms.count)")
                                    StatBadge(label: "Coups Won", value: "\(player.coupsWon)")
                                    StatBadge(label: "Subjects", value: "\(totalSubjects)")
                                }
                            }
                            .padding()
                            .background(Color(red: 0.92, green: 0.82, blue: 0.65))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Kingdoms list
                            ForEach(ruledKingdoms) { kingdom in
                                KingdomCard(kingdom: kingdom, player: player, viewModel: viewModel)
                                    .onTapGesture {
                                        selectedKingdom = kingdom
                                    }
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("My Kingdoms")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedKingdom) { kingdom in
                KingdomDetailView(kingdomId: kingdom.id, player: player, viewModel: viewModel)
            }
        }
    }
    
    private var totalSubjects: Int {
        ruledKingdoms.reduce(0) { $0 + $1.checkedInPlayers }
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.1))
            Text(label)
                .font(.system(.caption2, design: .serif))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
        }
    }
}

struct KingdomCard: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.2))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(kingdom.name)
                        .font(.system(.title3, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                    
                    Text("Ruled by \(kingdom.rulerName)")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
                
                Spacer()
                
                // Kingdom treasury
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("\(kingdom.treasuryGold)")
                            .font(.system(.headline, design: .serif))
                            .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                    }
                    Text("Treasury")
                        .font(.system(.caption2, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Kingdom stats
            HStack(spacing: 20) {
                KingdomStatItem(icon: "figure.stand", label: "Subjects", value: "\(kingdom.checkedInPlayers)")
                KingdomStatItem(icon: "building.2.fill", label: "Walls", value: "Lvl \(kingdom.buildingLevel("wall"))")
                KingdomStatItem(icon: "lock.shield.fill", label: "Vault", value: "Lvl \(kingdom.buildingLevel("vault"))")
            }
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 2)
            
            // Tap to open kingdom details
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                
                Text("Tap to manage kingdom")
                    .font(FontStyles.bodyMedium)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(FontStyles.iconSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding()
        .brutalistCard(
            backgroundColor: KingdomTheme.Colors.parchmentLight,
            cornerRadius: KingdomTheme.Brutalist.cornerRadiusMedium
        )
    }
}

struct KingdomStatItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            Text(value)
                .font(.system(.caption, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
            Text(label)
                .font(.system(.caption2, design: .serif))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
        }
        .frame(maxWidth: .infinity)
    }
}


