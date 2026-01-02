import SwiftUI

// Sheet wrapper for KingdomInfoCard with proper dismiss handling
struct KingdomInfoSheetView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let isPlayerInside: Bool
    let onViewKingdom: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showClaimError = false
    @State private var claimErrorMessage = ""
    @State private var isClaiming = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.xLarge) {
                // Header with medieval styling
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(
                            backgroundColor: Color(
                                red: kingdom.color.strokeRGBA.red,
                                green: kingdom.color.strokeRGBA.green,
                                blue: kingdom.color.strokeRGBA.blue
                            ),
                            cornerRadius: 12,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kingdom.name)
                            .font(FontStyles.displaySmall)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        if kingdom.isUnclaimed {
                            Text("No ruler")
                                .font(FontStyles.bodySmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else {
                            HStack(spacing: 4) {
                                Text("Ruled by \(kingdom.rulerName)")
                                    .font(FontStyles.bodySmall)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if kingdom.isUnclaimed {
                        Text("Unclaimed")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.error, cornerRadius: 6)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Kingdom color divider with brutalist style
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal)
                
                // Ruler Actions (moved to top, after header)
                if isPlayerInside && kingdom.rulerId == player.playerId {
                    Button(action: onViewKingdom) {
                        HStack(spacing: KingdomTheme.Spacing.medium) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 54, height: 54)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.imperialGold, cornerRadius: 14, shadowOffset: 3, borderWidth: 2.5)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage Your Kingdom")
                                    .font(FontStyles.bodyLargeBold)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                Text("Buildings, taxes & decrees")
                                    .font(FontStyles.labelMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(FontStyles.iconMedium)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .padding(KingdomTheme.Spacing.medium)
                    }
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                    .padding(.horizontal)
                } else if kingdom.canClaim {
                    // Backend says we can claim!
                    Button(action: {
                        isClaiming = true
                        Task {
                            do {
                                try await viewModel.claimKingdom()
                                // Dismiss sheet after short delay to let celebration popup show
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                dismiss()
                            } catch {
                                isClaiming = false
                                claimErrorMessage = error.localizedDescription
                                showClaimError = true
                                print("❌ Failed to claim: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isClaiming {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "flag.fill")
                                    .font(FontStyles.iconSmall)
                                    .foregroundColor(.white)
                            }
                            Text(isClaiming ? "Claiming..." : "Claim This Kingdom")
                                .font(FontStyles.bodyMediumBold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(KingdomTheme.Spacing.medium)
                        .foregroundColor(.white)
                    }
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                    .disabled(isClaiming)
                    .padding(.horizontal)
                    .alert("Claim Failed", isPresented: $showClaimError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(claimErrorMessage)
                    }
                } else if isPlayerInside {
                    // Already present but someone else rules it
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        Text("You are here")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(KingdomTheme.Spacing.small)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 8)
                    .padding(.horizontal)
                } else {
                    // Not inside this kingdom
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(FontStyles.iconSmall)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text("You must travel here first")
                            .font(FontStyles.labelMedium)
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(KingdomTheme.Spacing.small)
                    .padding(.horizontal)
                }
                
                // Population Stats
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Population")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .font(FontStyles.iconMedium)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                            
                            Text("\(kingdom.checkedInPlayers)")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Present Now")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(FontStyles.iconMedium)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
                            
                            Text("\(kingdom.weeklyUniqueCheckIns)")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("This Week")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    }
                    .padding(.horizontal)
                }
                
                // Player Activity Feed
                PlayerActivityFeedCard(kingdomId: kingdom.id)
                    .padding(.horizontal)
                
                // Treasury & Income Section
                VStack(spacing: KingdomTheme.Spacing.small) {
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        // Treasury
                        VStack(spacing: 8) {
                            Image(systemName: "building.columns.fill")
                                .font(FontStyles.iconLarge)
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 12)
                            
                            Text("\(kingdom.treasuryGold)g")
                                .font(FontStyles.headingLarge)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Treasury")
                                .font(FontStyles.labelSmall)
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.medium)
                        
                        // TODO: Income Rate - backend should provide this in kingdom response
                        // Removed local income calculation
                    }
                }
                .padding(KingdomTheme.Spacing.medium)
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                .padding(.horizontal)
                
                // Buildings & Stats Section
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                        .padding(.horizontal)
                    
                    Text("Fortifications")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        BuildingStatCard(
                            icon: "building.2.fill",
                            name: "Walls",
                            level: kingdom.wallLevel,
                            maxLevel: 5,
                            benefit: "+\(kingdom.wallLevel * 2) defenders",
                            buildingType: "wall",
                            kingdom: kingdom,
                            player: player
                        )
                        
                        BuildingStatCard(
                            icon: "lock.shield.fill",
                            name: "Vault",
                            level: kingdom.vaultLevel,
                            maxLevel: 5,
                            benefit: "\(kingdom.vaultLevel * 20)% protected",
                            buildingType: "vault",
                            kingdom: kingdom,
                            player: player
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Economy Buildings
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Economy")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        BuildingStatCard(
                            icon: "hammer.fill",
                            name: "Mine",
                            level: kingdom.mineLevel,
                            maxLevel: 5,
                            benefit: "+\(kingdom.mineLevel * 5)g/hr",
                            buildingType: "mine",
                            kingdom: kingdom,
                            player: player
                        )
                        
                        BuildingStatCard(
                            icon: "cart.fill",
                            name: "Market",
                            level: kingdom.marketLevel,
                            maxLevel: 5,
                            benefit: "+\(kingdom.marketLevel * 3)g/hr",
                            buildingType: "market",
                            kingdom: kingdom,
                            player: player
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Military Strength / Intelligence
                MilitaryStrengthCard(
                    strength: viewModel.militaryStrengthCache[kingdom.id],
                    kingdom: kingdom,
                    player: player,
                    onGatherIntel: {
                        Task {
                            do {
                                _ = try await viewModel.gatherIntelligence(kingdomId: kingdom.id)
                            } catch {
                                print("❌ Failed to gather intelligence: \(error)")
                            }
                        }
                    }
                )
                .padding(.horizontal)
                .task {
                    // Load military strength when sheet opens
                    print("🎯 KingdomInfoSheet loading strength for: \(kingdom.id)")
                    if viewModel.militaryStrengthCache[kingdom.id] == nil {
                        print("🎯 Cache miss, fetching...")
                        await viewModel.fetchMilitaryStrength(kingdomId: kingdom.id)
                    } else {
                        print("🎯 Cache hit!")
                    }
                }
                
                // Active Contract Section
                if let contract = kingdom.activeContract {
                    VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text("Active Contract")
                                .font(FontStyles.bodyMediumBold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Spacer()
                            if contract.isComplete {
                                Text("Complete")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                            } else {
                                Text("In Progress")
                                    .font(FontStyles.labelSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonWarning, cornerRadius: 6, shadowOffset: 1, borderWidth: 1.5)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(FontStyles.iconMini)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text("\(contract.buildingType) Level \(contract.buildingLevel)")
                                    .font(FontStyles.labelMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            
                            HStack(spacing: 8) {
                                Label("\(contract.contributorCount) contributors", systemImage: "person.2.fill")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                
                                Label("\(contract.rewardPool) pool", systemImage: "g.circle.fill")
                                    .font(FontStyles.labelTiny)
                                    .foregroundColor(KingdomTheme.Colors.goldLight)
                            }
                            
                            // Progress bar
                            if !contract.isComplete {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Progress")
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkLight)
                                        Spacer()
                                        Text(String(format: "%.0f%%", contract.progress * 100))
                                            .font(FontStyles.labelTiny)
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                                .frame(height: 6)
                                                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                                            
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.buttonWarning)
                                                .frame(width: geometry.size.width * contract.progress, height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                        }
                    }
                    .padding(KingdomTheme.Spacing.medium)
                    .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
                    .padding(.horizontal)
                }
                
                // Action buttons - Medieval war council style (backend controls visibility)
                if kingdom.canDeclareWar || kingdom.canFormAlliance {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                        .padding(.horizontal)
                    
                    VStack(spacing: KingdomTheme.Spacing.small) {
                        if kingdom.canDeclareWar {
                            Button(action: {
                                // TODO: Implement declare war
                                print("Declare war on \(kingdom.name)")
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(.white)
                                    Text("Declare War")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonDanger, cornerRadius: 10)
                        }
                        
                        if kingdom.canFormAlliance {
                            Button(action: {
                                // TODO: Implement form alliance
                                print("Form alliance with \(kingdom.name)")
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(.white)
                                    Text("Form Alliance")
                                        .font(FontStyles.bodyMediumBold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(KingdomTheme.Spacing.medium)
                                .foregroundColor(.white)
                            }
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                        }
                        
                        Button(action: {
                            // TODO: Implement stage coup
                            print("Stage coup in \(kingdom.name)")
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(FontStyles.iconSmall)
                                    .foregroundColor(.white)
                                Text("Stage Coup")
                                    .font(FontStyles.bodyMediumBold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(KingdomTheme.Spacing.medium)
                            .foregroundColor(.white)
                        }
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonPrimary, cornerRadius: 10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.top)
        }
        .background(KingdomTheme.Colors.parchment)
    }
}

