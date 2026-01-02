import SwiftUI

struct ReputationDetailView: View {
    @ObservedObject var player: Player
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTier: Int = 1
    
    private var currentTierIndex: Int {
        if player.reputation >= 1000 { return 6 }
        if player.reputation >= 500 { return 5 }
        if player.reputation >= 300 { return 4 }
        if player.reputation >= 150 { return 3 }
        if player.reputation >= 50 { return 2 }
        return 1
    }
    
    private var currentReputationTier: ReputationTier {
        ReputationTier.from(reputation: player.reputation)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current reputation display
                VStack(spacing: 12) {
                    Image(systemName: currentReputationTier.icon)
                        .font(FontStyles.iconExtraLarge)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .brutalistBadge(
                            backgroundColor: currentReputationTier.color,
                            cornerRadius: 16,
                            shadowOffset: 3,
                            borderWidth: 2
                        )
                    
                    Text("Current Rank: \(currentReputationTier.displayName)")
                        .font(FontStyles.headingMedium)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("\(player.reputation) Reputation")
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                
                // Tier selector with all reputation tiers
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: "star.fill")
                            .font(FontStyles.iconMedium)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                        
                        Text("Reputation Tiers")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                    }
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    
                    // Tier buttons
                    VStack(spacing: 8) {
                        ForEach(1...6, id: \.self) { tier in
                            tierButton(tier: tier)
                        }
                    }
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    
                    // Selected tier details
                    VStack(alignment: .leading, spacing: 16) {
                        let tier = getTierData(for: selectedTier)
                        
                        // Tier name
                        HStack {
                            Text(tier.name)
                                .font(FontStyles.headingMedium)
                                .foregroundColor(KingdomTheme.Colors.inkDark)
                            
                            if selectedTier <= currentTierIndex {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(FontStyles.iconMedium)
                                    .foregroundColor(KingdomTheme.Colors.inkMedium)
                            }
                        }
                        
                        // Requirements
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(FontStyles.iconSmall)
                                .foregroundColor(KingdomTheme.Colors.inkDark.opacity(0.7))
                            
                            if tier.requirement > 0 {
                                Text("Requires \(tier.requirement) reputation")
                                    .font(FontStyles.bodySmall)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            } else {
                                Text("Starting rank")
                                    .font(FontStyles.bodySmall)
                                    .foregroundColor(KingdomTheme.Colors.inkDark)
                            }
                        }
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 2)
                        
                        // Abilities
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(icon: "star.fill", title: "Abilities Unlocked")
                            
                            ForEach(tier.abilities, id: \.self) { ability in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: selectedTier <= currentTierIndex ? "checkmark.circle.fill" : "lock.circle.fill")
                                        .font(FontStyles.iconSmall)
                                        .foregroundColor(selectedTier <= currentTierIndex ? KingdomTheme.Colors.inkMedium : KingdomTheme.Colors.inkDark.opacity(0.3))
                                        .frame(width: 20)
                                    
                                    Text(ability)
                                        .font(FontStyles.bodySmall)
                                        .foregroundColor(selectedTier <= currentTierIndex ? KingdomTheme.Colors.inkDark : KingdomTheme.Colors.inkMedium)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        // Status badge
                        if selectedTier <= currentTierIndex {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(FontStyles.iconSmall)
                                Text("Unlocked")
                                    .font(FontStyles.bodyMediumBold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.inkMedium, cornerRadius: 10)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(FontStyles.iconSmall)
                                Text("Earn \(tier.requirement - player.reputation) more reputation to unlock")
                                    .font(FontStyles.bodySmall)
                            }
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 10)
                        }
                    }
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
                
                // How to earn reputation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(FontStyles.iconMedium)
                            .foregroundColor(KingdomTheme.Colors.buttonPrimary)
                        
                        Text("How to Earn Reputation")
                            .font(FontStyles.headingMedium)
                            .foregroundColor(KingdomTheme.Colors.inkDark)
                        
                        Spacer()
                    }
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    
                    VStack(spacing: 10) {
                        infoRow(icon: "hammer.fill", text: "Complete building contracts")
                        infoRow(icon: "leaf.fill", text: "Harvest crops from farms")
                        infoRow(icon: "flag.fill", text: "Participate in coups")
                        infoRow(icon: "person.2.fill", text: "Help other players with Assist actions")
                    }
                }
                .padding()
                .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
            }
            .padding()
        }
        .background(KingdomTheme.Colors.parchment.ignoresSafeArea())
        .navigationTitle("Reputation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(KingdomTheme.Colors.parchment, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            selectedTier = currentTierIndex
        }
    }
    
    // MARK: - Helper Views
    
    private func tierButton(tier: Int) -> some View {
        let tierData = getTierData(for: tier)
        let isUnlocked = tier <= currentTierIndex
        let isSelected = tier == selectedTier
        
        return Button {
            selectedTier = tier
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: tierData.icon)
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .brutalistBadge(
                        backgroundColor: isUnlocked ? tierData.color : KingdomTheme.Colors.inkLight,
                        cornerRadius: 10,
                        shadowOffset: 2,
                        borderWidth: 1.5
                    )
                
                // Name and requirement
                VStack(alignment: .leading, spacing: 2) {
                    Text(tierData.name)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    if tierData.requirement > 0 {
                        Text("\(tierData.requirement) rep")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    } else {
                        Text("Starting rank")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.inkMedium)
                    }
                }
                
                Spacer()
                
                // Status indicator
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FontStyles.iconSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                }
            }
            .padding(12)
            .background(isSelected ? KingdomTheme.Colors.inkMedium.opacity(0.1) : KingdomTheme.Colors.parchment)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? KingdomTheme.Colors.inkMedium : Color.black, lineWidth: isSelected ? 2 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            Text(title)
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkDark)
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(FontStyles.iconSmall)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 20)
            
            Text(text)
                .font(FontStyles.bodySmall)
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Spacer()
        }
    }
    
    // MARK: - Data Helpers
    
    private func getTierData(for tier: Int) -> (name: String, requirement: Int, icon: String, color: Color, abilities: [String]) {
        switch tier {
        case 1:
            return (
                name: "Stranger",
                requirement: 0,
                icon: "person.fill",
                color: .gray,
                abilities: ["Accept building contracts", "Work on properties", "Basic game access"]
            )
        case 2:
            return (
                name: "Resident",
                requirement: 50,
                icon: "house.fill",
                color: KingdomTheme.Colors.buttonPrimary,
                abilities: ["Buy property in cities", "Upgrade owned properties", "Farm resources"]
            )
        case 3:
            return (
                name: "Citizen",
                requirement: 150,
                icon: "person.2.fill",
                color: .blue,
                abilities: ["Vote on city coups", "Join alliances", "Participate in city governance"]
            )
        case 4:
            return (
                name: "Notable",
                requirement: 300,
                icon: "star.fill",
                color: .purple,
                abilities: ["Propose city coups (with Leadership 3+)", "Lead strategic initiatives", "Enhanced influence"]
            )
        case 5:
            return (
                name: "Champion",
                requirement: 500,
                icon: "crown.fill",
                color: KingdomTheme.Colors.inkMedium,
                abilities: ["Vote weight counts 2x", "Significantly increased influence", "Respected leader status"]
            )
        case 6:
            return (
                name: "Legendary",
                requirement: 1000,
                icon: "sparkles",
                color: .orange,
                abilities: ["Vote weight counts 3x", "Maximum influence", "Most prestigious rank"]
            )
        default:
            return (
                name: "Unknown",
                requirement: 0,
                icon: "questionmark",
                color: .gray,
                abilities: []
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReputationDetailView(player: {
            let p = Player(name: "Test Player")
            p.reputation = 250
            return p
        }())
    }
}

