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
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            // Header with medieval styling
            HStack {
                Text("🏰 \(kingdom.name)")
                    .font(KingdomTheme.Typography.title2())
                    .fontWeight(.bold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                Spacer()
                
                if kingdom.isUnclaimed {
                    Text("⚠️ Unclaimed")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KingdomTheme.Colors.parchmentRich)
                        .cornerRadius(KingdomTheme.CornerRadius.small)
                }
            }
            .padding(.bottom, 4)
            
            if kingdom.isUnclaimed {
                Text("No ruler!")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            } else {
                HStack(spacing: 4) {
                    Text("Ruled by \(kingdom.rulerName)")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    if kingdom.rulerId == player.playerId {
                        Text("(You)")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.gold)
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
            
            // Treasury & Income Section
            VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                HStack {
                    Label("\(kingdom.treasuryGold)g", systemImage: "dollarsign.circle.fill")
                        .foregroundColor(KingdomTheme.Colors.gold)
                        .font(KingdomTheme.Typography.headline())
                    
                    Spacer()
                    
                    // Show pending income if any
                    if kingdom.pendingIncome > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                                .font(.caption)
                            Text("+\(kingdom.pendingIncome)g ready")
                                .font(KingdomTheme.Typography.caption())
                                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KingdomTheme.Colors.buttonSuccess.opacity(0.1))
                        .cornerRadius(KingdomTheme.CornerRadius.small)
                    }
                }
                
                // Income rate display
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(KingdomTheme.Colors.goldWarm)
                        .font(.caption2)
                    Text("\(kingdom.dailyIncome)g/day")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    Text("(\(kingdom.hourlyIncome)g/hr)")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            .padding(KingdomTheme.Spacing.medium)
            .background(KingdomTheme.Colors.parchmentHighlight)
            .cornerRadius(KingdomTheme.CornerRadius.medium)
            
            // Buildings & Stats
            HStack(spacing: KingdomTheme.Spacing.xLarge) {
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    Label("Walls Lv.\(kingdom.wallLevel)", systemImage: "shield.fill")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Label("Vault Lv.\(kingdom.vaultLevel)", systemImage: "lock.fill")
                        .foregroundColor(KingdomTheme.Colors.goldWarm)
                }
                
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    Label("Mine Lv.\(kingdom.mineLevel)", systemImage: "hammer.fill")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Label("Market Lv.\(kingdom.marketLevel)", systemImage: "cart.fill")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.small) {
                    Label("\(kingdom.checkedInPlayers) present", systemImage: "person.3.fill")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Label("\(kingdom.weeklyUniqueCheckIns) weekly", systemImage: "calendar")
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
            }
            .font(KingdomTheme.Typography.caption())
            
            // Check-in/Claim section
            if isPlayerInside {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.divider)
                        .frame(height: 2)
                        .padding(.vertical, 4)
                    
                    if kingdom.rulerId == player.playerId {
                        // You own this kingdom - show ruler options
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
                            
                            // Collect income button (if income is pending)
                            if kingdom.pendingIncome > 0 {
                                MedievalActionButton(
                                    title: "💰 Collect \(kingdom.pendingIncome)g Income",
                                    color: KingdomTheme.Colors.buttonSuccess,
                                    fullWidth: true
                                ) {
                                    viewModel.collectKingdomIncome(for: kingdom)
                                }
                            }
                            
                            // Build button
                            MedievalActionButton(
                                title: "Build Fortifications",
                                color: KingdomTheme.Colors.buttonPrimary,
                                fullWidth: true
                            ) {
                                showBuildMenu = true
                            }
                        }
                    } else if kingdom.isUnclaimed && player.isCheckedIn() && player.currentKingdom == kingdom.name {
                        // Can claim!
                        MedievalActionButton(
                            title: "Claim This Kingdom",
                            color: KingdomTheme.Colors.gold,
                            fullWidth: true
                        ) {
                            onClaim()
                        }
                    } else if !player.isCheckedIn() || player.currentKingdom != kingdom.name {
                        // Need to enter the kingdom
                        MedievalActionButton(
                            title: "⚔️ Enter Kingdom",
                            color: KingdomTheme.Colors.buttonSuccess,
                            fullWidth: true
                        ) {
                            onCheckIn()
                        }
                    } else {
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
                    }
                }
            } else {
                // Not inside this kingdom
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(KingdomTheme.Colors.divider)
                        .frame(height: 2)
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                        Text("You must travel here first")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
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
                            color: KingdomTheme.Colors.buttonDanger
                        ) {
                            // TODO: Implement declare war
                            print("Declare war on \(kingdom.name)")
                        }
                        
                        MedievalActionButton(
                            title: "🤝 Form Alliance",
                            color: KingdomTheme.Colors.buttonSuccess
                        ) {
                            // TODO: Implement form alliance
                            print("Form alliance with \(kingdom.name)")
                        }
                    }
                    
                    MedievalActionButton(
                        title: "🗡️ Stage Coup",
                        color: KingdomTheme.Colors.buttonSpecial,
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
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(KingdomTheme.Spacing.xLarge)
        .background(
            KingdomTheme.Colors.parchment
                .overlay(
                    // Add subtle texture
                    KingdomTheme.Colors.parchmentRich.opacity(0.1)
                )
        )
        .cornerRadius(KingdomTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: KingdomTheme.CornerRadius.large)
                .stroke(
                    Color(
                        red: kingdom.color.strokeRGBA.red,
                        green: kingdom.color.strokeRGBA.green,
                        blue: kingdom.color.strokeRGBA.blue
                    ),
                    lineWidth: KingdomTheme.BorderWidth.thick
                )
        )
        .shadow(
            color: KingdomTheme.Shadows.cardStrong.color,
            radius: KingdomTheme.Shadows.cardStrong.radius,
            x: KingdomTheme.Shadows.cardStrong.x,
            y: KingdomTheme.Shadows.cardStrong.y
        )
        .sheet(isPresented: $showBuildMenu) {
            BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)
        }
        .onAppear {
            // Auto-collect income when viewing kingdom (if player is ruler)
            if kingdom.rulerId == player.playerId {
                viewModel.autoCollectIncomeForKingdom(kingdom)
            }
        }
    }
}
