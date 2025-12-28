import SwiftUI
import MapKit

enum KingdomDetailDestination: Hashable {
    case build
    case decree
}

struct KingdomDetailView: View {
    let kingdom: Kingdom
    @ObservedObject var player: Player
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var decreeText = ""
    
    var isRuler: Bool {
        kingdom.rulerId == player.playerId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Kingdom header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundColor(KingdomTheme.Colors.goldLight)
                    
                    Text(kingdom.name)
                        .font(KingdomTheme.Typography.largeTitle())
                        .fontWeight(.bold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if isRuler {
                        Text("Your Kingdom")
                            .font(KingdomTheme.Typography.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    } else {
                        Text("Ruled by \(kingdom.rulerName)")
                            .font(KingdomTheme.Typography.subheadline())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                .padding()
                
                // Treasury - Kingdom's money
                VStack(spacing: 8) {
                    Text("Kingdom Treasury")
                        .font(KingdomTheme.Typography.caption())
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns.fill")
                            .font(.title)
                            .foregroundColor(KingdomTheme.Colors.goldLight)
                        Text("\(kingdom.treasuryGold)")
                            .font(KingdomTheme.Typography.title())
                            .fontWeight(.bold)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        Text("gold")
                            .font(KingdomTheme.Typography.subheadline())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    
                    Text("Used for contracts & defenses")
                        .font(KingdomTheme.Typography.caption2())
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .parchmentCard(backgroundColor: KingdomTheme.Colors.parchmentDark, hasShadow: false)
                .padding(.horizontal)
                
                // Buildings section
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Fortifications")
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    HStack(spacing: KingdomTheme.Spacing.large) {
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
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    HStack {
                        Text("Checked In")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                        
                        Text("\(kingdom.checkedInPlayers) present")
                            .font(KingdomTheme.Typography.subheadline())
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                    .padding(.horizontal)
                    
                    // Placeholder for future player list
                    if kingdom.checkedInPlayers == 0 {
                        Text("No one is present")
                            .font(KingdomTheme.Typography.caption())
                            .foregroundColor(KingdomTheme.Colors.inkLight)
                            .italic()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.vertical, KingdomTheme.Spacing.medium)
                .parchmentCard(
                    backgroundColor: KingdomTheme.Colors.parchmentLight,
                    borderWidth: KingdomTheme.BorderWidth.thin,
                    hasShadow: false
                )
                .padding(.horizontal)
                
                // Reward Distribution System
                if isRuler {
                    // Show ruler management card
                    RulerRewardManagementCard(
                        kingdom: Binding(
                            get: { kingdom },
                            set: { _ in }
                        ),
                        viewModel: viewModel
                    )
                    .padding(.horizontal)
                } else {
                    // Show subject reward card
                    SubjectRewardCard(kingdom: kingdom, player: player)
                        .padding(.horizontal)
                }
                
                        // Ruler actions
                        if isRuler {
                            VStack(spacing: KingdomTheme.Spacing.medium) {
                                Text("Kingdom Management")
                                    .font(KingdomTheme.Typography.headline())
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                                
                                NavigationLink(value: KingdomDetailDestination.build) {
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Manage Buildings")
                                                .font(KingdomTheme.Typography.headline())
                                            Text("Upgrade economy & defenses")
                                                .font(KingdomTheme.Typography.caption())
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(KingdomTheme.Colors.buttonPrimary)
                                    .cornerRadius(KingdomTheme.CornerRadius.xLarge)
                                }
                        
                        NavigationLink(value: KingdomDetailDestination.decree) {
                            HStack {
                                Image(systemName: "scroll.fill")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Make Decree")
                                        .font(KingdomTheme.Typography.headline())
                                    Text("Announce to all subjects")
                                        .font(KingdomTheme.Typography.caption())
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(KingdomTheme.Colors.buttonSecondary)
                            .cornerRadius(KingdomTheme.CornerRadius.xLarge)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, KingdomTheme.Spacing.xLarge)
                }
                
                // Benefits of ruling
                if isRuler {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Benefits of Ruling")
                            .font(KingdomTheme.Typography.headline())
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        BenefitRow(icon: "bitcoinsign.circle.fill", text: "Passive income: +10 gold/hour")
                        BenefitRow(icon: "person.2.fill", text: "Tax subjects & demand tribute")
                        BenefitRow(icon: "shield.fill", text: "Build defenses against coups")
                        BenefitRow(icon: "crown.fill", text: "Control territory & make decrees")
                    }
                    .padding()
                    .parchmentCard(
                        backgroundColor: KingdomTheme.Colors.parchmentRich,
                        borderWidth: KingdomTheme.BorderWidth.thin,
                        hasShadow: false
                    )
                    .padding(.horizontal)
                    .padding(.bottom, KingdomTheme.Spacing.xLarge)
                }
            }
            .padding(.top)
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationDestination(for: KingdomDetailDestination.self) { destination in
            switch destination {
            case .build:
                BuildMenuView(kingdom: kingdom, player: player, viewModel: viewModel)
            case .decree:
                DecreeInputView(kingdom: kingdom, decreeText: $decreeText)
            }
        }
    }
}
