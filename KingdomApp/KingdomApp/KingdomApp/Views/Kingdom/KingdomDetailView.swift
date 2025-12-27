import SwiftUI
import MapKit

struct KingdomDetailView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showBuildMenu = false
    @State private var showDecreeInput = false
    @State private var decreeText = ""
    
    var isRuler: Bool {
        kingdom.rulerId == player.playerId
    }
    
    var body: some View {
        ZStack {
            // Parchment background
            Color(red: 0.95, green: 0.87, blue: 0.70)
                .ignoresSafeArea()
            
            ScrollView {
                    VStack(spacing: 20) {
                        // Kingdom header
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.2))
                            
                            Text(kingdom.name)
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                            
                            Text("Ruled by \(kingdom.rulerName)")
                                .font(.system(.subheadline, design: .serif))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        .padding()
                        
                        // Treasury - Kingdom's money
                        VStack(spacing: 8) {
                            Text("Kingdom Treasury")
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            
                            HStack(spacing: 6) {
                                Image(systemName: "building.columns.fill")
                                    .font(.title)
                                    .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.2))
                                Text("\(kingdom.treasuryGold)")
                                    .font(.system(.title, design: .serif))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                Text("gold")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            }
                            
                            Text("Used for contracts & defenses")
                                .font(.system(.caption2, design: .serif))
                                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.92, green: 0.82, blue: 0.65))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 2)
                        )
                        .padding(.horizontal)
                        
                        // Buildings section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fortifications")
                                .font(.system(.headline, design: .serif))
                                .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                BuildingStatCard(
                                    icon: "building.2.fill",
                                    name: "Walls",
                                    level: kingdom.wallLevel,
                                    maxLevel: 5,
                                    benefit: "+\(kingdom.wallLevel * 2) defenders"
                                )
                                
                                BuildingStatCard(
                                    icon: "lock.shield.fill",
                                    name: "Vault",
                                    level: kingdom.vaultLevel,
                                    maxLevel: 5,
                                    benefit: "\(kingdom.vaultLevel * 20)% protected"
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Population
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Checked In")
                                    .font(.system(.headline, design: .serif))
                                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                
                                Spacer()
                                
                                Text("\(kingdom.checkedInPlayers) present")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            }
                            .padding(.horizontal)
                            
                            // Placeholder for future player list
                            if kingdom.checkedInPlayers == 0 {
                                Text("No one is present")
                                    .font(.system(.caption, design: .serif))
                                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                                    .italic()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(red: 0.98, green: 0.92, blue: 0.80))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Ruler actions
                        if isRuler {
                            VStack(spacing: 12) {
                                Text("Ruler Powers")
                                    .font(.system(.headline, design: .serif))
                                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                
                                Button(action: {
                                    showBuildMenu = true
                                }) {
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Build Fortifications")
                                                .font(.system(.headline, design: .serif))
                                            Text("Upgrade walls or vault")
                                                .font(.system(.caption, design: .serif))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color(red: 0.5, green: 0.3, blue: 0.1))
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showDecreeInput = true
                                }) {
                                    HStack {
                                        Image(systemName: "scroll.fill")
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Make Decree")
                                                .font(.system(.headline, design: .serif))
                                            Text("Announce to all subjects")
                                                .font(.system(.caption, design: .serif))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color(red: 0.4, green: 0.25, blue: 0.15))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        
                        // Benefits of ruling
                        if isRuler {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Benefits of Ruling")
                                    .font(.system(.headline, design: .serif))
                                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))
                                
                                BenefitRow(icon: "bitcoinsign.circle.fill", text: "Passive income: +10 gold/hour")
                                BenefitRow(icon: "person.2.fill", text: "Tax subjects & demand tribute")
                                BenefitRow(icon: "shield.fill", text: "Build defenses against coups")
                                BenefitRow(icon: "crown.fill", text: "Control territory & make decrees")
                            }
                            .padding()
                            .background(Color(red: 0.90, green: 0.80, blue: 0.60))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.4, green: 0.3, blue: 0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBuildMenu) {
                BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)
            }
            .sheet(isPresented: $showDecreeInput) {
                DecreeInputView(kingdom: kingdom, decreeText: $decreeText)
            }
        }
    }
