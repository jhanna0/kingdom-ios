import SwiftUI
import CoreLocation

struct TownHallView: View {
    let kingdom: Kingdom
    let playerId: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header
                VStack(spacing: KingdomTheme.Spacing.medium) {
                    Image(systemName: "building.columns.fill")
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalBlue, cornerRadius: 12, shadowOffset: 3, borderWidth: 2)
                    
                    Text("Town Hall")
                        .font(FontStyles.displayMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text(kingdom.name)
                        .font(FontStyles.bodyLarge)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Community Activities & Social Hub")
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkLight)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Activities Section
                VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
                    Text("Available Activities")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .padding(.horizontal)
                    
                    // Group Hunt
                    NavigationLink {
                        HuntView(kingdomId: kingdom.id, kingdomName: kingdom.name, playerId: playerId)
                    } label: {
                        TownHallActivityCard(
                            icon: "hare.fill",
                            title: "Group Hunt",
                            description: "Hunt together for meat and glory",
                            color: KingdomTheme.Colors.buttonSuccess,
                            badge: nil
                        )
                    }
                    
                    // Fishing
                    NavigationLink {
                        FishingView(apiClient: APIClient.shared)
                    } label: {
                        TownHallActivityCard(
                            icon: "fish.fill",
                            title: "Fishing",
                            description: "Relax and catch some fish",
                            color: KingdomTheme.Colors.royalBlue,
                            badge: nil
                        )
                    }
                    
                    // Research Lab
                    NavigationLink {
                        ResearchView(apiClient: APIClient.shared)
                    } label: {
                        TownHallActivityCard(
                            icon: "flask.fill",
                            title: "Research Lab",
                            description: "Experiment to discover blueprints",
                            color: KingdomTheme.Colors.regalPurple,
                            badge: nil
                        )
                    }
                    
                    // Foraging
                    NavigationLink {
                        ForagingView(apiClient: APIClient.shared)
                    } label: {
                        TownHallActivityCard(
                            icon: "leaf.fill",
                            title: "Foraging",
                            description: "Search bushes for seeds and herbs",
                            color: KingdomTheme.Colors.buttonSuccess,
                            badge: nil
                        )
                    }
                    
                    // Town Pub
                    NavigationLink {
                        TownPubView(kingdomId: kingdom.id, kingdomName: kingdom.name)
                    } label: {
                        TownHallActivityCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Town Pub",
                            description: "Chat with fellow citizens",
                            color: KingdomTheme.Colors.buttonWarning,
                            badge: nil
                        )
                    }

                                        // Hunt Leaderboard
                    NavigationLink {
                        HuntLeaderboardView(kingdomId: kingdom.id, kingdomName: kingdom.name)
                    } label: {
                        TownHallActivityCard(
                            icon: "trophy.fill",
                            title: "Hunt Leaderboard",
                            description: "Top hunters and creatures killed",
                            color: KingdomTheme.Colors.buttonWarning,
                            badge: nil
                        )
                    }
                    
                    // PvP Arena
                    // NavigationLink {
                    //     ArenaView(kingdomId: kingdom.id, kingdomName: kingdom.name, playerId: playerId)
                    // } label: {
                    //     TownHallActivityCard(
                    //         icon: "figure.fencing",
                    //         title: "PvP Arena",
                    //         description: "Duel friends in 1v1 combat",
                    //         color: KingdomTheme.Colors.royalCrimson,
                    //         badge: nil
                    //     )
                    // }
                    VStack(spacing: KingdomTheme.Spacing.small) {
                        TownHallComingSoonCard(
                            icon: "figure.fencing",
                            title: "PvP Arena",
                            description: "Duel friends in 1v1 combat"
                        )
                    }
                    
                    
                    // Coming Soon Activities
                    VStack(spacing: KingdomTheme.Spacing.small) {
                        TownHallComingSoonCard(
                            icon: "sparkles",
                            title: "Festival Hall",
                            description: "Seasonal events and celebrations"
                        )
                        
                        TownHallComingSoonCard(
                            icon: "book.fill",
                            title: "Quest Board",
                            description: "Community quests and bounties"
                        )
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(KingdomTheme.Colors.parchment)
        .navigationTitle("Town Hall")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - Town Hall Activity Card

struct TownHallActivityCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let badge: String?
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .brutalistBadge(backgroundColor: color, cornerRadius: 8, shadowOffset: 2, borderWidth: 2)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let badge = badge {
                        Text(badge)
                            .font(FontStyles.labelTiny)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(FontStyles.iconMini)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(10)
        .background(KingdomTheme.Colors.parchmentLight)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
        .padding(.horizontal)
    }
}

// MARK: - Town Hall Coming Soon Card

struct TownHallComingSoonCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon (dimmed)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkLight, cornerRadius: 8, shadowOffset: 1, borderWidth: 1.5)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(FontStyles.bodySmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    Text("Soon")
                        .font(FontStyles.labelTiny)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(KingdomTheme.Colors.inkLight)
                        .cornerRadius(4)
                }
                
                Text(description)
                    .font(FontStyles.labelTiny)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KingdomTheme.Colors.parchmentLight.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundColor(KingdomTheme.Colors.inkLight.opacity(0.3))
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    let testCoord = CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)
    let testKingdom = Kingdom(
        name: "Test Kingdom",
        territory: Territory.circular(
            center: testCoord,
            radiusMeters: 1000,
            osmId: "test"
        ),
        color: .burntSienna
    )!
    
    return NavigationStack {
        TownHallView(kingdom: testKingdom, playerId: 1)
    }
}
