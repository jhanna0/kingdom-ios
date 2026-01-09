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
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .brutalistBadge(backgroundColor: KingdomTheme.Colors.royalBlue, cornerRadius: 20, shadowOffset: 4, borderWidth: 3)
                    
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
                            badge: "Active"
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
                    
                    // Coming Soon Activities
                    VStack(spacing: KingdomTheme.Spacing.small) {
                        TownHallComingSoonCard(
                            icon: "flag.2.crossed.fill",
                            title: "Tournament Arena",
                            description: "Compete in skill-based challenges"
                        )
                        
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
            .padding()
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
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .brutalistBadge(backgroundColor: color, cornerRadius: 16, shadowOffset: 3, borderWidth: 3)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if let badge = badge {
                        Text(badge)
                            .font(FontStyles.labelTiny)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color)
                            .cornerRadius(6)
                    }
                }
                
                Text(description)
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(FontStyles.iconMedium)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
        }
        .padding(KingdomTheme.Spacing.medium)
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
        .padding(.horizontal)
    }
}

// MARK: - Town Hall Coming Soon Card

struct TownHallComingSoonCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Icon (dimmed)
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkLight, cornerRadius: 14, shadowOffset: 2, borderWidth: 2)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(FontStyles.bodyMediumBold)
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
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkLight)
            }
            
            Spacer()
        }
        .padding(KingdomTheme.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchmentLight.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
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
