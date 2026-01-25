import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hunt Lobby View
// Waiting room for party members before the hunt starts

struct HuntLobbyView: View {
    @ObservedObject var viewModel: HuntViewModel
    let kingdomName: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: KingdomTheme.Spacing.xLarge) {
                // Header with hunt info
                lobbyHeader
                
                // Party members
                partySection
                
                // Action buttons
                actionButtons
                
                Spacer(minLength: 40)
            }
            .padding()
        }
    }
    
    // MARK: - Lobby Header
    
    private var lobbyHeader: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Animated hunting icon
            ZStack {
                Circle()
                    .fill(KingdomTheme.Colors.buttonSuccess.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "hare.fill")
                    .font(.system(size: 44))
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            Text("Hunt Party")
                .font(KingdomTheme.Typography.title())
                .foregroundColor(KingdomTheme.Colors.inkDark)
            
            Text("Hunting in \(kingdomName)")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            if let hunt = viewModel.hunt {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                    Text("\(hunt.party_size)/\(viewModel.config?.party.max_size ?? 5)")
                }
                .font(KingdomTheme.Typography.headline())
                .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Party Section
    
    private var partySection: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack {
                Text("Party Members")
                    .font(KingdomTheme.Typography.headline())
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Spacer()
                
                if viewModel.hunt?.allReady == true {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("All Ready!")
                    }
                    .font(FontStyles.labelMedium)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
                }
            }
            
            if let hunt = viewModel.hunt {
                ForEach(hunt.participantList) { participant in
                    PartyMemberCard(
                        participant: participant,
                        isLeader: participant.player_id == hunt.created_by
                    )
                }
            }
            
            // Empty slots
            if let hunt = viewModel.hunt, let maxSize = viewModel.config?.party.max_size {
                let emptySlots = maxSize - hunt.party_size
                if emptySlots > 0 {
                    ForEach(0..<emptySlots, id: \.self) { _ in
                        EmptyPartySlot()
                    }
                }
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: KingdomTheme.Spacing.medium) {
            // Ready button
            Button {
                hapticImpact(.medium)
                Task {
                    await viewModel.toggleReady()
                }
            } label: {
                HStack {
                    if isCurrentUserReady {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Ready!")
                    } else {
                        Image(systemName: "circle")
                        Text("Mark Ready")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.brutalist(
                backgroundColor: isCurrentUserReady ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.inkMedium,
                fullWidth: true
            ))
            
            // Start button (leader only)
            if viewModel.isLeader {
                Button {
                    hapticImpact(.heavy)
                    Task {
                        await viewModel.startHunt()
                    }
                } label: {
                    HStack {
                        Image(systemName: "flag.fill")
                        Text("Start Hunt!")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.brutalist(
                    backgroundColor: viewModel.canStartHunt ? KingdomTheme.Colors.buttonSuccess : KingdomTheme.Colors.disabled,
                    fullWidth: true
                ))
                .disabled(!viewModel.canStartHunt)
            }
            
            // Leave button
            Button {
                hapticImpact(.light)
                Task {
                    await viewModel.leaveHunt()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.left.circle")
                    Text("Leave Party")
                }
            }
            .font(KingdomTheme.Typography.subheadline())
            .foregroundColor(KingdomTheme.Colors.buttonDanger)
        }
    }
    
    // MARK: - Haptics
    
    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
    
    // MARK: - Helpers
    
    private var isCurrentUserReady: Bool {
        guard let hunt = viewModel.hunt, let userId = viewModel.currentUserId else { return false }
        return hunt.participants[String(userId)]?.is_ready ?? false
    }
}

// MARK: - Party Member Card

struct PartyMemberCard: View {
    let participant: HuntParticipant
    let isLeader: Bool
    
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isLeader ? KingdomTheme.Colors.gold : KingdomTheme.Colors.inkMedium)
                    .frame(width: 44, height: 44)
                
                if isLeader {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.white)
                } else {
                    Text(String(participant.player_name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            // Name and stats
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                if isLeader {
                        Text("Leader")
                            .font(FontStyles.labelSmall)
                            .foregroundColor(KingdomTheme.Colors.gold)
                    }
                }
                    Text(participant.player_name)
                        .font(KingdomTheme.Typography.headline())
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    
                if let stats = participant.stats {
                    HStack(spacing: 8) {
                        HuntStatBadge(icon: "eye.fill", value: stats["intelligence"] ?? 0)
                        HuntStatBadge(icon: "bolt.fill", value: stats["attack_power"] ?? 0)
                        HuntStatBadge(icon: "shield.fill", value: stats["defense"] ?? 0)
                    }
                }
            }
            
            Spacer()
            
            // Ready status
            if participant.is_ready {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.buttonSuccess)
            } else {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchment)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(participant.is_ready ? KingdomTheme.Colors.buttonSuccess.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Hunt Stat Badge

struct HuntStatBadge: View {
    let icon: String
    let value: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(value)")
                .font(FontStyles.labelSmall)
        }
        .foregroundColor(KingdomTheme.Colors.inkMedium)
    }
}

// MARK: - Empty Party Slot

struct EmptyPartySlot: View {
    var body: some View {
        HStack(spacing: KingdomTheme.Spacing.medium) {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.3))
                .frame(width: 44, height: 44)
            
            Text("Waiting for hunter...")
                .font(KingdomTheme.Typography.subheadline())
                .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.5))
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KingdomTheme.Colors.parchment.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(KingdomTheme.Colors.inkMedium.opacity(0.2))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HuntLobbyView(viewModel: HuntViewModel(), kingdomName: "Test Kingdom")
    }
}

