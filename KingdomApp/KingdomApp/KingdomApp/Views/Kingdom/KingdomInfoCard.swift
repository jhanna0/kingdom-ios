import SwiftUI

// Info card when kingdom is selected - Medieval scroll style with actions
struct KingdomInfoCard: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let isPlayerInside: Bool
    let onCheckIn: () -> Void
    let onClaim: () -> Void
    let onClose: () -> Void
    
    @State private var showBuildMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with medieval styling
            HStack {
                Text("🏰 \(kingdom.name)")
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.2, green: 0.1, blue: 0.05))  // Dark brown ink
                Spacer()
                
                if kingdom.isUnclaimed {
                    Text("⚠️ Unclaimed")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.7, green: 0.3, blue: 0.1))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.9, green: 0.8, blue: 0.6))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)
            
            if kingdom.isUnclaimed {
                Text("No ruler - claim it by checking in!")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            } else {
                HStack(spacing: 4) {
                    Text("Ruled by \(kingdom.rulerName)")
                        .font(.system(.headline, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    if kingdom.rulerId == player.playerId {
                        Text("(You)")
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    }
                }
            }
            
            // Kingdom color divider with medieval style
            Rectangle()
                .fill(
                    Color(
                        red: kingdom.color.strokeRGBA.red,
                        green: kingdom.color.strokeRGBA.green,
                        blue: kingdom.color.strokeRGBA.blue
                    )
                )
                .frame(height: 2)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(kingdom.treasuryGold)g", systemImage: "dollarsign.circle.fill")
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                    Label("Walls Lv.\(kingdom.wallLevel)", systemImage: "shield.fill")
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Label("Vault Lv.\(kingdom.vaultLevel)", systemImage: "lock.fill")
                        .foregroundColor(Color(red: 0.45, green: 0.3, blue: 0.1))
                    Label("\(kingdom.checkedInPlayers) subjects", systemImage: "person.3.fill")
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.15))
                }
            }
            .font(.system(.subheadline, design: .serif))
            
            // Check-in/Claim section
            if isPlayerInside {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                        .frame(height: 2)
                        .padding(.vertical, 4)
                    
                    if kingdom.rulerId == player.playerId {
                        // You own this kingdom - show ruler options
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                                Text("You rule this kingdom")
                                    .font(.system(.subheadline, design: .serif))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.1))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(red: 0.95, green: 0.9, blue: 0.75))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.6, green: 0.4, blue: 0.1), lineWidth: 2)
                            )
                            
                            // Build button
                            MedievalActionButton(
                                title: "Build Fortifications",
                                color: Color(red: 0.5, green: 0.3, blue: 0.1),
                                fullWidth: true
                            ) {
                                showBuildMenu = true
                            }
                        }
                    } else if kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                        // Can claim!
                        MedievalActionButton(
                            title: "👑 Claim This Kingdom",
                            color: Color(red: 0.6, green: 0.4, blue: 0.1),
                            fullWidth: true
                        ) {
                            onClaim()
                        }
                    } else if !player.isCheckedIn() || player.currentKingdom != kingdom.name {
                        // Need to enter the kingdom
                        MedievalActionButton(
                            title: "⚔️ Enter Kingdom",
                            color: Color(red: 0.2, green: 0.5, blue: 0.3),
                            fullWidth: true
                        ) {
                            onCheckIn()
                        }
                    } else {
                        // Already present but someone else rules it
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                            Text("You are here")
                                .font(.system(.caption, design: .serif))
                                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(red: 0.9, green: 0.85, blue: 0.7))
                        .cornerRadius(6)
                    }
                }
            } else {
                // Not inside this kingdom
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color(red: 0.4, green: 0.3, blue: 0.2))
                        .frame(height: 2)
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                        Text("You must travel here first")
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                    }
                    .padding(8)
                }
            }
            
            // Action buttons - Medieval war council style (only if kingdom has ruler)
            if !kingdom.isUnclaimed && kingdom.rulerId != player.playerId {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        MedievalActionButton(
                            title: "⚔️ Declare War",
                            color: Color(red: 0.7, green: 0.15, blue: 0.1)
                        ) {
                            // TODO: Implement declare war
                            print("Declare war on \(kingdom.name)")
                        }
                        
                        MedievalActionButton(
                            title: "🤝 Form Alliance",
                            color: Color(red: 0.2, green: 0.5, blue: 0.3)
                        ) {
                            // TODO: Implement form alliance
                            print("Form alliance with \(kingdom.name)")
                        }
                    }
                    
                    MedievalActionButton(
                        title: "🗡️ Stage Coup",
                        color: Color(red: 0.3, green: 0.15, blue: 0.4),
                        fullWidth: true
                    ) {
                        // TODO: Implement stage coup
                        print("Stage coup in \(kingdom.name)")
                    }
                }
                .padding(.top, 8)
            }
            
            Button(action: onClose) {
                HStack {
                    Spacer()
                    Text("✕ Close")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            Color(red: 0.95, green: 0.87, blue: 0.70)  // Parchment background
                .overlay(
                    // Add subtle texture
                    Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.1)
                )
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(
                        red: kingdom.color.strokeRGBA.red,
                        green: kingdom.color.strokeRGBA.green,
                        blue: kingdom.color.strokeRGBA.blue
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 2, y: 4)
        .sheet(isPresented: $showBuildMenu) {
            BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)
        }
    }
}

