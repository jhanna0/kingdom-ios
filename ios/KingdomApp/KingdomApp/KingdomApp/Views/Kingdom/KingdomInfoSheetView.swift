import SwiftUI

// Sheet wrapper for KingdomInfoCard with proper dismiss handling
struct KingdomInfoSheetView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    let isPlayerInside: Bool
    let onViewKingdom: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.xLarge) {
                // Header with medieval styling
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    HStack(alignment: .center) {
                        HStack(spacing: 10) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(
                                    red: kingdom.color.strokeRGBA.red,
                                    green: kingdom.color.strokeRGBA.green,
                                    blue: kingdom.color.strokeRGBA.blue
                                ))
                            
                            Text(kingdom.name)
                                .font(KingdomTheme.Typography.largeTitle())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                        }
                        
                        Spacer()
                        
                        if kingdom.isUnclaimed {
                            Text("Unclaimed")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.error)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(KingdomTheme.Colors.parchmentRich)
                                .cornerRadius(KingdomTheme.CornerRadius.medium)
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 6) {
                        if kingdom.isUnclaimed {
                            Image(systemName: "crown")
                                .font(.subheadline)
                                .foregroundColor(KingdomTheme.Colors.inkLight)
                            Text("No ruler")
                                .font(KingdomTheme.Typography.subheadline())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.subheadline)
                                .foregroundColor(kingdom.rulerId == player.playerId ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkLight)
                            
                            Text("Ruled by \(kingdom.rulerName)")
                                .font(KingdomTheme.Typography.subheadline())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                            
                            if kingdom.rulerId == player.playerId {
                                Text("(You)")
                                    .font(KingdomTheme.Typography.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Kingdom color divider with medieval style
                Rectangle()
                    .fill(
                        Color(
                            red: kingdom.color.strokeRGBA.red,
                            green: kingdom.color.strokeRGBA.green,
                            blue: kingdom.color.strokeRGBA.blue
                        )
                    )
                    .frame(height: 3)
                    .cornerRadius(1.5)
                    .padding(.horizontal)
                
                // Ruler Actions (moved to top, after header)
                if isPlayerInside && kingdom.rulerId == player.playerId {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(KingdomTheme.Colors.gold)
                            Text("You rule this kingdom")
                                .font(KingdomTheme.Typography.subheadline())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.gold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(KingdomTheme.Spacing.medium)
                        .background(KingdomTheme.Colors.parchmentHighlight)
                        .cornerRadius(KingdomTheme.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.medium)
                                .stroke(KingdomTheme.Colors.gold, lineWidth: KingdomTheme.BorderWidth.regular)
                        )
                        
                        // Manage Kingdom button
                        Button(action: onViewKingdom) {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.white)
                                Text("Manage Kingdom")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(KingdomTheme.Spacing.medium)
                            .background(KingdomTheme.Colors.buttonPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(KingdomTheme.CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal)
                } else if isPlayerInside && kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                    // Can claim!
                    Button(action: {
                        _ = viewModel.claimKingdom()
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.white)
                            Text("Claim This Kingdom")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(KingdomTheme.Spacing.medium)
                        .background(KingdomTheme.Colors.gold)
                        .foregroundColor(.white)
                        .cornerRadius(KingdomTheme.CornerRadius.medium)
                    }
                    .padding(.horizontal)
                } else if isPlayerInside {
                    // Already present but someone else rules it
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(KingdomTheme.Colors.divider)
                        Text("You are here")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.divider)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(KingdomTheme.Colors.parchmentMuted)
                    .cornerRadius(KingdomTheme.CornerRadius.medium)
                    .padding(.horizontal)
                } else {
                    // Not inside this kingdom
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text("You must travel here first")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                    }
                    .padding(8)
                    .padding(.horizontal)
                }
                
                // Population Stats
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Population")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 24))
                                .foregroundColor(KingdomTheme.Colors.goldWarm)
                            
                            Text("\(kingdom.checkedInPlayers)")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Present Now")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .parchmentCard(
                            backgroundColor: KingdomTheme.Colors.parchmentLight,
                            cornerRadius: KingdomTheme.CornerRadius.xLarge,
                            hasShadow: false
                        )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 24))
                                .foregroundColor(KingdomTheme.Colors.goldWarm)
                            
                            Text("\(kingdom.weeklyUniqueCheckIns)")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("This Week")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .parchmentCard(
                            backgroundColor: KingdomTheme.Colors.parchmentLight,
                            cornerRadius: KingdomTheme.CornerRadius.xLarge,
                            hasShadow: false
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Treasury & Income Section
                VStack(spacing: KingdomTheme.Spacing.small) {
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        // Treasury
                        VStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 28))
                                .foregroundColor(KingdomTheme.Colors.goldLight)
                            
                            Text("\(kingdom.treasuryGold)g")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Treasury")
                                .font(KingdomTheme.Typography.caption2())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.medium)
                        
                        // Income Rate
                        VStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 28))
                                .foregroundColor(KingdomTheme.Colors.goldWarm)
                            
                            Text("\(kingdom.hourlyIncome)g/hr")
                                .font(KingdomTheme.Typography.title3())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            Text("Income Rate")
                                .font(KingdomTheme.Typography.caption2())
                                .foregroundColor(KingdomTheme.Colors.inkMedium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KingdomTheme.Spacing.medium)
                    }
                }
                .padding(KingdomTheme.Spacing.medium)
                .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentDark, hasShadow: false)
                .padding(.horizontal)
                
                // Buildings & Stats Section
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Fortifications")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
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
                
                // Economy Buildings
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Economy")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.medium) {
                        BuildingStatCard(
                            icon: "hammer.fill",
                            name: "Mine",
                            level: kingdom.mineLevel,
                            maxLevel: 5,
                            benefit: "+\(kingdom.mineLevel * 5)g/hr"
                        )
                        
                        BuildingStatCard(
                            icon: "cart.fill",
                            name: "Market",
                            level: kingdom.marketLevel,
                            maxLevel: 5,
                            benefit: "+\(kingdom.marketLevel * 3)g/hr"
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
                                .foregroundColor(KingdomTheme.Colors.buttonWarning)
                            Text("Active Contract")
                                .font(KingdomTheme.Typography.subheadline())
                                .fontWeight(.bold)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            Spacer()
                            if contract.isComplete {
                                Text("Complete")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KingdomTheme.Colors.buttonSuccess.opacity(0.1))
                                    .cornerRadius(KingdomTheme.CornerRadius.small)
                            } else {
                                Text("In Progress")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.buttonWarning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KingdomTheme.Colors.buttonWarning.opacity(0.1))
                                    .cornerRadius(KingdomTheme.CornerRadius.small)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption2)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                                Text("\(contract.buildingType) Level \(contract.buildingLevel)")
                                    .font(KingdomTheme.Typography.caption())
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                            
                            HStack(spacing: 8) {
                                Label("\(contract.contributorCount) contributors", systemImage: "person.2.fill")
                                    .font(KingdomTheme.Typography.caption2())
                                    .foregroundColor(KingdomTheme.Colors.inkLight)
                                
                                Label("\(contract.rewardPool)g pool", systemImage: "dollarsign.circle")
                                    .font(KingdomTheme.Typography.caption2())
                                    .foregroundColor(KingdomTheme.Colors.gold)
                            }
                            
                            // Progress bar
                            if !contract.isComplete {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Progress")
                                            .font(KingdomTheme.Typography.caption2())
                                            .foregroundColor(KingdomTheme.Colors.inkLight)
                                        Spacer()
                                        Text(String(format: "%.0f%%", contract.progress * 100))
                                            .font(KingdomTheme.Typography.caption2())
                                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                                    }
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.inkDark.opacity(0.1))
                                                .frame(height: 4)
                                                .cornerRadius(2)
                                            
                                            Rectangle()
                                                .fill(KingdomTheme.Colors.buttonWarning)
                                                .frame(width: geometry.size.width * contract.progress, height: 4)
                                                .cornerRadius(2)
                                        }
                                    }
                                    .frame(height: 4)
                                }
                            }
                        }
                    }
                    .padding(KingdomTheme.Spacing.medium)
                    .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentLight, hasShadow: false)
                    .padding(.horizontal)
                }
                
                // Action buttons - Medieval war council style (only if kingdom has ruler)
                if !kingdom.isUnclaimed && kingdom.rulerId != player.playerId {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Button(action: {
                                // TODO: Implement declare war
                                print("Declare war on \(kingdom.name)")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                    Text("Declare War")
                                        .fontWeight(.semibold)
                                        .font(KingdomTheme.Typography.caption())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(KingdomTheme.Colors.buttonDanger)
                                .foregroundColor(.white)
                                .cornerRadius(KingdomTheme.CornerRadius.medium)
                            }
                            
                            Button(action: {
                                // TODO: Implement form alliance
                                print("Form alliance with \(kingdom.name)")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.raised.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                    Text("Form Alliance")
                                        .fontWeight(.semibold)
                                        .font(KingdomTheme.Typography.caption())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(KingdomTheme.Colors.buttonSuccess)
                                .foregroundColor(.white)
                                .cornerRadius(KingdomTheme.CornerRadius.medium)
                            }
                        }
                        
                        Button(action: {
                            // TODO: Implement stage coup
                            print("Stage coup in \(kingdom.name)")
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.white)
                                Text("Stage Coup")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(KingdomTheme.Spacing.medium)
                            .background(KingdomTheme.Colors.buttonSpecial)
                            .foregroundColor(.white)
                            .cornerRadius(KingdomTheme.CornerRadius.medium)
                        }
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

