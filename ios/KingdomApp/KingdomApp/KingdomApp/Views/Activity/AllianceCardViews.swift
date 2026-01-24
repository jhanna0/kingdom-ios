import SwiftUI

// MARK: - Alliance Proposal Card

struct AllianceProposalCard: View {
    let alliance: AllianceResponse
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    
    @State private var isAccepting = false
    @State private var isDeclining = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KingdomTheme.Spacing.medium) {
            HStack(spacing: 12) {
                // Empire avatar
                Image(systemName: "flag.fill")
                    .font(FontStyles.iconMedium)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alliance.initiatorRulerName)
                        .font(FontStyles.bodyMediumBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                    
                    Text("proposes an alliance")
                        .font(FontStyles.labelSmall)
                        .foregroundColor(KingdomTheme.Colors.inkMedium)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(alliance.hoursToRespond) hours to respond")
                            .font(FontStyles.labelTiny)
                    }
                    .foregroundColor(alliance.hoursToRespond < 24 ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkLight)
                }
                
                Spacer()
            }
            
            // Benefits
            HStack(spacing: 8) {
                Text("🛡️ Protection")
                    .font(FontStyles.labelTiny)
                Text("🚫 No fees")
                    .font(FontStyles.labelTiny)
                Text("⚔️ Defense")
                    .font(FontStyles.labelTiny)
            }
            .foregroundColor(KingdomTheme.Colors.inkMedium)
            
            // Action buttons
            HStack(spacing: KingdomTheme.Spacing.medium) {
                Button(action: {
                    isDeclining = true
                    Task {
                        await onDecline()
                        isDeclining = false
                    }
                }) {
                    Text("Decline")
                        .font(FontStyles.labelBold)
                        .foregroundColor(KingdomTheme.Colors.inkDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 8)
                .disabled(isAccepting || isDeclining)
                
                Button(action: {
                    isAccepting = true
                    Task {
                        await onAccept()
                        isAccepting = false
                    }
                }) {
                    HStack(spacing: 6) {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text("Accept")
                            .font(FontStyles.labelBold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.buttonSuccess, cornerRadius: 8)
                .disabled(isAccepting || isDeclining)
            }
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KingdomTheme.Colors.buttonSuccess.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Active Alliance Card

struct ActiveAllianceCard: View {
    let alliance: AllianceResponse
    
    var otherEmpireName: String {
        // Show the other party's name (not ours)
        alliance.targetRulerName ?? alliance.initiatorRulerName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Alliance icon
            Image(systemName: "person.2.fill")
                .font(FontStyles.iconMedium)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.territoryAllied, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(otherEmpireName)
                    .font(FontStyles.bodyMediumBold)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(alliance.daysRemaining) days left")
                            .font(FontStyles.labelSmall)
                    }
                    .foregroundColor(alliance.daysRemaining < 7 ? KingdomTheme.Colors.buttonWarning : KingdomTheme.Colors.inkMedium)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundColor(KingdomTheme.Colors.buttonSuccess)
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
}

// MARK: - Pending Alliance Sent Card

struct PendingAllianceSentCard: View {
    let alliance: AllianceResponse
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(FontStyles.bodyMediumBold)
                .foregroundColor(KingdomTheme.Colors.inkMedium)
                .frame(width: 40, height: 40)
                .brutalistBadge(backgroundColor: KingdomTheme.Colors.parchment, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alliance.targetRulerName ?? "Unknown")
                    .font(FontStyles.bodySmall)
                    .foregroundColor(KingdomTheme.Colors.inkDark)
                
                Text("Awaiting response • \(alliance.hoursToRespond)h left")
                    .font(FontStyles.labelSmall)
                    .foregroundColor(KingdomTheme.Colors.inkMedium)
            }
            
            Spacer()
        }
        .padding()
        .brutalistCard(backgroundColor: KingdomTheme.Colors.parchmentLight, cornerRadius: 12)
        .padding(.horizontal)
    }
}
